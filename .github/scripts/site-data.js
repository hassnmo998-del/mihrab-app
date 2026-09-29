// site-data.json للموقع: رقم آخر إصدار رسمي، ومجموع تحميلات ملفات التثبيت (apk/exe).
// usage: node site-data.js <releases.json من GitHub API>
const releases = JSON.parse(require('fs').readFileSync(process.argv[2], 'utf8'));

const parts = tag => String(tag).replace(/^v/i, '').split(/[+-]/)[0].split('.').map(n => parseInt(n, 10) || 0);
const newer = (a, b) => {
  const [x, y] = [parts(a), parts(b)];
  for (let i = 0; i < Math.max(x.length, y.length); i++) {
    if ((x[i] || 0) !== (y[i] || 0)) return (x[i] || 0) > (y[i] || 0);
  }
  return false;
};

let version = null;
let downloads = 0;
for (const r of releases) {
  if (!r.draft && !r.prerelease && (!version || newer(r.tag_name, version))) version = r.tag_name;
  for (const a of r.assets || []) {
    if (/\.(apk|exe)$/i.test(a.name)) downloads += a.download_count || 0;
  }
}

process.stdout.write(JSON.stringify({ version, downloads }) + '\n');
