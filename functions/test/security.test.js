const {test, before, after} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {initializeTestEnvironment, assertFails, assertSucceeds} = require('../../build/policy-tests/node_modules/@firebase/rules-unit-testing');
const {doc, setDoc, updateDoc, getDoc, getDocs, collection, Timestamp} = require('../../build/policy-tests/node_modules/firebase/firestore');
const admin = require('firebase-admin');
const projectId = 'demo-lactigen-security';
if (process.env.GCLOUD_PROJECT !== projectId || !process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST) throw new Error('Isolated demo emulators required.');
admin.initializeApp({projectId});
const security = require('../security');
let env;
before(async () => {
  env = await initializeTestEnvironment({projectId, firestore: {host: '127.0.0.1', port: 8088, rules: fs.readFileSync(path.resolve('firestore.rules'), 'utf8')}});
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    await setDoc(doc(db, 'users/anne-a'), {role: 'Anne', phone: '+905550000001'});
    await setDoc(doc(db, 'users/anne-b'), {role: 'Anne', phone: '+905550000002'});
    await setDoc(doc(db, 'users/admin'), {role: 'Admin', phone: '+905550000003'});
    await setDoc(doc(db, 'sss/info'), {question: 'Bilgi', answer: 'Eğitim'});
    await setDoc(doc(db, 'chats/anne-a'), {userId: 'anne-a'});
    await setDoc(doc(db, 'chats/anne-a/messages/bot_q'), {text: 'Eğitim yanıtı', senderType: 'bot'});
  });
});
after(async () => {await env?.cleanup(); await admin.app().delete();});
test('Anonymous access cannot read accounts or chats; public FAQ stays available', async () => {
  const db = env.unauthenticatedContext().firestore();
  await assertFails(getDocs(collection(db, 'users')));
  await assertFails(getDoc(doc(db, 'chats/anne-a/messages/bot_q')));
  await assertSucceeds(getDoc(doc(db, 'sss/info')));
});
test('A user reads only their own profile and cannot gain admin privileges', async () => {
  const db = env.authenticatedContext('anne-a').firestore();
  await assertSucceeds(getDoc(doc(db, 'users/anne-a')));
  await assertFails(getDoc(doc(db, 'users/anne-b')));
  await assertFails(updateDoc(doc(db, 'users/anne-a'), {role: 'Admin'}));
  await assertFails(setDoc(doc(db, 'users/evil'), {role: 'Admin'}));
  await assertSucceeds(updateDoc(doc(db, 'users/anne-a'), {fcmToken: 'demo-device'}));
});
test('User chat flow works but bot impersonation and other users chat writes fail', async () => {
  const db = env.authenticatedContext('anne-a').firestore();
  await assertSucceeds(setDoc(doc(db, 'chats/anne-a'), {userId: 'anne-a', createdAt: Timestamp.now(), updatedAt: Timestamp.now()}, {merge: true}));
  await assertSucceeds(setDoc(doc(db, 'chats/anne-a/messages/q'), {text: 'Eğitim sorusu', senderType: 'user', senderId: 'anne-a', senderRole: 'Anne', createdAt: Timestamp.now(), needsAdminReply: false, isAnswered: false}));
  await assertFails(setDoc(doc(db, 'chats/anne-a/messages/forged'), {text: 'Sahte yanıt', senderType: 'bot', senderId: 'chatbot'}));
  await assertFails(setDoc(doc(db, 'chats/anne-b'), {userId: 'anne-b'}));
  await assertSucceeds(updateDoc(doc(db, 'chats/anne-a/messages/bot_q'), {feedbackGiven: true, isSufficient: false, showFeedbackButtons: false, feedbackAt: Timestamp.now()}));
  await assertFails(updateDoc(doc(db, 'chats/anne-a/messages/bot_q'), {text: 'Değiştirilmiş içerik'}));
});
test('Reporting and deletion requests are scoped to the account', async () => {
  const db = env.authenticatedContext('anne-a').firestore();
  await assertSucceeds(getDoc(doc(db, 'content_reports/anne-a_bot_q')));
  await assertSucceeds(setDoc(doc(db, 'content_reports/anne-a_bot_q'), {userId: 'anne-a', messageId: 'bot_q', reason: 'Uygunsuz içerik', status: 'pending', createdAt: Timestamp.now()}));
  await assertFails(setDoc(doc(db, 'content_reports/other'), {userId: 'anne-b', messageId: 'bot_q', reason: 'Uygunsuz içerik', status: 'pending'}));
  await assertSucceeds(setDoc(doc(db, 'deletion_requests/anne-a'), {userId: 'anne-a', status: 'pending', createdAt: Timestamp.now()}));
  await assertFails(getDocs(collection(db, 'content_reports')));
  await assertSucceeds(getDocs(collection(env.authenticatedContext('admin').firestore(), 'content_reports')));
});
test('Server account creation is restricted to actual administrators and stores no password in profile', async () => {
  const data = {name: 'Emulator', surname: 'Test', phone: '05550000004', role: 'Anne', password: 'emulator-only-pass'};
  await assert.rejects(security.saveManagedUser.run({data}), /Giriş yapmanız/);
  await assert.rejects(security.saveManagedUser.run({auth: {uid: 'anne-a'}, data}), /Yönetici yetkisi/);
  const result = await security.saveManagedUser.run({auth: {uid: 'admin'}, data});
  const profile = await admin.firestore().doc('users/' + result.userId).get();
  assert.equal(profile.data().password, undefined);
  assert.equal((await admin.auth().getUser(result.userId)).email, security.loginEmail(data.phone));
  await assert.rejects(security.saveManagedUser.run({auth: {uid: 'admin'}, data}), /kullanılıyor/);
});
test('Server deletion removes nested progress, chats, queues, reports and Auth account', async () => {
  const db = admin.firestore();
  const created = await security.saveManagedUser.run({auth: {uid: 'admin'}, data: {name: 'Delete', phone: '05550000005', role: 'Anne', password: 'emulator-only-pass'}});
  const uid = created.userId;
  await db.doc(`users/${uid}/correctCards/a`).set({question: 'Test'});
  await db.doc(`users/${uid}/wrongCards/b`).set({question: 'Test'});
  await db.doc(`chats/${uid}/messages/bot_a`).set({text: 'Test'});
  await db.doc('sendQueue/test').set({uid});
  await db.doc('admin_alerts/test').set({userId: uid});
  await db.doc('content_reports/test').set({userId: uid});
  await db.doc('deletion_requests/' + uid).set({userId: uid});
  await assert.rejects(security.deleteManagedUser.run({auth: {uid: 'anne-a'}, data: {userId: uid}}), /Yönetici yetkisi/);
  await security.deleteManagedUser.run({auth: {uid: 'admin'}, data: {userId: uid}});
  for (const location of [`users/${uid}`, `users/${uid}/correctCards/a`, `users/${uid}/wrongCards/b`, `chats/${uid}/messages/bot_a`, 'sendQueue/test', 'admin_alerts/test', 'content_reports/test', 'deletion_requests/' + uid]) assert.equal((await db.doc(location).get()).exists, false);
  await assert.rejects(admin.auth().getUser(uid), error => error.code === 'auth/user-not-found');
});
