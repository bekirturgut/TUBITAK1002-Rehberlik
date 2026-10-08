"use strict";
const crypto = require("node:crypto");
const { promisify } = require("node:util");
const scrypt = promisify(crypto.scrypt);
const ROLES = ["Anne", "Üst Kuşak", "Admin"];
function phone(input) {
  let value = String(input || "").replace(/[\s()\-]/g, "");
  if (value.startsWith("00")) value = "+" + value.slice(2);
  if (/^0\d{10}$/.test(value)) value = "+90" + value.slice(1);
  if (/^5\d{9}$/.test(value)) value = "+90" + value;
  if (/^90\d{10}$/.test(value)) value = "+" + value;
  if (!/^\+[1-9]\d{7,14}$/.test(value)) throw new Error("Geçerli bir telefon numarası giriniz.");
  return value;
}
function key(value) { return crypto.createHash("sha256").update(value).digest("hex"); }
function text(value, name, max = 4000) {
  if (typeof value !== "string" || !value.trim() || value.trim().length > max) throw new Error(`${name} geçersiz (1–${max} karakter).`);
  return value.trim();
}
function id(value) {
  if (typeof value !== "string" || !/^[A-Za-z0-9_-]{1,128}$/.test(value)) throw new Error("Geçersiz kayıt kimliği.");
  return value;
}
function collection(role) {
  if (role === "Anne") return "MotherLearnCard";
  if (role === "Üst Kuşak") return "UpperLearnCard";
  throw new Error("Bu rol öğrenme kartı çözemez.");
}
function week(createdAt, now = new Date()) {
  const date = createdAt?.toDate ? createdAt.toDate() : new Date(createdAt);
  if (!Number.isFinite(date.getTime())) throw new Error("Kullanıcı kayıt tarihi eksik.");
  return Math.max(1, Math.floor((now - date) / 604800000) + 1);
}
function eligible(cards, currentWeek) {
  return cards.filter(c => c.isActive !== false && Number(c.startWeek ?? 1) <= currentWeek && String(c.bilinen || "").trim() && String(c.gercek || "").trim());
}
function stats(cards, correctIDs, wrongIDs, previous = []) {
  const valid = new Set(cards.map(c => c.id));
  const correctCount = [...new Set(correctIDs)].filter(x => valid.has(x)).length;
  const wrongCount = [...new Set(wrongIDs)].filter(x => valid.has(x) && !correctIDs.includes(x)).length;
  const percent = valid.size ? Math.floor(correctCount * 100 / valid.size) : 0;
  const earnedBadges = [...new Set([...previous.filter(x => [25,50,75,100].includes(x)), ...[25,50,75,100].filter(x => percent >= x)])].sort((a,b) => a-b);
  return { assignedCount: valid.size, correctCount, wrongCount, percent, earnedBadges, latestBadge: earnedBadges.at(-1) ?? null };
}
async function hashPassword(password) {
  if (typeof password !== "string" || password.length < 8 || password.length > 128) throw new Error("Şifre 8–128 karakter olmalıdır.");
  const salt = crypto.randomBytes(16).toString("hex");
  const hash = await scrypt(password, salt, 64);
  return { salt, hash: hash.toString("hex") };
}
async function verifyPassword(password, credential) {
  if (typeof password !== "string" || password.length > 128 || !credential?.salt || !/^[a-f0-9]{128}$/.test(credential.hash || "")) return false;
  const hash = await scrypt(password, credential.salt, 64);
  return crypto.timingSafeEqual(hash, Buffer.from(credential.hash, "hex"));
}
function cosine(a, b) {
  if (!Array.isArray(a) || !Array.isArray(b) || a.length !== b.length || !a.length) return -1;
  let dot=0, aa=0, bb=0;
  for (let i=0;i<a.length;i++) { dot+=a[i]*b[i]; aa+=a[i]**2; bb+=b[i]**2; }
  return aa && bb ? dot/Math.sqrt(aa*bb) : -1;
}
module.exports = { phone, key, text, id, collection, week, eligible, stats, hashPassword, verifyPassword, cosine, ROLES };
