$ErrorActionPreference = 'Stop'
$path = 'lib\presentation\screens\main_shell_screen.dart'
$lines = [System.IO.File]::ReadAllLines($path, [System.Text.Encoding]::UTF8)
$out = @()
for ($i = 95; $i -le 200; $i++) { $out += "$i`t| $($lines[$i-1])" }
[System.IO.File]::WriteAllLines('show_region.txt', $out, [System.Text.Encoding]::UTF8)
'wrote ' + $lines.Length + ' lines total'