import Foundation
import SwiftUI
import FirebaseAuth
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
    @Published var correctIDs: Set<String> = [], wrongIDs: Set<String> = []
    @Published var chats: [ChatSummary] = []
    @Published var notificationRoute: String?
    private var started=false
    private var authHandle: AuthStateDidChangeListenerHandle?
    private var profileListener: ListenerRegistration?
    private var listeners: [ListenerRegistration] = []
    private var generation=UUID()
    let demo=ProcessInfo.processInfo.arguments.contains("-ui-testing")
    var db: Firestore { Firestore.firestore() }
    var functions: Functions { Functions.functions(region:"europe-west1") }
    var eligibleCards: [LearningCard] {
        guard let profile,let col=profile.role.cardCollection else { return [] }
        return LearningPolicy.eligible((records[col] ?? []).map(\.card),week:LearningPolicy.currentWeek(createdAt:profile.createdAt))
    }
    var summary: QuizSummary { QuizSummary(cards:eligibleCards,correct:correctIDs,wrong:wrongIDs,previouslyEarned:profile?.earnedBadges ?? []) }
    var installationID: String {
        if let id=UserDefaults.standard.string(forKey:"native.installationID") { return id }
        let id=UUID().uuidString; UserDefaults.standard.set(id,forKey:"native.installationID"); return id
    }
    func start() {
        guard !started else { return }; started=true
        if demo { loading=false; return }
        if !UserDefaults.standard.bool(forKey:"native.remember") { try? Auth.auth().signOut() }
        authHandle=Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in self?.observeProfile(uid:user?.uid) }
        }
    }
    private func clearData() {
        generation=UUID(); listeners.forEach{$0.remove()}; listeners=[]
        records=[:]; users=[]; correctIDs=[]; wrongIDs=[]; chats=[]; notificationRoute=nil
    }
    private func observeProfile(uid:String?) {
        profileListener?.remove(); profileListener=nil; clearData(); profile=nil
        guard let uid else { loading=false; return }
        loading=true
        profileListener=db.collection("users").document(uid).addSnapshotListener { [weak self] snap,error in
            Task { @MainActor in
                guard let self,Auth.auth().currentUser?.uid==uid else { return }
                if let error {
                    self.errorMessage=error.localizedDescription; self.loading=false
                    if (error as NSError).code == FirestoreErrorCode.permissionDenied.rawValue { await self.logout() }
                    return
                }
                do {
                    guard let snap,snap.exists else { throw DomainError.invalidProfile }
                    let next=try UserProfile(id:uid,data:snap.data() ?? [:])
                    guard !next.disabled else { throw DomainError.invalidProfile }
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
        let normalized=try PhoneNumber.normalize(phone)
        if demo { loadDemo(role:role); return }
        let response=try await call("loginWithPhone",["phone":normalized,"password":password,"role":role.rawValue])
        guard let token=response["token"] as? String else { throw DomainError.invalidResponse }
        UserDefaults.standard.set(remember,forKey:"native.remember")
        _=try await Auth.auth().signIn(withCustomToken:token)
    }
    func logout() async {
        if !demo {
            do { _=try await call("updateNativeDevice",["installationId":installationID]) }
            catch { // Delete the token before losing the authenticated session if server detach fails.
                try? await Messaging.messaging().deleteToken()
            }
            try? Auth.auth().signOut()
        }
        profileListener?.remove(); profileListener=nil; clearData(); profile=nil; loading=false
        UserDefaults.standard.set(false,forKey:"native.remember")
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
        do {
            let granted=try await UNUserNotificationCenter.current().requestAuthorization(options:[.alert,.badge,.sound])
            guard profile?.id==uid else { return }
            guard granted else { _=try await call("updateNativeDevice",["installationId":installationID]); return }
            UIApplication.shared.registerForRemoteNotifications()
            guard Messaging.messaging().apnsToken != nil else { return }
            let token=try await Messaging.messaging().token()
            guard profile?.id==uid else { return }
            _=try await call("updateNativeDevice",["installationId":installationID,"token":token])
        } catch { errorMessage="Bildirim kaydı tamamlanamadı: \(error.localizedDescription)" }
    }
    func openNotification(_ data:[AnyHashable:Any]?) {
        guard let profile,let uid=data?["userId"] as? String else { return }
        NotificationInbox.shared.pending=nil
        if profile.role == .admin || profile.id==uid { notificationRoute=uid }
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
