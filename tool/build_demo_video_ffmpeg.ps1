$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$cache = Join-Path $root '.cache'
$out = Join-Path $root 'demo-output'
$frames = Join-Path $out 'frames'
$parts = Join-Path $out 'parts'
New-Item -ItemType Directory -Force -Path $parts | Out-Null

& 'C:\Users\it\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' (Join-Path $PSScriptRoot 'render_demo_frames.py')

$ffmpeg = (Get-Command ffmpeg.exe -ErrorAction SilentlyContinue).Source
if (-not $ffmpeg) {
  $ffmpeg = (Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter ffmpeg.exe -Recurse | Select-Object -First 1).FullName
}
if (-not $ffmpeg) { throw 'ffmpeg.exe not found' }

function Still([string]$name, [int]$seconds, [int]$index) {
  & $ffmpeg -y -loop 1 -i (Join-Path $frames $name) -t $seconds -r 30 -vf 'format=yuv420p' -c:v libx264 -preset medium -crf 20 (Join-Path $parts ("{0:d2}.mp4" -f $index)) | Out-Null
}
function Live([string]$bg, [string]$clip, [int]$index) {
  & $ffmpeg -y -loop 1 -i (Join-Path $frames $bg) -i (Join-Path $cache $clip) -filter_complex '[1:v]scale=-2:990[phone];[0:v][phone]overlay=1225:45:shortest=1,format=yuv420p' -r 30 -c:v libx264 -preset medium -crf 20 -shortest (Join-Path $parts ("{0:d2}.mp4" -f $index)) | Out-Null
}

Still '01-title.png' 7 1
Still '02-home.png' 8 2
Still '03-notifications.png' 10 3
Still '04-quests.png' 8 4
Live '05-live-bg.png' 'app-tour.mp4' 5
Still '06-growth.png' 8 6
Live '07-custom-bg.png' 'accessory.mp4' 7
Still '08-admin.png' 10 8
Still '09-admin-form.png' 10 9
Still '10-sync.png' 10 10
Still '11-outro.png' 9 11

$list = Join-Path $out 'concat.txt'
$lines = 1..11 | ForEach-Object { "file 'parts/{0:d2}.mp4'" -f $_ }
[IO.File]::WriteAllLines($list, $lines, [Text.UTF8Encoding]::new($false))
$final = Join-Path $out 'LifeQuest-integrated-demo.mp4'
& $ffmpeg -y -f concat -safe 0 -i $list -c copy -movflags +faststart $final | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Final concat failed: $LASTEXITCODE" }
Write-Output $final
