import subprocess
import os

screen_dir = r'lib/screens'
results = []
for root, dirs, files in os.walk(screen_dir):
    for f in files:
        if f.endswith('.dart'):
            p = os.path.join(root, f)
            res = subprocess.run(f'dart format --output=show "{p}"', shell=True, capture_output=True, text=True, encoding='utf-8')
            formatted_lines = len(res.stdout.splitlines())
            with open(p, 'r', encoding='utf-8') as orig:
                orig_lines = len(orig.readlines())
            results.append((p, orig_lines, formatted_lines))

results.sort(key=lambda x: x[2], reverse=True)
print("Top 15 files by formatted line count:")
for p, orig, fmt in results[:15]:
    status = "OVER 500!" if fmt >= 500 else "OK"
    print(f"{fmt:4d} fmt (orig {orig:4d}) [{status}] : {p}")

over_500 = [r for r in results if r[2] >= 500]
print(f"\nTotal screen files: {len(results)}")
print(f"Files >= 500 when formatted: {len(over_500)}")
