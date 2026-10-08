import SwiftUI
import RehberlikCore
import FirebaseFirestore

struct RootView: View {
    @EnvironmentObject var store:AppStore
    var body:some View {
        Group {
            if store.loading { ProgressView("Yükleniyor…") }
            else if let profile=store.profile {
                if profile.role == .admin { AdminView() } else { HomeView() }
            } else { LoginView() }
        }
        .tint(.indigo)
        .alert("İşlem tamamlanamadı",isPresented:Binding(get:{store.errorMessage != nil},set:{if !$0 {store.errorMessage=nil}})) {
            Button("Tamam",role:.cancel){store.errorMessage=nil}
        } message:{Text(store.errorMessage ?? "")}
        .sheet(item:Binding(get:{store.notificationRoute.map{RouteID(id:$0)}},set:{store.notificationRoute=$0?.id})) { route in
            NavigationStack { ChatView(userID:route.id).toolbar { ToolbarItem(placement:.cancellationAction){Button("Kapat"){store.notificationRoute=nil}} } }.environmentObject(store)
        }
    }
}
struct RouteID:Identifiable { let id:String }
struct LoginView:View {
    @EnvironmentObject var store:AppStore
    @State private var phone=""
    @State private var password=""
    @State private var role:UserRole = .mother
    @State private var remember=false
    @State private var busy=false
    var body:some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing:12) {
                        Image(systemName:"heart.circle.fill").font(.system(size:64)).foregroundStyle(.pink)
                        Text("Rehberlik").font(.largeTitle.bold())
                        Text("Öğren, danış, birlikte güçlen.").foregroundStyle(.secondary)
                    }.frame(maxWidth:.infinity).padding()
                }
                Section("Giriş") {
                    Picker("Rol",selection:$role){ForEach(UserRole.allCases){Text($0.rawValue).tag($0)}}.pickerStyle(.segmented).accessibilityIdentifier("rolePicker")
                    TextField("Telefon numarası",text:$phone).keyboardType(.phonePad).textContentType(.telephoneNumber).accessibilityIdentifier("phone")
                    SecureField("Şifre",text:$password).textContentType(.password).accessibilityIdentifier("password")
                    Toggle("Beni hatırla",isOn:$remember)
                    Button {
                        busy=true
                        Task {
                            defer {busy=false}
                            do { try await store.login(phone:phone,password:password,role:role,remember:remember); password="" }
                            catch {store.errorMessage=error.localizedDescription}
                        }
                    } label:{HStack{Text("Giriş yap"); Spacer(); if busy {ProgressView()}}}
                    .disabled(busy || phone.isEmpty || password.isEmpty).accessibilityIdentifier("login")
                }
                Section { Text("Hesabınız uzman tarafından oluşturulur. Erişim sorununuz varsa proje sorumlusuna başvurunuz.").font(.footnote).foregroundStyle(.secondary) }
            }.navigationTitle("Hoş geldiniz").scrollDismissesKeyboard(.interactively)
        }
    }
}
struct HomeView:View {
    @EnvironmentObject var store:AppStore
    @State private var logoutConfirmation=false
    var body:some View {
        NavigationStack {
            List {
                Section {
                    Text("Merhaba, \(store.profile?.name ?? "")").font(.title2.bold())
                    Text(store.profile?.role.rawValue ?? "").foregroundStyle(.secondary)
                    ProgressView(value:Double(store.summary.percent),total:100)
                    Text("\(store.summary.correctCount) / \(store.summary.assignedCount) doğru · %\(store.summary.percent)").font(.subheadline)
                }
                Section("Birlikte öğrenelim") {
                    NavigationLink(destination:QuizView()){Label("Öğrenme kartları",systemImage:"rectangle.on.rectangle")}.accessibilityIdentifier("learning")
                    NavigationLink(destination:ChatView(userID:store.profile?.id ?? "")){Label("Danış",systemImage:"bubble.left.and.bubble.right")}
                    NavigationLink(destination:FAQView()){Label("Sıkça sorulan sorular",systemImage:"questionmark.circle")}
                    NavigationLink(destination:NotificationsView()){Label("Bildirimler",systemImage:"bell")}
                    NavigationLink(destination:BadgesView()){Label("Rozetlerim",systemImage:"medal")}
                }
                Button("Çıkış yap",role:.destructive){logoutConfirmation=true}.accessibilityIdentifier("logout")
            }.navigationTitle("Rehberlik")
            .confirmationDialog("Oturum kapatılsın mı?",isPresented:$logoutConfirmation,titleVisibility:.visible){Button("Çıkış yap",role:.destructive){Task{await store.logout()}}}
        }
    }
}
struct FAQView:View {
    @EnvironmentObject var store:AppStore
    @State private var search=""
    var items:[ContentRecord] {(store.records["sss"] ?? []).filter{search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.body.localizedCaseInsensitiveContains(search)}}
    var body:some View {
        List {
            if items.isEmpty {Text("Henüz içerik bulunmuyor.").foregroundStyle(.secondary)}
            ForEach(items){item in DisclosureGroup(item.title){Text(item.body).textSelection(.enabled).padding(.vertical)}}
        }.navigationTitle("Sıkça sorulan sorular").searchable(text:$search,prompt:"Soru veya cevap ara")
    }
}
struct BadgesView:View {
    @EnvironmentObject var store:AppStore
    var body:some View {
        List {
            Text("Güncel başarı: %\(store.summary.percent)")
            ForEach([25,50,75,100],id:\.self){level in
                Label("%\(level) Bilgi Ustası",systemImage:store.summary.earnedBadges.contains(level) ? "medal.fill":"lock")
                    .foregroundStyle(store.summary.earnedBadges.contains(level) ? .orange:.secondary)
            }
            Text("Kazanılan rozetler korunur. Güncel başarı yalnızca açık ve aktif kartlardan hesaplanır.").font(.footnote).foregroundStyle(.secondary)
        }.navigationTitle("Rozetlerim")
    }
}
struct NotificationsView:View {
    @EnvironmentObject var store:AppStore
    @State private var now=Date()
    let timer=Timer.publish(every:30,on:.main,in:.common).autoconnect()
    func due(_ item:ContentRecord)->Date { (store.profile?.createdAt ?? now).addingTimeInterval(Double((item.data["delayDays"] as? NSNumber)?.intValue ?? 0)*86400) }
    var body:some View {
        List {
            ForEach([true,false],id:\.self){arrived in
                Section(arrived ? "Zamanı gelenler":"Yaklaşanlar") {
                    let items=(store.records["notifications"] ?? []).filter{(due($0)<=now)==arrived}.sorted{due($0)<due($1)}
                    if items.isEmpty {Text("Bildirim bulunmuyor.").foregroundStyle(.secondary)}
                    ForEach(items){item in VStack(alignment:.leading,spacing:8){Text(item.title).font(.headline);Text(item.body);Text(due(item),style:.date).font(.caption).foregroundStyle(.secondary)}}
                }
            }
            Section { Button("Bildirim iznini kontrol et"){Task{await store.syncDevice()}} }
        }.navigationTitle("Bildirimler").onReceive(timer){now=$0}
    }
}
struct QuizView:View {
    @EnvironmentObject var store:AppStore
    @State private var questions:[QuizQuestion]=[]
    @State private var index=0
    @State private var selected:String?
    @State private var correct:Bool?
    @State private var busy=false
    @State private var showAnswer=false
    @State private var attemptID=UUID().uuidString
    @State private var failedOption:String?
    @State private var mode:String?
    @State private var completed=false
    func start(wrong:Bool) {
        do {
            var random=SystemRandomNumberGenerator()
            let all=try LearningPolicy.questions(store.eligibleCards,using:&random)
            questions=wrong ? all.filter{store.wrongIDs.contains($0.id)}:all
            guard !questions.isEmpty else {store.errorMessage="Tekrar çözülecek yanlış soru bulunmuyor.";return}
            index=0; mode=wrong ? "Yanlış sorular":"Normal sorular"; completed=false; reset()
        } catch {store.errorMessage=error.localizedDescription}
    }
    func reset(){selected=nil;correct=nil;busy=false;showAnswer=false;failedOption=nil;attemptID=UUID().uuidString}
    func submit(_ option:String) {
        guard !busy,selected==nil,index<questions.count else {return}
        busy=true; failedOption=option
        let question=questions[index]
        Task {
            defer{busy=false}
            do {
                let response=try await store.call("recordQuizAnswer",["cardId":question.id,"answer":option,"attemptId":attemptID,"question":question.card.question,"expectedAnswer":question.card.answer])
                let result:Bool
                if store.demo {result=option==question.card.answer}
                else {guard let value=response["isCorrect"] as? Bool else {throw DomainError.invalidResponse};result=value}
                selected=option; correct=result;failedOption=nil
                if result {store.correctIDs.insert(question.id);store.wrongIDs.remove(question.id)}
                else {store.wrongIDs.insert(question.id);store.correctIDs.remove(question.id)}
            } catch {store.errorMessage="Cevap kaydedilemedi. Aynı cevabı yeniden deneyebilirsiniz. \(error.localizedDescription)"}
        }
    }
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:20) {
                if completed {Label("Tur tamamlandı",systemImage:"checkmark.circle.fill").font(.title);Text("Cevaplarınız kaydedildi.")}
                if mode==nil {
                    Text("Bilgini test et").font(.largeTitle.bold())
                    Text("\(store.eligibleCards.count) açık kart · \(store.summary.wrongCount) yanlış")
                    Button("Normal sorular"){start(wrong:false)}.buttonStyle(.borderedProminent).accessibilityIdentifier("normalQuiz")
                    Button("Yanlış sorular"){start(wrong:true)}.buttonStyle(.bordered).disabled(store.summary.wrongCount==0)
                    if store.eligibleCards.isEmpty {Text("Henüz açık öğrenme kartı bulunmuyor.")}
                } else if index<questions.count {
                    let question=questions[index]
                    Text("\(mode ?? "") · \(index+1) / \(questions.count)").foregroundStyle(.secondary)
                    Text(question.card.question).font(.title2.bold()).frame(maxWidth:.infinity,alignment:.leading).padding().background(.indigo.opacity(0.08),in:RoundedRectangle(cornerRadius:20))
                    if !showAnswer {Button("Seçenekleri göster"){showAnswer=true}.buttonStyle(.borderedProminent)}
                    else {
                        ForEach(Array(question.options.enumerated()),id:\.offset){offset,option in
                            Button{submit(option)} label:{HStack(alignment:.top){Text(["A","B","C","D"][offset]).bold();Text(option);Spacer();if selected != nil && option==question.card.answer {Image(systemName:"checkmark.circle.fill")}}.frame(maxWidth:.infinity,alignment:.leading).padding()}
                                .buttonStyle(.bordered).disabled(busy || selected != nil || (failedOption != nil && failedOption != option))
                        }
                    }
                    if busy {ProgressView("Kaydediliyor…")}
                    if let correct {Text(correct ? "Doğru cevap!":"Yanlış cevap. Doğru cevap: \(question.card.answer)").foregroundStyle(correct ? .green:.red)}
                    if selected != nil {Button(index+1==questions.count ? "Turu bitir":"Sonraki soru") {
                        if index+1==questions.count {mode=nil;completed=true;questions=[]} else {index+=1;reset()}
                    }.buttonStyle(.borderedProminent)}
                    Button("Mod seçimine dön"){mode=nil;questions=[]}.disabled(busy)
                }
            }.padding().frame(maxWidth:650,alignment:.leading).frame(maxWidth:.infinity)
        }.navigationTitle("Öğrenme kartları").navigationBarTitleDisplayMode(.inline)
    }
}
