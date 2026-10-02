// update.json للموقع: وصف آخر إصدار كما يقرؤه التحديث داخل التطبيق.
// usage: node update-manifest.js <release.json من GitHub API> <مجلد downloads المنشور>
//
// الحجم والبصمة يُحسبان من الملفين اللذين سيُنشران فعلاً، لا من بيانات الإصدار:
// التطبيق يرفض أي ملف لا يطابق هذا الوصف، فالوصف يجب أن يصف ما على الموقع.
// وإن لم يكن ما على الموقع هو ملف الإصدار الأخير بعينه فلا يُكتب شيء (خروج 2)،
// والتطبيق يرجع إلى GitHub API.
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const release = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const dir = process.argv[3];

function entry(localName, pattern) {
  const file = path.join(dir, localName);
  const asset = (release.assets || []).find((a) => pattern.test(a.name));
  if (!asset || !fs.existsSync(file)) return null;

  const size = fs.statSync(file).size;
  const sha256 = crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
  const digest = String(asset.digest || '').replace(/^sha256:/, '').toLowerCase();
  if (size !== asset.size || (digest && digest !== sha256)) return null;

  return { path: `downloads/${localName}`, size, sha256, mirror: asset.browser_download_url };
}

const android = entry('mihrab-android.apk', /\.apk$/i);
const windows = entry('mihrab-windows.exe', /\.exe$/i);
if (!android && !windows) {
  console.error('downloads/ does not hold the latest release binaries; update.json not written');
  process.exit(2);
}

process.stdout.write(
  JSON.stringify({
    version: String(release.tag_name).replace(/^v/i, ''),
    publishedAt: release.published_at,
    notes: release.body || '',
    ...(android ? { android } : {}),
    ...(windows ? { windows } : {}),
  }) + '\n',
);
