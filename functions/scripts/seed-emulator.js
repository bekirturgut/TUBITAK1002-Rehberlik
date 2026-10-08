const {initializeApp}=require("firebase-admin/app");const {getFirestore,Timestamp}=require("firebase-admin/firestore");const D=require("../domain");
async function main(){
  if(!process.env.FIRESTORE_EMULATOR_HOST || process.env.GCLOUD_PROJECT!=="demo-rehberlik")throw new Error("Demo emulator required.");
  initializeApp();const db=getFirestore();
  if(process.argv.includes("--reset")) for(const col of await db.listCollections()) await db.recursiveDelete(col);
  for(const [id,role,phone,name] of [["mother","Anne","+905321234567","Anne"],["elder","Üst Kuşak","+905321234568","Üst Kuşak"],["admin","Admin","+905321234569","Uzman"]]){
    await db.doc(`users/${id}`).set({name:"Test",surname:name,role,phone,disabled:false,sessionVersion:0,createdAt:Timestamp.fromMillis(Date.now()-1209600000)});
    await db.doc(`_credentials/${id}`).set(await D.hashPassword("test-password"));await db.doc(`_phoneLogins/${D.key(phone)}`).set({uid:id});
  }
  for(const col of ["MotherLearnCard","UpperLearnCard"])for(let i=1;i<=4;i++)await db.doc(`${col}/c${i}`).set({bilinen:`Örnek soru ${i}`,gercek:`Cevap ${i}`,isActive:true,startWeek:1,targetGroup:col==="MotherLearnCard"?"mother":"upper"});
  await db.doc("sss/example").set({question:"Destek nasıl alınır?",answer:"Danış ekranından uzman desteği isteyebilirsiniz.",createdAt:Timestamp.now()});
  console.log("Demo emulator fixtures ready.");
}
main().catch(e=>{console.error(e.name);process.exitCode=1});
