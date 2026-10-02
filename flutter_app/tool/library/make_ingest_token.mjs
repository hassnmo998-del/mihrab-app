#!/usr/bin/env node
/**
 * ينشئ رمز استيراد الكتب ويحفظه في tool/library/.ingest-token (خارج git).
 *
 *   node tool/library/make_ingest_token.mjs            ينشئه إن لم يوجد، ويطبع بصمته
 *   node tool/library/make_ingest_token.mjs --rotate   يستبدله برمز جديد
 *
 * قاعدة البيانات تحفظ البصمة (sha256) فقط. سجّلها مرة واحدة من SQL Editor:
 *   insert into private.library_ingest_tokens (token_sha256, label) values ('<البصمة>', 'جهازي');
 * ولإبطال رمز قديم احذف صفّه من الجدول نفسه.
 */
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

const file = path.join(path.dirname(fileURLToPath(import.meta.url)), '.ingest-token');
const rotate = process.argv.includes('--rotate');

if (rotate || !fs.existsSync(file)) {
  fs.writeFileSync(file, crypto.randomBytes(32).toString('base64url'), { mode: 0o600 });
  console.log(`أُنشئ رمز جديد في ${file}`);
} else {
  console.log(`الرمز موجود في ${file}`);
}

const token = fs.readFileSync(file, 'utf8').trim();
console.log(`sha256: ${crypto.createHash('sha256').update(token).digest('hex')}`);
