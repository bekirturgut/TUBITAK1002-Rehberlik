// Creates an isolated copy of the original backend; never reads/copies local credentials.
const fs=require("node:fs"),path=require("node:path");
const root=path.resolve(__dirname,"../.."),out=path.join(root,".legacy-emulator");
fs.mkdirSync(out,{recursive:true});
const source=fs.readFileSync(path.join(root,"functions/index.js"),"utf8");
fs.writeFileSync(path.join(out,"index.js"),source.replace('require("@google/genai")','require("./fake-genai")').replaceAll('admin.messaging()', '({send:async()=>"demo-push",sendEachForMulticast:async()=>({successCount:1,failureCount:0,responses:[{success:true}]})})'));
fs.writeFileSync(path.join(out,"package.json"),fs.readFileSync(path.join(root,"functions/package.json")));
fs.writeFileSync(path.join(out,".env"),"GEMINI_API_KEY=emulator-only\n");
fs.writeFileSync(path.join(out,"fake-genai.js"),`exports.GoogleGenAI=class{constructor(){this.models={embedContent:async()=>({embeddings:[{values:[1,0,0]}]}),generateContent:async()=>({text:"Test bilgi tabanı yanıtı"})}}};`);
if(!fs.existsSync(path.join(out,"node_modules")))fs.symlinkSync(path.join(root,"functions/node_modules"),path.join(out,"node_modules"),process.platform==="win32"?"junction":"dir");
console.log("Isolated legacy backend prepared with fake Gemini; production source unchanged.");
