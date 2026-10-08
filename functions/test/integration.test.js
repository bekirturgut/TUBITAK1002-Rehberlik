const {test,before,after,beforeEach}=require("node:test");
const assert=require("node:assert/strict");
const fs=require("node:fs");
const {initializeTestEnvironment,assertSucceeds,assertFails}=require("@firebase/rules-unit-testing");
const {doc,getDoc,setDoc,updateDoc,collection,getDocs,query,where}=require("firebase/firestore");
if(!process.env.FIRESTORE_EMULATOR_HOST) throw new Error("Integration tests require emulator; live execution refused.");
process.env.GCLOUD_PROJECT="demo-rehberlik";
const api=require("../native-api");
const {getFirestore,Timestamp}=require("firebase-admin/firestore");const {getApp,deleteApp}=require("firebase-admin/app");
const db=getFirestore();
let env;
const request=(uid,data)=>({auth:uid?{uid,token:{}}:undefined,data,rawRequest:{ip:"127.0.0.1"}});
const run=(name,uid,data)=>api[name].run(request(uid,data));
const profile=(role="Anne")=>({role,name:"Test",surname:"User",phone:"+905321234567",createdAt:Timestamp.fromMillis(Date.now()-1209600000)});
before(async()=>{env=await initializeTestEnvironment({projectId:"demo-rehberlik",firestore:{rules:fs.readFileSync("../firestore.rules","utf8")}})});
after(async()=>{await env.cleanup();await deleteApp(getApp())});
beforeEach(async()=>{
  await env.clearFirestore();
  await db.doc("users/mother").set(profile());await db.doc("users/elder").set({...profile("Üst Kuşak"),phone:"+905321234568"});await db.doc("users/admin").set({...profile("Admin"),phone:"+905321234569"});
  const batch=db.batch();for(let i=1;i<=4;i++) batch.set(db.doc(`MotherLearnCard/c${i}`),{bilinen:`Q${i}`,gercek:`A${i}`,startWeek:1,isActive:true,targetGroup:"mother"});await batch.commit();
});
test("unauthenticated and cross-user reads are denied; credentials never readable",async()=>{
  const anon=env.unauthenticatedContext().firestore(),mother=env.authenticatedContext("mother").firestore(),expert=env.authenticatedContext("admin").firestore();
  await assertFails(getDoc(doc(anon,"users/mother")));
  await assertFails(getDoc(doc(mother,"users/elder")));
  await assertSucceeds(getDoc(doc(mother,"users/mother")));
  await assertSucceeds(getDoc(doc(expert,"users/mother")));
  await db.doc("_credentials/mother").set({salt:"secret",hash:"secret"});
  await assertFails(getDoc(doc(mother,"_credentials/mother")));await assertFails(getDoc(doc(expert,"_credentials/mother")));
});
test("clients cannot promote roles, forge quiz/bot/admin messages or register tokens directly",async()=>{
  const mother=env.authenticatedContext("mother").firestore();
  for(const [path,data] of [["users/mother",{role:"Admin"}],["users/mother/correctCards/forged",{cardId:"c1"}],["chats/mother/messages/forged",{senderType:"admin"}],["_devices/forged",{uid:"elder",token:"x"}]]) await assertFails(setDoc(doc(mother,path),data));
});
test("admin content CRUD validates schema; learner cannot edit or read opposite-role cards",async()=>{
  const expert=env.authenticatedContext("admin").firestore(),mother=env.authenticatedContext("mother").firestore();
  await assertSucceeds(setDoc(doc(expert,"sss/one"),{question:"Q",answer:"A"}));
  await assertFails(setDoc(doc(expert,"sss/bad"),{question:"",answer:"A"}));
  await assertFails(setDoc(doc(mother,"sss/one"),{question:"Q",answer:"A"}));
  await assertFails(getDoc(doc(mother,"UpperLearnCard/anything")));
  await assertSucceeds(getDocs(collection(mother,"MotherLearnCard")));
  await assertSucceeds(setDoc(doc(expert,"faq_items/faq"),{question:"Q",answer:"A",isActive:true}));
  await assertFails(updateDoc(doc(expert,"faq_items/faq"),{embedding:[1,2]}));
  await assertSucceeds(updateDoc(doc(expert,"faq_items/faq"),{question:"new"}));
});
test("role-filtered notification queries work and unrestricted user query fails",async()=>{
  await db.doc("notifications/m").set({title:"T",body:"B",isActive:true,targetRole:"Anne",delayDays:1});
  const mother=env.authenticatedContext("mother").firestore();
  await assertSucceeds(getDocs(query(collection(mother,"notifications"),where("targetRole","==","Anne"),where("isActive","==",true))));
  await assertFails(getDocs(collection(mother,"notifications")));
});
test("disabled and deleting profiles lose access and callable permission",async()=>{
  await db.doc("users/mother").update({disabled:true});
  await assertFails(getDoc(doc(env.authenticatedContext("mother").firestore(),"users/mother")));
  await assert.rejects(run("recordQuizAnswer","mother",{cardId:"c1",answer:"A1",attemptId:"x"}),{code:"permission-denied"});
});
test("all sensitive callable endpoints require authentication",async()=>{
  for(const name of ["saveNativeUser","deleteNativeUser","recordQuizAnswer","sendNativeMessage","askFaqBot","escalateChatToAdmin","rateNativeAnswer","updateNativeDevice"]) await assert.rejects(run(name,null,{}),{code:"unauthenticated"});
});
test("answer updates correct/wrong atomically, retries are idempotent and invalid cards fail",async()=>{
  let result=await run("recordQuizAnswer","mother",{cardId:"c1",answer:"A2",attemptId:"try1"});
  assert.equal(result.isCorrect,false);assert.equal(result.stats.wrongCount,1);
  result=await run("recordQuizAnswer","mother",{cardId:"c1",answer:"A1",attemptId:"try2"});
  assert.equal(result.isCorrect,true);assert.equal(result.stats.wrongCount,0);assert.equal(result.stats.percent,25);
  assert.deepEqual(await run("recordQuizAnswer","mother",{cardId:"c1",answer:"A1",attemptId:"try2"}),result);
  await assert.rejects(run("recordQuizAnswer","mother",{cardId:"c1",answer:"A2",attemptId:"try2"}),{code:"already-exists"});
  assert.equal((await db.doc("users/mother/wrongCards/MotherLearnCard_c1").get()).exists,false);
  await db.doc("MotherLearnCard/c2").update({isActive:false});
  await assert.rejects(run("recordQuizAnswer","mother",{cardId:"c2",answer:"A2",attemptId:"try3"}),{code:"failed-precondition"});
});
test("parallel answer submissions retain both results and exclude stale cards",async()=>{
  await db.doc("users/mother/correctCards/stale").set({cardId:"deleted",collectionName:"MotherLearnCard"});
  await Promise.all([run("recordQuizAnswer","mother",{cardId:"c1",answer:"A1",attemptId:"parallel1"}),run("recordQuizAnswer","mother",{cardId:"c2",answer:"A2",attemptId:"parallel2"})]);
  const stats=(await db.doc("users/mother").get()).data().quizStats;
  assert.equal(stats.correctCount,2);assert.equal(stats.percent,50);assert.deepEqual(stats.earnedBadges,[25,50]);
});
test("user spoofing is ignored and message retry does not duplicate; admin identity is real",async()=>{
  await run("sendNativeMessage","mother",{userId:"elder",messageId:"m1",text:"Question"});
  await run("sendNativeMessage","mother",{userId:"elder",messageId:"m1",text:"Question"});
  assert.equal((await db.collection("chats/mother/messages").get()).size,1);
  assert.equal((await db.collection("chats/elder/messages").get()).size,0);
  await run("escalateChatToAdmin","mother",{sourceMessageId:"m1"});
  await run("sendNativeMessage","admin",{userId:"mother",messageId:"a1",text:"Answer",replyToMessageId:"m1"});
  const question=(await db.doc("chats/mother/messages/m1").get()).data();
  assert.equal(question.answeredBy,"admin");assert.equal(question.isAnswered,true);
  assert.equal((await db.doc("chats/mother").get()).data().pendingAdminCount,0);
  assert.equal((await db.doc("sendQueue/reply_mother_a1").get()).exists,true);
});
test("cross-user escalation fails and learner cannot create users or delete accounts",async()=>{
  await run("sendNativeMessage","elder",{messageId:"m1",text:"Q"});
  await assert.rejects(run("escalateChatToAdmin","mother",{sourceMessageId:"m1"}),{code:"permission-denied"});
  await assert.rejects(run("saveNativeUser","mother",{}),{code:"permission-denied"});
  await assert.rejects(run("deleteNativeUser","mother",{id:"elder"}),{code:"permission-denied"});
  await assert.rejects(run("deleteNativeUser","admin",{id:"admin"}),{code:"failed-precondition"});
});
test("device belongs to one account and old logout cannot detach new owner",async()=>{
  await run("updateNativeDevice","mother",{installationId:"device",token:"token1"});
  await run("updateNativeDevice","elder",{installationId:"device",token:"token2"});
  await run("updateNativeDevice","mother",{installationId:"device"});
  assert.equal((await db.doc("_devices/device").get()).data().uid,"elder");
  await run("updateNativeDevice","elder",{installationId:"device"});
  assert.equal((await db.doc("_devices/device").get()).exists,false);
});
test("duplicate normalized phones rejected and new users have private hashed credentials",async()=>{
  const data={name:"New",surname:"User",phone:"+905321234560",password:"secure-password",role:"Anne"};
  const result=await run("saveNativeUser","admin",data);
  assert.equal((await db.doc(`users/${result.id}`).get()).data().password,undefined);
  assert.equal((await db.doc(`_credentials/${result.id}`).get()).exists,true);
  await assert.rejects(run("saveNativeUser","admin",{...data,phone:"05321234560"}),{code:"already-exists"});
});
