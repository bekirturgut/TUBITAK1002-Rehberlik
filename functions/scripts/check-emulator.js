// Exercises the actual callable HTTP protocol and Auth token exchange, not .run().
const assert=require("node:assert/strict");
if(process.env.GCLOUD_PROJECT!=="demo-rehberlik") throw new Error("Demo emulator required.");
async function post(url,body,token) {
  const response=await fetch(url,{method:"POST",headers:{"Content-Type":"application/json",...(token?{Authorization:`Bearer ${token}`}:{})},body:JSON.stringify(body),signal:AbortSignal.timeout(45000)});
  const text=await response.text();let data;try{data=JSON.parse(text)}catch{throw new Error(`Emulator HTTP ${response.status}: non-JSON response`)}
  if(!response.ok || data.error) throw new Error(`Emulator HTTP ${response.status}: ${data.error?.status || "request failed"}`);
  return data;
}
async function call(name,data,token) {return (await post(`http://127.0.0.1:5001/demo-rehberlik/europe-west1/${name}`,{data},token)).result;}
async function login(phone,role) {
  const result=await call("loginWithPhone",{phone,role,password:"test-password"});assert.equal(typeof result.token,"string");
  const auth=await post("http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=fake-api-key",{token:result.token,returnSecureToken:true});
  assert.equal(typeof auth.idToken,"string");return auth.idToken;
}
async function main() {
  let mother;
  for(let attempt=0;attempt<4;attempt++) {
    try {mother=await login("05321234567","Anne");break}
    catch(error) {if(attempt===3)throw error;await new Promise(resolve=>setTimeout(resolve,2000));}
  }
  const result=await call("recordQuizAnswer",{cardId:"c1",answer:"Cevap 1",attemptId:"ci-smoke-attempt"},mother);assert.equal(result.isCorrect,true);
  await call("sendNativeMessage",{messageId:"ci-smoke-message",text:"CI smoke question"},mother);
  await call("askFaqBot",{sourceMessageId:"ci-smoke-message"},mother);
  const admin=await login("05321234569","Admin");
  await call("sendNativeMessage",{userId:"mother",messageId:"ci-smoke-reply",text:"CI smoke answer",replyToMessageId:"ci-smoke-message"},admin);
  await call("updateNativeDevice",{installationId:"ci-smoke-device"},mother);
  console.log("Callable HTTP, Auth exchange, quiz, bot fallback, expert reply and device endpoints passed.");
}
main().catch(error=>{console.error(error.name+": "+error.message);process.exitCode=1});
