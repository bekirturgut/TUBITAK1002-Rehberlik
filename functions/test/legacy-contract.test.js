const {test}=require("node:test"),assert=require("node:assert/strict"),fs=require("node:fs"),cp=require("node:child_process"),path=require("node:path");
const root=path.resolve(__dirname,"../..");
for(const file of ["functions/package.json","functions/package-lock.json","firebase.json"])
 test(`Original file preserved: ${file}`,()=>assert.deepEqual(fs.readFileSync(path.join(root,file)),cp.execFileSync("git",["show",`e445e39:${file}`],{cwd:root,maxBuffer:5e6})));

test("Native client has no migration/Auth endpoint dependencies",()=>{
 for(const file of fs.readdirSync(path.join(root,"native-ios/App")).filter(x=>x.endsWith(".swift"))){
  const text=fs.readFileSync(path.join(root,"native-ios/App",file),"utf8");
  assert.doesNotMatch(text,/FirebaseAuth|loginWithPhone|saveNativeUser|deleteNativeUser|sendNativeMessage|updateNativeDevice|rateNativeAnswer|withCustomToken|_credentials|_phoneLogins/);
 }
});
test("Production deployment does not replace existing Firestore rules",()=>assert.equal(JSON.parse(fs.readFileSync(path.join(root,"firebase.json"))).firestore,undefined));

test("Existing backend exports remain available after chat fixes",()=>{
 const current=fs.readFileSync(path.join(root,"functions/index.js"),"utf8");
 const original=cp.execFileSync("git",["show","e445e39:functions/index.js"],{cwd:root,encoding:"utf8"});
 for(const match of original.matchAll(/exports\.(\w+)\s*=/g))
  assert.match(current,new RegExp(`exports\\.${match[1]}\\s*=`));
});
