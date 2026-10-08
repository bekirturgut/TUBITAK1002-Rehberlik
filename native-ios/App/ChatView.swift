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
    private var pendingReplyID:String?
    private var generation=UUID()
    func start(store:AppStore,uid:String) {
        stop();let epoch=generation
        messages=[];loading=true;error=nil;replyingTo=nil;retryBotID=nil
        pendingID=nil;pendingText=nil;pendingReplyID=nil
        if store.demo {messages=[];loading=false;return}
        listener=store.db.collection("chats").document(uid).collection("messages").order(by:"createdAt",descending:true).addSnapshotListener{[weak self] snap,error in
            Task{@MainActor in guard let self,self.generation==epoch else{return};self.loading=false
                if let error {self.error=error.localizedDescription;return}
                self.messages=(snap?.documents ?? []).reversed().map{ChatMessage(id:$0.documentID,data:$0.data())}
            }
        }
    }
    func stop(){generation=UUID();listener?.remove();listener=nil}
    deinit{listener?.remove()}
    func send(store:AppStore,uid:String) async {
        guard !busy else{return}
        let text=draft.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !text.isEmpty else{return}
        if pendingText != text || pendingReplyID != replyingTo?.id {pendingID=UUID().uuidString;pendingText=text;pendingReplyID=replyingTo?.id}
        let id=pendingID ?? UUID().uuidString
        busy=true;defer{busy=false}
        do {
            if store.demo {messages.append(ChatMessage(id:id,data:["text":text,"senderType":"user"]))}
            else {
                let chat=store.db.collection("chats").document(uid)
                try await chat.setData(["userId":uid,"createdAt":FieldValue.serverTimestamp(),"updatedAt":FieldValue.serverTimestamp()],merge:true)
                var data:[String:Any]=["text":text,"senderType":store.profile?.role == .admin ? "admin":"user","senderRole":store.profile?.role.rawValue ?? "","senderId":uid,"createdAt":FieldValue.serverTimestamp()]
                if store.profile?.role == .admin {data["replyToMessageId"]=replyingTo?.id ?? "";data["replyToText"]=replyingTo?.text ?? ""}
                else {data["needsAdminReply"]=false;data["isAnswered"]=false}
                try await chat.collection("messages").document(id).setData(data)
                try await chat.setData(["updatedAt":FieldValue.serverTimestamp()],merge:true)
            }
            draft="";pendingID=nil;pendingText=nil;replyingTo=nil
            if !store.demo && store.profile?.role != .admin {await askBot(store:store,id:id)}
        } catch{self.error=error.localizedDescription}
    }
    func askBot(store:AppStore,id:String) async {
        guard let uid=store.profile?.id else{return}
        do {
            let chat=store.db.collection("chats").document(uid)
            let source=try await chat.collection("messages").document(id).getDocument()
            let question=source.data()?["text"] as? String ?? ""
            let result=try await store.call("askFaqBot",["question":question,"userId":uid,"sourceMessageId":id])
            let needsFeedback=result["needsFeedback"] as? Bool ?? false
            _=try await chat.collection("messages").addDocument(data:["text":result["answer"] as? String ?? "","senderType":"bot","senderId":"chatbot","createdAt":FieldValue.serverTimestamp(),"relatedQuestion":question,"sourceMessageId":id,"score":result["score"] as? Double ?? 0,"needsFeedback":needsFeedback,"showFeedbackButtons":needsFeedback,"feedbackGiven":false,"isSufficient":NSNull(),"escalated":result["escalated"] as? Bool ?? false])
            retryBotID=nil
        }catch{retryBotID=id;self.error="Sorunuz kaydedildi, bot yanıtı alınamadı. Yeniden deneyebilirsiniz."}
    }
    func escalate(store:AppStore,id:String) async {
        guard let uid=store.profile?.id else{return}
        do {
            let source=try await store.db.collection("chats").document(uid).collection("messages").document(id).getDocument()
            _=try await store.call("escalateChatToAdmin",["userId":uid,"sourceMessageId":id,"question":source.data()?["text"] as? String ?? "","score":0]);retryBotID=nil
        }catch{self.error=error.localizedDescription}
    }
    func feedback(store:AppStore,message:ChatMessage,sufficient:Bool) async {
        guard let uid=store.profile?.id else{return}
        do {
            let ref=store.db.collection("chats").document(uid).collection("messages").document(message.id)
            let source=try await ref.getDocument(),data=source.data() ?? [:]
            try await ref.updateData(["feedbackGiven":true,"isSufficient":sufficient,"showFeedbackButtons":false,"feedbackAt":FieldValue.serverTimestamp()])
            if !sufficient {_=try await store.call("escalateChatToAdmin",["userId":uid,"question":data["relatedQuestion"] as? String ?? "","score":data["score"] as? Double ?? 0,"sourceMessageId":data["sourceMessageId"] as? String ?? ""])}
        }catch{self.error=error.localizedDescription}
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
