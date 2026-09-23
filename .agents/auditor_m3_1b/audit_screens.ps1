$files = Get-ChildItem -Path "c:\Users\moham\Desktop\masjed app\flutter_app\lib\screens" -Recurse -Filter *.dart

Write-Host "=== MULTIPLE SEMICOLONS PER LINE (OUTSIDE FOR LOOPS) ==="
$multiSemiFound = 0
foreach ($f in $files) {
    $lines = Get-Content $f.FullName
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $semiCount = ($line -split ';').Count - 1
        if ($semiCount -gt 1) {
            if ($line -notmatch 'for\s*\(') {
                Write-Host "$($f.Name):$($i+1): $line"
                $multiSemiFound++
            }
        }
    }
}
Write-Host "Total non-loop multi-semicolon lines: $multiSemiFound"

Write-Host "`n=== CHECKING TOP 10 LARGEST FILES AVERAGE LINE LENGTH ==="
$top10 = $files | Sort-Object { (Get-Content $_.FullName).Count } -Descending | Select-Object -First 10
foreach ($f in $top10) {
    $lines = Get-Content $f.FullName
    $totalChars = ($lines | Measure-Object -Property Length -Sum).Sum
    $avgChars = [math]::Round($totalChars / $lines.Count, 1)
    $maxChars = ($lines | Measure-Object -Property Length -Maximum).Maximum
    Write-Host "$($f.Name): Lines=$($lines.Count), AvgLen=$avgChars, MaxLen=$maxChars"
}
