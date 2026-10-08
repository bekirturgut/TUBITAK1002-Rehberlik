import SwiftUI
import FirebaseFirestore

@MainActor
final class ChatModel:ObservableObject {
    @Published var messages:[ChatMessage]=[]
    @Published var loading=true
    @Published var busy=false
    @Published var error:String?
    @Published var draft=""
    @Published var replyingTo:ChatMessage?
    @Published var retryBotID:String?
    private var listener:ListenerRegistration?
    private var pendingID:String?
    private var pendingText:String?
    private var active=true
    func start(store:AppStore,uid:String) {
        stop();active=true
        if store.demo {messages=[];loading=false;return}
        listener=store.db.collection("chats").document(uid).collection("messages").order(by:"createdAt",descending:true).limit(to:300).addSnapshotListener{[weak self] snap,error in
            Task{@MainActor in guard let self,self.active else{return};self.loading=false
                if let error {self.error=error.localizedDescription;return}
                self.messages=(snap?.documents ?? []).reversed().map{ChatMessage(id:$0.documentID,data:$0.data())}
            }
        }
    }
    func stop(){active=false;listener?.remove();listener=nil}
    deinit{listener?.remove()}
    func send(store:AppStore,uid:String) async {
        guard !busy else{return}
        let text=draft.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !text.isEmpty,text.count<=2000 else{error="Mesaj 1–2000 karakter olmalıdır.";return}
        guard store.profile?.role != .admin || replyingTo != nil else{error="Önce cevaplayacağınız soruyu seçiniz.";return}
        if pendingText != text {pendingID=UUID().uuidString;pendingText=text}
        let id=pendingID ?? UUID().uuidString
        busy=true;defer{busy=false}
        do {
            var payload:[String:Any]=["userId":uid,"messageId":id,"text":text]
            if let reply=replyingTo {payload["replyToMessageId"]=reply.id}
            _=try await store.call("sendNativeMessage",payload)
            draft="";pendingID=nil;pendingText=nil;replyingTo=nil
            if store.demo {messages.append(ChatMessage(id:id,data:["text":text,"senderType":"user"]))}
            else if store.profile?.role != .admin {await askBot(store:store,id:id)}
        } catch{self.error=error.localizedDescription}
    }
    func askBot(store:AppStore,id:String) async {
        do {_=try await store.call("askFaqBot",["sourceMessageId":id]);retryBotID=nil}
        catch{retryBotID=id;self.error="Sorunuz kaydedildi, bot yanıtı alınamadı. Yeniden deneyebilir veya uzmana iletebilirsiniz."}
    }
    func escalate(store:AppStore,id:String) async {
        do {_=try await store.call("escalateChatToAdmin",["sourceMessageId":id]);retryBotID=nil}
        catch{self.error=error.localizedDescription}
    }
    func feedback(store:AppStore,message:ChatMessage,sufficient:Bool) async {
        do {_=try await store.call("rateNativeAnswer",["messageId":message.id,"isSufficient":sufficient])}
        catch{self.error=error.localizedDescription}
    }
}
struct ChatView:View {
    @EnvironmentObject var store:AppStore
    let userID:String
    @StateObject private var model=ChatModel()
    @State private var feedbackBusy=false
    var body:some View {
        VStack(spacing:0) {
            ScrollViewReader{proxy in
                ScrollView {
                    LazyVStack(alignment:.leading,spacing:14) {
                        if model.loading {ProgressView()}
                        if !model.loading && model.messages.isEmpty {Text("Sorunuzu yazarak başlayabilirsiniz.").foregroundStyle(.secondary).padding()}
                        ForEach(model.messages){message in
                            VStack(alignment:.leading,spacing:8) {
                                Text(message.senderType=="admin" ? "Uzman":message.senderType=="bot" ? "Asistan":"Kullanıcı").font(.caption.bold()).foregroundStyle(.secondary)
                                Text(message.text).textSelection(.enabled)
                                if message.pending && !message.answered {Label("Uzman yanıtı bekleniyor",systemImage:"clock").font(.caption)}
                                if message.answered {Label("Uzman yanıtladı",systemImage:"checkmark.circle").font(.caption).foregroundStyle(.green)}
                                if store.profile?.role == .admin && message.senderType=="user" {Button("Bu soruyu yanıtla"){model.replyingTo=message}}
                                if store.profile?.role != .admin && message.needsFeedback && !message.feedbackGiven {
                                    HStack{ForEach([true,false],id:\.self){sufficient in Button(sufficient ? "Yeterli":"Uzmana ilet"){
                                        feedbackBusy=true;Task{defer{feedbackBusy=false};await model.feedback(store:store,message:message,sufficient:sufficient)}
                                    }.disabled(feedbackBusy)}}
                                }
                                Text(message.createdAt,style:.time).font(.caption2).foregroundStyle(.secondary)
                            }.padding().frame(maxWidth:.infinity,alignment:.leading).background(message.senderType=="admin" ? Color.orange.opacity(0.12):message.senderType=="bot" ? Color.gray.opacity(0.08):Color.blue.opacity(0.1),in:RoundedRectangle(cornerRadius:16)).id(message.id)
                        }
                    }.padding()
                }.onChange(of:model.messages.count){_ in if let id=model.messages.last?.id {proxy.scrollTo(id,anchor:.bottom)}}
            }
            if let id=model.retryBotID {HStack{Button("Botu tekrar dene"){Task{await model.askBot(store:store,id:id)}};Button("Uzmana ilet"){Task{await model.escalate(store:store,id:id)}}}.font(.footnote).padding()}
            if let reply=model.replyingTo {HStack{Text("Yanıt: \(reply.text)").lineLimit(2);Spacer();Button("Vazgeç"){model.replyingTo=nil}}.font(.caption).padding()}
            HStack(alignment:.bottom) {
                TextField("Mesajınızı yazınız",text:$model.draft,axis:.vertical).lineLimit(1...5).textFieldStyle(.roundedBorder).accessibilityIdentifier("chatDraft")
                Button{Task{await model.send(store:store,uid:userID)}} label:{if model.busy {ProgressView()} else{Image(systemName:"paperplane.fill")}}
                    .disabled(model.busy || model.draft.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty).accessibilityLabel("Mesaj gönder").accessibilityIdentifier("chatSend")
            }.padding().background(.bar)
        }.navigationTitle(store.profile?.role == .admin ? "Kullanıcı sohbeti":"Danış").navigationBarTitleDisplayMode(.inline)
        .task(id:userID){model.start(store:store,uid:userID)}.onDisappear{model.stop()}
        .alert("Sohbet",isPresented:Binding(get:{model.error != nil},set:{if !$0 {model.error=nil}})){Button("Tamam"){model.error=nil}} message:{Text(model.error ?? "")}
    }
}
