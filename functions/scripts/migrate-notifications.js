// Preserve old queue sent-state, remove old token snapshots, prevent double scheduling.
const {initializeApp}=require("firebase-admin/app");const {getFirestore,FieldValue}=require("firebase-admin/firestore");
async function main() {
  initializeApp();const db=getFirestore();const apply=process.argv.includes("--apply");
  const rows=await db.collection("sendQueue").get();
  const legacy=rows.docs.filter(d=>d.data().uid && d.data().templateId && !d.id.startsWith("template_"));
  console.log(`${legacy.length} legacy template deliveries. ${apply ? "APPLY":"DRY RUN"}`);
  if(!apply)return;
  for(const old of legacy) {
    const q=old.data();const next=db.doc(`sendQueue/template_${q.uid}_${q.templateId}`);
    await db.runTransaction(async tx=>{
      const [fresh,current]=await Promise.all([tx.get(old.ref),tx.get(next)]);if(!fresh.exists)return;
      const data=fresh.data();const copy={...data,token:FieldValue.delete(),leaseUntil:0};
      if(current.data()?.sent===true) copy.sent=true;
      tx.set(next,copy,{merge:true});tx.delete(old.ref);
    });
  }
  console.log("Legacy queue migration complete.");
}
main().catch(e=>{console.error(e.name);process.exitCode=1});
