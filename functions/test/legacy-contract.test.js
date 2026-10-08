const {test}=require("node:test"),assert=require("node:assert/strict"),fs=require("node:fs"),cp=require("node:child_process"),path=require("node:path");
const root=path.resolve(__dirname,"../..");
for(const file of ["functions/package.json","functions/package-lock.json","firebase.json"])
 test(`Original file preserved: ${file}`,()=>assert.deepEqual(fs.readFileSync(path.join(root,file)),cp.execFileSync("git",["show",`e445e39:${file}`],{cwd:root,maxBuffer:5e6})));
test("Original Flutter source is unchanged",()=>assert.equal(cp.execFileSync("git",["diff","e445e39","--","lib"],{cwd:root,encoding:"utf8"}),""));
test("Native client has no migration/Auth endpoint dependencies",()=>{
 for(const file of fs.readdirSync(path.join(root,"native-ios/App")).filter(x=>x.endsWith(".swift"))){
  const text=fs.readFileSync(path.join(root,"native-ios/App",file),"utf8");
  assert.doesNotMatch(text,/FirebaseAuth|loginWithPhone|saveNativeUser|deleteNativeUser|sendNativeMessage|updateNativeDevice|rateNativeAnswer|withCustomToken|_credentials|_phoneLogins/);
 }
});
test("Production deployment does not replace existing Firestore rules",()=>assert.equal(JSON.parse(fs.readFileSync(path.join(root,"firebase.json"))).firestore,undefined));

test("Backend flow is original apart from Firestore SDK import compatibility",()=>{
 const current=fs.readFileSync(path.join(root,"functions/index.js"),"utf8").replace(/\r\n/g,"\n");
 const original=cp.execFileSync("git",["show","e445e39:functions/index.js"],{cwd:root,encoding:"utf8"});
 const expected=original.replace('const admin = require("firebase-admin");','const admin = require("firebase-admin");\nconst { FieldValue, Timestamp } = require("firebase-admin/firestore");').replaceAll("admin.firestore.FieldValue","FieldValue").replaceAll("admin.firestore.Timestamp","Timestamp");
 assert.equal(current,expected);
});
