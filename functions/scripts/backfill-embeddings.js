const {initializeApp}=require("firebase-admin/app");const {getFirestore,FieldValue}=require("firebase-admin/firestore");const {GoogleGenAI}=require("@google/genai");
async function main() {
  initializeApp();const db=getFirestore();const rows=await db.collection("faq_items").get();
  const apply=process.argv.includes("--apply");console.log(`${rows.size} FAQ records. ${apply?"APPLY":"DRY RUN"}`);
  if(!apply)return;
  if(!process.env.GEMINI_API_KEY)throw new Error("Provide the rotated key through the operator environment.");
  const ai=new GoogleGenAI({apiKey:process.env.GEMINI_API_KEY});
  for(const row of rows.docs) {
    const question=String(row.data().question || "").trim();if(!question)continue;
    const result=await ai.models.embedContent({model:"gemini-embedding-001",contents:question,config:{outputDimensionality:768}});
    await db.runTransaction(async tx=>{const fresh=await tx.get(row.ref);if(fresh.data()?.question!==question)return;
      tx.update(row.ref,{embedding:result.embeddings[0].values,embeddingQuestion:question,embeddingDim:result.embeddings[0].values.length,embeddingModel:"gemini-embedding-001",embeddingError:FieldValue.delete()});});
  }
  console.log("Backfill complete.");
}
main().catch(e=>{console.error(e.name);process.exitCode=1});
