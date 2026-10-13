const {test, before, after} = require('node:test');
const assert = require('node:assert/strict');
const Module = require('node:module');
const projectId = 'demo-lactigen-security';
if (process.env.GCLOUD_PROJECT !== projectId || !process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST) throw new Error('Isolated demo emulators required.');
// Test the real callable and persistence without sending data to an AI provider.
const originalLoad = Module._load;
let generated = 0;
Module._load = function(name, ...args) {
  if (name === 'dotenv') return {config() {}};
  if (name === '@google/genai') return {GoogleGenAI: class {
    constructor() { this.models = {
      embedContent: async () => ({embeddings: [{values: [1, 0]}]}),
      generateContent: async () => { generated++; return {text: 'Emulator eğitim yanıtı.'}; },
    }; }
  }};
  return originalLoad.call(this, name, ...args);
};
const backend = require('../index');
Module._load = originalLoad;
const admin = require('firebase-admin');
const db = admin.firestore();
const data = {question: 'Emulator eğitim sorusu?', userId: 'chat-test', sourceMessageId: 'source', aiConsent: true, privacyVersion: '2026-10-13-v2'};
before(async () => {
  await db.doc('users/chat-test').set({role: 'Anne'});
  await db.doc('chats/chat-test/messages/source').set({text: data.question, senderType: 'user'});
  await db.doc('faq_items/chat-test').set({question: data.question, answer: 'Eğitim içeriği.', isActive: true, embedding: [1, 0]});
});
after(async () => { await admin.app().delete(); });
test('AI callable rejects missing authentication, wrong owner and missing consent', async () => {
  await assert.rejects(backend.askFaqBot.run({data}), /Giriş yapmanız/);
  await assert.rejects(backend.askFaqBot.run({auth: {uid: 'chat-test'}, data: {...data, userId: 'other'}}), /erişim yok/);
  await assert.rejects(backend.askFaqBot.run({auth: {uid: 'chat-test'}, data: {...data, aiConsent: false}}), /izin gerekiyor/);
  await assert.rejects(backend.askFaqBot.run({auth: {uid: 'chat-test'}, data: {...data, question: 'Değiştirilmiş soru'}}), /doğrulanamadı/);
  assert.equal(generated, 0);
});
test('Authenticated answer is persisted by the server and retried without duplicate messages', async () => {
  const result = await backend.askFaqBot.run({auth: {uid: 'chat-test'}, data});
  assert.equal(result.answer, 'Emulator eğitim yanıtı.');
  const bot = (await db.doc('chats/chat-test/messages/bot_source').get()).data();
  assert.equal(bot.text, result.answer);
  assert.equal(bot.senderType, 'bot');
  assert.equal(bot.sourceMessageId, 'source');
  assert.equal((await db.doc('chats/chat-test/messages/source').get()).data().botRequestStatus, 'answered');
  await backend.askFaqBot.run({auth: {uid: 'chat-test'}, data});
  assert.equal((await db.collection('chats/chat-test/messages').get()).size, 2);
});
