// Run from the project root. Default is a read-only audit; --apply performs the
// authenticated account import while preserving Firestore user IDs and passwords.
// Passwords and hashes are never written to disk or logged.
const path = require('node:path');
const crypto = require('node:crypto');
const admin = require('firebase-admin');

async function cliCredential() {
  const base = path.join(process.env.APPDATA, 'npm/node_modules/firebase-tools/lib');
  const {configstore} = require(path.join(base, 'configstore'));
  const auth = require(path.join(base, 'auth'));
  const saved = configstore.get('tokens');
  if (!saved?.refresh_token) throw new Error('Firebase CLI login required.');
  return {getAccessToken: async () => {
    const token = await auth.getAccessToken(saved.refresh_token, saved.scopes || ['https://www.googleapis.com/auth/cloud-platform']);
    return {access_token: token.access_token, expires_in: 3600};
  }};
}

async function main() {
  const credential = await cliCredential();
  admin.initializeApp({projectId: 'tubitak-86d68', credential});
  const {OAuth2Client} = require('google-auth-library');
  const {Firestore} = require('@google-cloud/firestore');
  const token = await credential.getAccessToken();
  const client = new OAuth2Client();
  client.setCredentials({access_token: token.access_token, expiry_date: Date.now() + 3500000});
  const db = new Firestore({projectId: 'tubitak-86d68', authClient: client});
  const {loginEmail} = require('../security');
  const profiles = await db.collection('users').get();
  const phones = new Set();
  const records = [];
  let invalid = 0;
  for (const doc of profiles.docs) {
    const data = doc.data();
    let email;
    try {email = loginEmail(data.phone);} catch (_) {invalid++; continue;}
    if (phones.has(email) || !['Admin', 'Anne', 'Üst Kuşak'].includes(data.role)) {invalid++;continue;}
    phones.add(email);
    if (!data.password) continue;
    const salt = crypto.randomBytes(16);
    records.push({doc, record: {uid: doc.id, email,
      displayName: [data.name, data.surname].filter(Boolean).join(' ').slice(0, 128),
      passwordSalt: salt,
      passwordHash: crypto.pbkdf2Sync(String(data.password), salt, 120000, 32, 'sha256'),
    }});
  }
  console.log(JSON.stringify({profiles: profiles.size, accountsToMigrate: records.length, invalidAccounts: invalid, mode: process.argv.includes('--apply') ? 'apply' : 'audit'}));
  if (invalid) throw new Error('Invalid or duplicate profiles must be resolved before migration.');
  if (!process.argv.includes('--apply')) return;
  // Import does not check UID/email duplication. Never overwrite an existing
  // Firebase Auth account without first verifying that it belongs to this profile.
  for (const {record} of records) {
    try {
      const current = await admin.auth().getUser(record.uid);
      if (current.email !== record.email) throw new Error('Existing Auth UID conflict.');
      record.skip = true;
    } catch (e) {if (e.code !== 'auth/user-not-found') throw e;}
    try {
      const current = await admin.auth().getUserByEmail(record.email);
      if (current.uid !== record.uid) throw new Error('Existing Auth email conflict.');
    } catch (e) {if (e.code !== 'auth/user-not-found') throw e;}
  }
  for (let start = 0; start < records.length; start += 100) {
    const group = records.slice(start, start + 100);
    const pending = group.filter(({record}) => !record.skip).map(({record}) => record);
    if (pending.length) {
      const result = await admin.auth().importUsers(pending, {hash: {algorithm: 'PBKDF2_SHA256', rounds: 120000}});
      if (result.failureCount) throw new Error('Auth import failed; plaintext removal was not performed for this group.');
    }
    const batch = db.batch();
    for (const {doc} of group) batch.update(doc.ref, {password: admin.firestore.FieldValue.delete(), authMigratedAt: admin.firestore.FieldValue.serverTimestamp()});
    await batch.commit();
    console.log('Migrated account count: ' + Math.min(start + 100, records.length));
  }
  console.log('Migration finished. Existing passwords now authenticate through Firebase Auth.');
}

if (require.main === module) main().catch(e => {
  // Firebase errors can contain request details; only emit the error code.
  console.error('Migration stopped: ' + (e.code || e.name)); process.exitCode = 1;
});
module.exports = {cliCredential};
