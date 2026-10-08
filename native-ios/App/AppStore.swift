import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseFunctions
import FirebaseMessaging
import UserNotifications
import RehberlikCore

@MainActor
final class AppStore: ObservableObject {
    @Published var profile: UserProfile?
    @Published var loading = true
    @Published var errorMessage: String?
    @Published var records: [String:[ContentRecord]] = [:]
    @Published var users: [UserProfile] = []
    @Published var correctIDs: Set<String> = []
    @Published var wrongIDs: Set<String> = []
    @Published var chats: [ChatSummary] = []
    @Published var notificationRoute: NotificationRoute?
    private var started=false
    private var profileListener: ListenerRegistration?
    private var listeners: [ListenerRegistration] = []
    private var profileGeneration=UUID()
    private var generation=UUID()
    let demo=ProcessInfo.processInfo.arguments.contains("-ui-testing")
    var db: Firestore { Firestore.firestore() }
    var functions: Functions { Functions.functions(region:"europe-west1") }
    var eligibleCards: [LearningCard] {
        guard let profile,let col=profile.role.cardCollection else { return [] }
        return LearningPolicy.eligible((records[col] ?? []).map(\.card),week:LearningPolicy.currentWeek(createdAt:profile.createdAt))
    }
    var summary: QuizSummary { QuizSummary(cards:eligibleCards,correct:correctIDs,wrong:wrongIDs,previouslyEarned:profile?.earnedBadges ?? []) }
    func start() async {
        guard !started else { return }; started=true
        if demo { loading=false; return }
        let defaults=UserDefaults.standard
        if defaults.bool(forKey:"native.remember"),let uid=defaults.string(forKey:"native.uid") {
            try? await writeLoginHistory(uid)
            observeProfile(uid:uid)
        } else { loading=false }
    }
    private func writeLoginHistory(_ uid:String) async throws {
        _=try await db.collection("users").document(uid).collection("loginHistory").addDocument(data:["createdAt":FieldValue.serverTimestamp()])
    }
    private func clearData() {
        generation=UUID(); listeners.forEach{$0.remove()}; listeners=[]
        records=[:]; users=[]; correctIDs=[]; wrongIDs=[]; chats=[]; notificationRoute=nil
    }
    private func observeProfile(uid:String?) {
        profileGeneration=UUID();profileListener?.remove(); profileListener=nil; clearData(); profile=nil
        guard let uid else { loading=false; return }
        loading=true
        let epoch=profileGeneration
        profileListener=db.collection("users").document(uid).addSnapshotListener { [weak self] snap,error in
            Task { @MainActor in
                guard let self,self.profileGeneration==epoch else { return }
                if let error {
                    self.errorMessage=error.localizedDescription; self.loading=false
                    if (error as NSError).code == FirestoreErrorCode.permissionDenied.rawValue { await self.logout() }
                    return
                }
                do {
                    guard let snap,snap.exists else { throw DomainError.invalidProfile }
                    let next=try UserProfile(id:uid,data:snap.data() ?? [:])
                    let needsReload=self.profile?.role != next.role || self.profile?.id != next.id
                    self.profile=next; self.loading=false
                    if needsReload {
                        self.clearData(); self.subscribe(next)
                        self.openNotification(NotificationInbox.shared.pending)
                        await self.syncDevice()
                    }
                } catch { self.errorMessage=error.localizedDescription; await self.logout() }
            }
        }
    }
    private func subscribe(_ profile:UserProfile) {
        let epoch=generation
        let collections=profile.role == .admin ? ["sss","faq_items","notifications","MotherLearnCard","UpperLearnCard"] : ["sss","notifications",profile.role.cardCollection!]
        for col in collections {
            var query:Query=db.collection(col)
            if col=="notifications" && profile.role != .admin { query=query.whereField("targetRole",isEqualTo:profile.role.rawValue).whereField("isActive",isEqualTo:true) }
            listeners.append(query.addSnapshotListener { [weak self] snap,error in
                Task { @MainActor in
                    guard let self,self.generation==epoch else { return }
                    if let error { self.errorMessage=error.localizedDescription; return }
                    self.records[col]=(snap?.documents ?? []).map { ContentRecord(id:$0.documentID,collection:col,data:$0.data()) }.sorted { $0.createdAt < $1.createdAt }
                }
            })
        }
        if profile.role == .admin {
            listeners.append(db.collection("users").addSnapshotListener { [weak self] snap,error in
                Task { @MainActor in
                    guard let self,self.generation==epoch else { return }
                    if let error { self.errorMessage=error.localizedDescription; return }
                    self.users=(snap?.documents ?? []).compactMap { try? UserProfile(id:$0.documentID,data:$0.data()) }.sorted{$0.fullName<$1.fullName}
                }
            })
            listeners.append(db.collection("chats").addSnapshotListener { [weak self] snap,error in
                Task { @MainActor in
                    guard let self,self.generation==epoch else { return }
                    if let error { self.errorMessage=error.localizedDescription; return }
                    self.chats=(snap?.documents ?? []).map{ChatSummary(id:$0.documentID,pendingCount:($0.data()["pendingAdminCount"] as? NSNumber)?.intValue ?? 0)}
                }
            })
        } else {
            for col in ["correctCards","wrongCards"] {
                listeners.append(db.collection("users").document(profile.id).collection(col).addSnapshotListener { [weak self] snap,error in
                    Task { @MainActor in
                        guard let self,self.generation==epoch else { return }
                        if let error { self.errorMessage=error.localizedDescription; return }
                        let ids=Set((snap?.documents ?? []).filter{$0.data()["collectionName"] as? String == profile.role.cardCollection}.compactMap{$0.data()["cardId"] as? String})
                        if col=="correctCards" { self.correctIDs=ids } else { self.wrongIDs=ids }
                    }
                })
            }
        }
    }
    func login(phone:String,password:String,role:UserRole,remember:Bool) async throws {
        let normalized=LegacyPolicy.normalizePhone(phone)
        let password=password.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !normalized.isEmpty,!password.isEmpty else { throw EditorError.invalid("Telefon ve şifre giriniz.") }
        if demo { loadDemo(role:role); return }
        let result=try await db.collection("users").whereField("phone",isEqualTo:normalized).limit(to:1).getDocuments()
        guard let doc=result.documents.first else { throw EditorError.invalid("Kullanıcı bulunamadı.") }
        guard doc.data()["password"] as? String == password else { throw EditorError.invalid("Şifre yanlış.") }
        guard doc.data()["role"] as? String == role.rawValue else { throw EditorError.invalid("Bu rolde bu kullanıcı yok.") }
        let defaults=UserDefaults.standard
        defaults.set(remember,forKey:"native.remember")
        if remember {defaults.set(doc.documentID,forKey:"native.uid");defaults.set(role.rawValue,forKey:"native.role")}
        else {defaults.removeObject(forKey:"native.uid");defaults.removeObject(forKey:"native.role")}
        try? await writeLoginHistory(doc.documentID)
        observeProfile(uid:doc.documentID)
    }
    func logout() async {
        profileGeneration=UUID();profileListener?.remove(); profileListener=nil; clearData(); profile=nil; loading=false
        for key in ["native.remember","native.uid","native.role"] {UserDefaults.standard.removeObject(forKey:key)}
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
    func call(_ name:String,_ data:[String:Any]) async throws -> [String:Any] {
        guard !demo else { return [:] }
        let result=try await functions.httpsCallable(name).call(data)
        guard let value=result.data as? [String:Any] else { throw DomainError.invalidResponse }
        return value
    }
    func syncDevice() async {
        guard !demo,let uid=profile?.id else { return }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-emulator-testing") { return }
        #endif
        do {
            let granted=try await UNUserNotificationCenter.current().requestAuthorization(options:[.alert,.badge,.sound])
            guard profile?.id==uid else { return }
            guard granted else { return }
            UIApplication.shared.registerForRemoteNotifications()
            guard Messaging.messaging().apnsToken != nil else { return }
            let token=try await Messaging.messaging().token()
            guard profile?.id==uid else { return }
            try await db.collection("users").document(uid).setData(["fcmToken":token,"fcmUpdatedAt":FieldValue.serverTimestamp()],merge:true)
            await scheduleLegacyNotifications(uid:uid)
        } catch { errorMessage="Bildirim kaydı tamamlanamadı: \(error.localizedDescription)" }
    }
    private func scheduleLegacyNotifications(uid:String) async {
        guard let profile,profile.id==uid else{return}
        do {
            let ref=db.collection("users").document(uid).collection("scheduledNotifs")
            let existing=try await ref.getDocuments();let ids=Set(existing.documents.map(\.documentID))
            let templates=try await db.collection("notifications").whereField("targetRole",isEqualTo:profile.role.rawValue).whereField("isActive",isEqualTo:true).getDocuments()
            for doc in templates.documents where !ids.contains(doc.documentID) {
                guard self.profile?.id==uid else{return}
                let data=doc.data(),days=(doc.data()["delayDays"] as? NSNumber)?.intValue ?? 0
                let due=profile.createdAt.addingTimeInterval(Double(days)*86400),past=due<Date()
                if !past {
                    let content=UNMutableNotificationContent();content.title=data["title"] as? String ?? "";content.body=data["body"] as? String ?? "";content.sound = .default
                    content.userInfo=["userId":uid,"type":"template"]
                    let trigger=UNTimeIntervalNotificationTrigger(timeInterval:max(1,due.timeIntervalSinceNow),repeats:false)
                    try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier:"\(uid)_\(doc.documentID)",content:content,trigger:trigger))
                }
                try await ref.document(doc.documentID).setData(["templateId":doc.documentID,"dueAt":Timestamp(date:due),"scheduledAt":FieldValue.serverTimestamp(),"skippedBecausePast":past])
            }
        }catch{errorMessage=error.localizedDescription}
    }
    func saveUser(id:String?,creationID:String,data:[String:Any]) async throws {
        guard !demo else{return}
        var values=data;values["updatedAt"]=FieldValue.serverTimestamp()
        if let id {try await db.collection("users").document(id).updateData(values)}
        else {values["createdAt"]=FieldValue.serverTimestamp();try await db.collection("users").document(creationID).setData(values)}
    }
    func deleteUser(id:String) async throws {
        guard !demo else{return}
        let ref=db.collection("users").document(id)
        for name in ["notifications","loginHistory","scheduledNotifs"] {
            while true {
                let page=try await ref.collection(name).limit(to:200).getDocuments()
                if page.isEmpty {break}
                let batch=db.batch();for doc in page.documents{batch.deleteDocument(doc.reference)};try await batch.commit()
            }
        }
        try await ref.delete()
    }
    func recordAnswer(_ question:QuizQuestion,option:String) async throws -> Bool {
        let correct=option==question.card.answer
        guard !demo else{return correct}
        guard let profile,let col=profile.role.cardCollection else{throw DomainError.invalidProfile}
        let ref=db.collection("users").document(profile.id),id="\(col)_\(question.id)"
        var data:[String:Any]=["cardId":question.id,"collectionName":col,"question":question.card.question,"answer":question.card.answer,"updatedAt":FieldValue.serverTimestamp()]
        let batch=db.batch()
        if correct {data["correctAt"]=FieldValue.serverTimestamp();batch.setData(data,forDocument:ref.collection("correctCards").document(id),merge:true);batch.deleteDocument(ref.collection("wrongCards").document(id))}
        else {data["wrongAt"]=FieldValue.serverTimestamp();data["nextReviewAt"]=Timestamp(date:Date().addingTimeInterval(86400));batch.setData(data,forDocument:ref.collection("wrongCards").document(id),merge:true);batch.deleteDocument(ref.collection("correctCards").document(id))}
        try await batch.commit()
        try await refreshStats(uid:profile.id,assignedCount:eligibleCards.count)
        return correct
    }
    func refreshStats(uid:String,assignedCount:Int) async throws {
        let ref=db.collection("users").document(uid)
        async let correct=ref.collection("correctCards").getDocuments()
        async let wrong=ref.collection("wrongCards").getDocuments()
        async let user=ref.getDocument()
        let (c,w,u)=try await (correct,wrong,user)
        let previous=(u.data()?["quizStats"] as? [String:Any])?["earnedBadges"] as? [Int] ?? []
        let percent=LegacyPolicy.percent(correct:c.count,assigned:assignedCount)
        let badges=Array(Set(previous+[25,50,75,100].filter{percent >= $0})).sorted()
        let latest=badges.filter{!previous.contains($0)}.last ?? badges.last
        try await ref.setData(["quizStats":["assignedCount":assignedCount,"correctCount":c.count,"wrongCount":w.count,"percent":percent,"earnedBadges":badges,"latestBadge":latest.map{ $0 as Any } ?? NSNull(),"updatedAt":FieldValue.serverTimestamp()]],merge:true)
    }
    func openNotification(_ data:[AnyHashable:Any]?) {
        guard let profile,let uid=data?["userId"] as? String else { return }
        NotificationInbox.shared.pending=nil
        guard profile.role == .admin || profile.id==uid else {return}
        if data?["type"] as? String == "template" {notificationRoute = .notifications}
        else {notificationRoute = .chat(uid)}
    }
    func saveContent(collection:String,id:String?,creationID:String,createdAt:Date,data:[String:Any]) async throws {
        guard !demo else { return }
        var values=data; values["updatedAt"]=FieldValue.serverTimestamp()
        if let id { try await db.collection(collection).document(id).updateData(values) }
        else { values["createdAt"]=Timestamp(date:createdAt); try await db.collection(collection).document(creationID).setData(values) }
    }
    func deleteContent(_ item:ContentRecord) async throws { if !demo { try await db.collection(item.collection).document(item.id).delete() } }
    func loadDemo(role:UserRole) {
        profile=try? UserProfile(id:"demo",data:["name":"Test","surname":"Kullanıcı","phone":"+905321234567","role":role.rawValue,"createdAt":Timestamp(date:Date().addingTimeInterval(-1209600))])
        records["sss"]=[ContentRecord(id:"faq",collection:"sss",data:["question":"Destek nasıl alınır?","answer":"Danış ekranından uzman desteği isteyebilirsiniz."])]
        for col in ["MotherLearnCard","UpperLearnCard"] {
            records[col]=(1...4).map{ContentRecord(id:"\($0)",collection:col,data:["bilinen":"Örnek soru \($0)","gercek":"Cevap \($0)","startWeek":1])}
        }
        users=profile.map{[$0]} ?? []; loading=false
    }
}
