$files = Get-ChildItem -Path "c:\Users\moham\Desktop\masjed app\flutter_app\lib\screens" -Recurse -Filter *.dart

Write-Host "=== 1. SEARCH FOR MOCK / FAKE / STUB / DUMMY IN lib/screens ==="
$mockHits = 0
foreach ($f in $files) {
    $matches = Select-String -Path $f.FullName -Pattern 'Mock|Fake|Stub|dummy|testDouble' -CaseSensitive:$false
    foreach ($m in $matches) {
        Write-Host "$($f.Name):$($m.LineNumber): $($m.Line.Trim())"
        $mockHits++
    }
}
Write-Host "Total Mock/Fake hits: $mockHits"

Write-Host "`n=== 2. SEARCH FOR UnimplementedError IN lib/screens ==="
$unimplHits = 0
foreach ($f in $files) {
    $matches = Select-String -Path $f.FullName -Pattern 'UnimplementedError'
    foreach ($m in $matches) {
        Write-Host "$($f.Name):$($m.LineNumber): $($m.Line.Trim())"
        $unimplHits++
    }
}
Write-Host "Total UnimplementedError hits: $unimplHits"

Write-Host "`n=== 3. SEARCH FOR EMPTY HANDLERS () {} IN lib/screens ==="
$emptyHits = 0
foreach ($f in $files) {
    $matches = Select-String -Path $f.FullName -Pattern 'onPressed:\s*\(\)\s*\{\s*\}|onTap:\s*\(\)\s*\{\s*\}|onChanged:\s*\([^)]*\)\s*\{\s*\}'
    foreach ($m in $matches) {
        Write-Host "$($f.Name):$($m.LineNumber): $($m.Line.Trim())"
        $emptyHits++
    }
}
Write-Host "Total empty handler hits: $emptyHits"
