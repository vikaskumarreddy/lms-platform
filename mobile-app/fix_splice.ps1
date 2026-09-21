$ErrorActionPreference = 'Stop'
$path = 'lib\presentation\screens\placement\placement_drive_card.dart'
$orig = [System.IO.File]::ReadLines($path, [System.Text.Encoding]::UTF8)
$fix = [System.IO.File]::ReadLines('fix_tail.txt', [System.Text.Encoding]::UTF8)
# Keep lines 1-469 (0..468), insert replacement for lines 470-534 (indices 469..533),
# then keep lines 535+ (skip first 534).
$head = $orig | Select-Object -First 469
$tail = $orig | Select-Object -Skip 534
$new = $head + @($fix) + $tail
[System.IO.File]::WriteAllLines($path, $new, [System.Text.Encoding]::UTF8)
'head: ' + $head.Count + ' | fix: ' + $fix.Count + ' | tail: ' + $tail.Count + ' | new: ' + $new.Count