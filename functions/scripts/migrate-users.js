// Run with Application Default Credentials. Dry run is the default.
// Never prints passwords, hashes, phone numbers or names.
const admin=require("firebase-admin");const D=require("../domain");
async function main() {
  admin.initializeApp();const db=admin.firestore();
  const apply=process.argv.includes("--apply");
  const users=await db.collection("users").get();
  const seen=new Set(),plans=[];
  for(const doc of users.docs) {
    const data=doc.data();const phone=D.phone(data.phone);
    if(!D.ROLES.includes(data.role) || !data.createdAt?.toDate) throw new Error(`Invalid role/date on user ${doc.id}; no writes applied.`);
    if(seen.has(phone)) throw new Error("Duplicate normalized phone; resolve before migration. No writes applied.");
    seen.add(phone);
    const existing=await db.doc(`_credentials/${doc.id}`).get();
    if(!existing.exists && (typeof data.password!=="string" || !data.password.length || data.password.length>128)) throw new Error(`Password migration requires reset for ${doc.id}; no writes applied.`);
    // Legacy short passwords may be imported; all newly set passwords require 8+ chars.
    const credential=existing.exists ? null : await D.hashPassword(data.password.padEnd(8,"\u0000"));
    if(credential && data.password.length<8) {
      const {promisify}=require("node:util"),crypto=require("node:crypto");
      credential.hash=(await promisify(crypto.scrypt)(data.password,credential.salt,64)).toString("hex");
    }
    plans.push({ref:doc.ref,phone,credential});
  }
  console.log(`${plans.length} users validated. Mode: ${apply ? "APPLY":"DRY RUN"}.`);
  if(!apply) return;
  for(const p of plans) {
    await db.runTransaction(async tx=>{
      const [latest,mapping]=await Promise.all([tx.get(p.ref),tx.get(db.doc(`_phoneLogins/${D.key(p.phone)}`))]);
      if(!latest.exists) throw new Error("User disappeared; rerun migration.");
      if(mapping.exists && mapping.data().uid!==p.ref.id) throw new Error("Phone index conflict; stopped.");
      if(D.phone(latest.data().phone)!==p.phone) throw new Error("Profile changed; stopped.");
      tx.set(db.doc(`_phoneLogins/${D.key(p.phone)}`),{uid:p.ref.id});
      if(p.credential) tx.set(db.doc(`_credentials/${p.ref.id}`),p.credential);
      tx.update(p.ref,{phone:p.phone,password:admin.firestore.FieldValue.delete()});
    });
  }
  console.log("Migration complete; IDs and subcollections preserved.");
}
main().catch(e=>{console.error(e.message);process.exitCode=1});
