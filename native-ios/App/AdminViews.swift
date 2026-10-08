import SwiftUI
import FirebaseFirestore
import RehberlikCore

struct AdminView:View {
    @EnvironmentObject var store:AppStore
    var body:some View {
        TabView {
            NavigationStack{UsersView()}.tabItem{Label("Üyeler",systemImage:"person.2")}
            NavigationStack{ContentListView(kind:.cards)}.tabItem{Label("Kartlar",systemImage:"rectangle.on.rectangle")}
            NavigationStack{ContentListView(kind:.faq)}.tabItem{Label("SSS",systemImage:"questionmark.circle")}
            NavigationStack{ContentListView(kind:.bot)}.tabItem{Label("Chatbot",systemImage:"bubble.left")}
            NavigationStack{ContentListView(kind:.notifications)}.tabItem{Label("Bildirim",systemImage:"bell")}
        }
    }
}
struct UsersView:View {
    @EnvironmentObject var store:AppStore
    @State private var search=""
    @State private var create=false
    @State private var logout=false
    var body:some View {
        List {
            ForEach(UserRole.allCases){role in
                Section(role.rawValue) {
                    ForEach(store.users.filter{$0.role==role && (search.isEmpty || $0.fullName.localizedCaseInsensitiveContains(search) || $0.phone.contains(search))}){user in
                        NavigationLink(destination:UserDetailView(user:user)) {
                            VStack(alignment:.leading){Text(user.fullName);Text(user.phone).font(.caption).foregroundStyle(.secondary)
                                let pending=store.chats.first{$0.id==user.id}?.pendingCount ?? 0
                                if pending>0 {Text("\(pending) yanıt bekleyen soru").font(.caption.bold()).foregroundStyle(.orange)}
                            }
                        }.accessibilityIdentifier("user-\(user.id)")
                    }
                }
            }
        }.navigationTitle("Uzman paneli").searchable(text:$search,prompt:"Ad veya telefon ara")
        .toolbar {
            ToolbarItem(placement:.primaryAction){Button{create=true}label:{Image(systemName:"plus")}.accessibilityLabel("Kullanıcı ekle")}
            ToolbarItem(placement:.navigationBarLeading){Button("Çıkış"){logout=true}}
        }
        .sheet(isPresented:$create){NavigationStack{UserEditor(user:nil)}.environmentObject(store)}
        .confirmationDialog("Oturum kapatılsın mı?",isPresented:$logout){Button("Çıkış yap",role:.destructive){Task{await store.logout()}}}
    }
}
struct UserDetailView:View {
    @EnvironmentObject var store:AppStore
    @Environment(\.dismiss) private var dismiss
    let user:UserProfile
    @State private var edit=false
    @State private var confirmDelete=false
    @State private var busy=false
    var latest:UserProfile {store.users.first{$0.id==user.id} ?? user}
    var body:some View {
        List {
            Section("Kullanıcı"){Text(latest.fullName);Text(latest.phone);Text(latest.role.rawValue)}
            Section {
                NavigationLink("Sohbet ve uzman yanıtları"){ChatView(userID:user.id)}.accessibilityIdentifier("userChat")
                NavigationLink("Giriş geçmişi"){HistoryView(userID:user.id)}
                Button("Kullanıcıyı düzenle"){edit=true}
                Button("Kullanıcıyı sil",role:.destructive){confirmDelete=true}.disabled(busy)
            }
            if busy {ProgressView("Siliniyor…")}
        }.navigationTitle(latest.fullName)
        .sheet(isPresented:$edit){NavigationStack{UserEditor(user:latest)}.environmentObject(store)}
        .confirmationDialog("Kullanıcı, bildirim ve giriş geçmişi silinecek. İşlem geri alınamaz.",isPresented:$confirmDelete,titleVisibility:.visible){
            Button("Kalıcı olarak sil",role:.destructive){busy=true;Task{defer{busy=false};do{try await store.deleteUser(id:user.id);dismiss()}catch{store.errorMessage=error.localizedDescription}}}
        }
    }
}
struct UserEditor:View {
    @EnvironmentObject var store:AppStore
    @Environment(\.dismiss) private var dismiss
    let user:UserProfile?
    @State private var name=""
    @State private var surname=""
    @State private var phone=""
    @State private var password=""
    @State private var role:UserRole = .mother
    @State private var busy=false
    @State private var creationID=UUID().uuidString
    @State private var saveError:String?
    @State private var initialized=false
    var body:some View {
        Form {
            Section("Profil") {
                TextField("Ad",text:$name).textContentType(.givenName).accessibilityIdentifier("editName")
                TextField("Soyad",text:$surname).textContentType(.familyName)
                TextField("Telefon",text:$phone).keyboardType(.phonePad)
                Picker("Rol",selection:$role){ForEach(UserRole.allCases){Text($0.rawValue).tag($0)}}.accessibilityIdentifier("editRole")
            }
            Section(user==nil ? "Şifre":"Şifre değiştir (isteğe bağlı)") {
                SecureField("Şifre",text:$password).textContentType(.newPassword)
                Text("Mevcut şifre görüntülenmez. Boş bırakırsanız değişmez.").font(.caption).foregroundStyle(.secondary)
            }
            if let saveError {Section{Text(saveError).foregroundStyle(.red)}}
            Button("Kaydet") {
                busy=true;Task {
                    defer{busy=false}
                    do {
                        let normalized=LegacyPolicy.normalizePhone(phone)
                        var data:[String:Any]=["name":name.trimmingCharacters(in:.whitespacesAndNewlines),"surname":surname.trimmingCharacters(in:.whitespacesAndNewlines),"phone":normalized,"role":role.rawValue]
                        let trimmed=password.trimmingCharacters(in:.whitespacesAndNewlines)
                        if !trimmed.isEmpty{data["password"]=trimmed}
                        try await store.saveUser(id:user?.id,creationID:creationID,data:data);password="";dismiss()
                    } catch{saveError=error.localizedDescription}
                }
            }.disabled(busy)
            if busy{ProgressView()}
        }.navigationTitle(user==nil ? "Kullanıcı ekle":"Kullanıcı düzenle")
        .toolbar{ToolbarItem(placement:.cancellationAction){Button("Vazgeç"){dismiss()}.disabled(busy)}}
        .onAppear{guard !initialized else{return};initialized=true;if let user{name=user.name;surname=user.surname;phone=user.phone;role=user.role}}
        .interactiveDismissDisabled(busy)
    }
}
enum EditorError:LocalizedError {case invalid(String);var errorDescription:String? {switch self{case .invalid(let message):return message}}}
struct HistoryView:View {
    @EnvironmentObject var store:AppStore
    let userID:String
    @State private var entries:[HistoryEntry]=[]
    @State private var loading=true
    var body:some View {
        List {if loading{ProgressView()};if !loading && entries.isEmpty{Text("Giriş kaydı yok.")};ForEach(entries){Text($0.date,format:.dateTime.day().month().year().hour().minute())}}
        .navigationTitle("Giriş geçmişi")
        .task {
            defer{loading=false};guard !store.demo else{return}
            do {let snap=try await store.db.collection("users").document(userID).collection("loginHistory").order(by:"createdAt",descending:true).limit(to:500).getDocuments()
                entries=snap.documents.compactMap{doc in guard let date=(doc.data()["createdAt"] as? Timestamp)?.dateValue() else{return nil};return HistoryEntry(id:doc.documentID,date:date)}
            }catch{store.errorMessage=error.localizedDescription}
        }
    }
}
enum ContentKind:String,CaseIterable {
    case cards,faq,bot,notifications
    var title:String {switch self{case .cards:return "Öğrenme kartları";case .faq:return "SSS";case .bot:return "Chatbot bilgi tabanı";case .notifications:return "Bildirim şablonları"}}
    func collection(role:UserRole)->String {switch self{case .cards:return role.cardCollection ?? "MotherLearnCard";case .faq:return "sss";case .bot:return "faq_items";case .notifications:return "notifications"}}
}
struct ContentListView:View {
    @EnvironmentObject var store:AppStore
    let kind:ContentKind
    @State private var role:UserRole = .mother
    @State private var search=""
    @State private var create=false
    @State private var editing:ContentRecord?
    @State private var deleting:ContentRecord?
    @State private var busy=false
    var collection:String{kind.collection(role:role)}
    var body:some View {
        List {
            if kind == .cards {Picker("Hedef grup",selection:$role){Text("Anne").tag(UserRole.mother);Text("Üst Kuşak").tag(UserRole.elder)}.pickerStyle(.segmented)}
            let items=(store.records[collection] ?? []).filter{search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.body.localizedCaseInsensitiveContains(search)}
            if items.isEmpty {Text("İçerik bulunmuyor.").foregroundStyle(.secondary)}
            ForEach(items){item in
                Button{editing=item}label:{VStack(alignment:.leading,spacing:6){Text(item.title).font(.headline);Text(item.body).lineLimit(2).foregroundStyle(.secondary);if !item.active{Text("Pasif").font(.caption).foregroundStyle(.orange)}}}.foregroundStyle(.primary)
                    .swipeActions{Button("Sil",role:.destructive){deleting=item}.disabled(busy)}
            }
        }.navigationTitle(kind.title).searchable(text:$search)
        .toolbar{Button{create=true}label:{Image(systemName:"plus")}.accessibilityLabel("İçerik ekle")}
        .sheet(isPresented:$create){NavigationStack{ContentEditor(kind:kind,role:role,item:nil)}.environmentObject(store)}
        .sheet(item:$editing){item in NavigationStack{ContentEditor(kind:kind,role:role,item:item)}.environmentObject(store)}
        .confirmationDialog("İçerik kalıcı olarak silinsin mi?",isPresented:Binding(get:{deleting != nil},set:{if !$0{deleting=nil}}),titleVisibility:.visible){
            Button("Sil",role:.destructive){guard let item=deleting else{return};busy=true;Task{defer{busy=false;deleting=nil};do{try await store.deleteContent(item)}catch{store.errorMessage=error.localizedDescription}}}
        }
    }
}
struct ContentEditor:View {
    @EnvironmentObject var store:AppStore
    @Environment(\.dismiss) private var dismiss
    let kind:ContentKind,role:UserRole,item:ContentRecord?
    @State private var title=""
    @State private var bodyText=""
    @State private var week=1
    @State private var days=0
    @State private var active=true
    @State private var busy=false
    @State private var target:UserRole = .mother
    @State private var creationID=UUID().uuidString
    @State private var createdAt=Date()
    @State private var saveError:String?
    @State private var initialized=false
    var body:some View {
        Form {
            Section(kind == .notifications ? "Başlık":"Soru") {TextField("Metin",text:$title,axis:.vertical).lineLimit(2...6)}
            Section(kind == .notifications ? "Bildirim metni":"Cevap") {TextEditor(text:$bodyText).frame(minHeight:150)}
            if kind == .cards {Section{Stepper("Başlangıç haftası: \(week)",onIncrement:{week+=1},onDecrement:{week=max(0,week-1)})}}
            if kind == .notifications {
                Section{Picker("Hedef rol",selection:$target){ForEach(UserRole.allCases){Text($0.rawValue).tag($0)}};Stepper("Kayıttan sonra gün: \(days)",onIncrement:{days+=1},onDecrement:{days=max(0,days-1)})}
            }
            if kind != .faq {Toggle("Aktif",isOn:$active)}
            if kind == .bot,let issue=item?.data["embeddingError"] as? String {Section("Eşleştirme durumu"){Text(issue).foregroundStyle(.red)}}
            if let saveError {Section{Text(saveError).foregroundStyle(.red)}}
            Button("Kaydet") {
                busy=true;Task {
                    defer{busy=false}
                    do {
                        let question=title.trimmingCharacters(in:.whitespacesAndNewlines),answer=bodyText.trimmingCharacters(in:.whitespacesAndNewlines)
                        guard !question.isEmpty,!answer.isEmpty else{throw EditorError.invalid("Soru/başlık ve cevap/metin giriniz.")}
                        var data:[String:Any]
                        switch kind {
                        case .cards:data=["bilinen":question,"gercek":answer,"startWeek":week,"isActive":active,"targetGroup":role == .mother ? "mother":"upper"]
                        case .faq:data=["question":question,"answer":answer]
                        case .bot:data=["question":question,"answer":answer,"isActive":active]
                        case .notifications:data=["title":question,"body":answer,"delayDays":days,"targetRole":target.rawValue,"isActive":active]
                        }
                        try await store.saveContent(collection:item?.collection ?? kind.collection(role:role),id:item?.id,creationID:creationID,createdAt:createdAt,data:data);dismiss()
                    }catch{saveError=error.localizedDescription}
                }
            }.disabled(busy)
            if busy{ProgressView()}
        }.navigationTitle(item==nil ? "İçerik ekle":"İçerik düzenle")
        .toolbar{ToolbarItem(placement:.cancellationAction){Button("Vazgeç"){dismiss()}.disabled(busy)}}
        .onAppear{guard !initialized else{return};initialized=true;target=role;if let item{title=item.title;bodyText=item.body;active=item.active;week=max(0,(item.data["startWeek"] as? NSNumber)?.intValue ?? 1);days=max(0,(item.data["delayDays"] as? NSNumber)?.intValue ?? 0);target=UserRole(rawValue:item.data["targetRole"] as? String ?? "") ?? role}}
        .interactiveDismissDisabled(busy)
    }
}
