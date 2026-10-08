const {test}=require("node:test");
const assert=require("node:assert/strict");
const D=require("../domain");
test("phone normalizes Turkish and international formats",()=>{
  for(const v of ["0532 123 45 67","5321234567","905321234567","+90 (532) 123-45-67","00905321234567"]) assert.equal(D.phone(v),"+905321234567");
  assert.equal(D.phone("+447911123456"),"+447911123456");
});
test("invalid phone, paths, roles and oversize messages fail closed",()=>{
  for(const v of ["","abc","123","+0123456789","+905321234567x"]) assert.throws(()=>D.phone(v));
  for(const v of ["../users","a/b","",null]) assert.throws(()=>D.id(v));
  assert.throws(()=>D.collection("root"));assert.throws(()=>D.text("x".repeat(2001),"Message",2000));
});
test("password hashes use unique salts and exact verification",async()=>{
  const a=await D.hashPassword("test-password"),b=await D.hashPassword("test-password");
  assert.notEqual(a.hash,b.hash);assert.notEqual(a.salt,b.salt);
  assert.equal(await D.verifyPassword("test-password",a),true);
  assert.equal(await D.verifyPassword("test-password ",a),false);
  assert.equal(await D.verifyPassword("wrong",a),false);
  assert.equal(await D.verifyPassword("x",{}),false);
  await assert.rejects(D.hashPassword("short"));
});
test("week boundaries use elapsed days and future dates stay week one",()=>{
  assert.equal(D.week(new Date(0),new Date(604799999)),1);
  assert.equal(D.week(new Date(0),new Date(604800000)),2);
  assert.equal(D.week(new Date(100),new Date(0)),1);
  assert.throws(()=>D.week(undefined));
});
test("eligibility excludes inactive, unreleased, empty records",()=>{
  const base={bilinen:"Q",gercek:"A",startWeek:1};
  assert.deepEqual(D.eligible([{...base,id:"valid"},{...base,id:"future",startWeek:2},{...base,id:"inactive",isActive:false},{...base,id:"empty",gercek:""}],1).map(x=>x.id),["valid"]);
});
test("progress excludes deleted, duplicate, wrong-role cards; exact badge threshold",()=>{
  const cards=Array.from({length:201},(_,i)=>({id:String(i)}));
  const result=D.stats(cards,[...Array.from({length:50},(_,i)=>String(i)),"0","deleted"],["0","50","deleted"]);
  assert.equal(result.percent,24);assert.equal(result.correctCount,50);assert.equal(result.wrongCount,1);assert.deepEqual(result.earnedBadges,[]);
});
test("earned badges persist and empty denominator is safe",()=>{
  assert.deepEqual(D.stats([],[],[],[25,50,999]).earnedBadges,[25,50]);assert.equal(D.stats([],[],[]).percent,0);
  assert.deepEqual(D.stats([{id:"a"}],["a"],[]).earnedBadges,[25,50,75,100]);
});
test("cosine rejects dimensions and zero vectors",()=>{
  assert.equal(D.cosine([1,0],[1,0]),1);assert.equal(D.cosine([1],[1,0]),-1);assert.equal(D.cosine([0],[0]),-1);
});
