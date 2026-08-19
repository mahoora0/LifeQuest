$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$cache = Join-Path $root '.cache'
$outDir = Join-Path $root 'demo-output'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$pptPath = Join-Path $outDir 'LifeQuest_통합_시연_영상_소스.pptx'
$videoPath = Join-Path $outDir 'LifeQuest_앱_관리자웹_통합_시연.mp4'

$ppt = New-Object -ComObject PowerPoint.Application
$ppt.Visible = $true
$deck = $ppt.Presentations.Add()
$deck.PageSetup.SlideWidth = 960
$deck.PageSetup.SlideHeight = 540

function Add-BaseSlide([string]$eyebrow, [string]$title, [string]$body, [double]$seconds) {
  $slide = $deck.Slides.Add($deck.Slides.Count + 1, 12)
  $slide.FollowMasterBackground = $false
  $slide.Background.Fill.ForeColor.RGB = 0xF8F5EC
  $bar = $slide.Shapes.AddShape(1, 0, 0, 960, 14)
  $bar.Fill.ForeColor.RGB = 0x405733; $bar.Line.Visible = 0
  $e = $slide.Shapes.AddTextbox(1, 55, 50, 430, 24)
  $e.TextFrame.TextRange.Text = $eyebrow
  $e.TextFrame.TextRange.Font.Name = 'Malgun Gothic'; $e.TextFrame.TextRange.Font.Size = 12
  $e.TextFrame.TextRange.Font.Bold = $true; $e.TextFrame.TextRange.Font.Color.RGB = 0x5B7B45
  $t = $slide.Shapes.AddTextbox(1, 55, 82, 470, 100)
  $t.TextFrame.TextRange.Text = $title
  $t.TextFrame.TextRange.Font.Name = 'Malgun Gothic'; $t.TextFrame.TextRange.Font.Size = 32
  $t.TextFrame.TextRange.Font.Bold = $true; $t.TextFrame.TextRange.Font.Color.RGB = 0x322C23
  $b = $slide.Shapes.AddTextbox(1, 58, 190, 440, 190)
  $b.TextFrame.TextRange.Text = $body
  $b.TextFrame.TextRange.Font.Name = 'Malgun Gothic'; $b.TextFrame.TextRange.Font.Size = 18
  $b.TextFrame.TextRange.Font.Color.RGB = 0x665F55
  $b.TextFrame.TextRange.ParagraphFormat.SpaceAfter = 12
  $slide.SlideShowTransition.AdvanceOnTime = $true
  $slide.SlideShowTransition.AdvanceTime = $seconds
  $slide.SlideShowTransition.EntryEffect = 3849
  return $slide
}

function Add-Portrait([object]$slide, [string]$path) {
  $pic = $slide.Shapes.AddPicture($path, $false, $true, 585, 30, 300, 480)
  $pic.Line.Visible = -1; $pic.Line.ForeColor.RGB = 0x40382D; $pic.Line.Weight = 2
}

function Add-Landscape([object]$slide, [string]$path) {
  $pic = $slide.Shapes.AddPicture($path, $false, $true, 515, 54, 410, 410)
  $pic.LockAspectRatio = -1
  $pic.Width = 410
  $pic.Line.Visible = -1; $pic.Line.ForeColor.RGB = 0x40382D; $pic.Line.Weight = 1.5
}

$s = Add-BaseSlide 'LIFEQUEST · PRODUCT DEMO' '일상을 퀘스트로, 경험을 성장으로' "앱과 관리자 웹이 하나의 성장 경험으로 연결됩니다.`n`nQUEST → GROWTH → REWARD → CUSTOMIZE" 7
$logo = Join-Path $root 'admin-web\public\logo-char.png'
if (Test-Path $logo) { $s.Shapes.AddPicture($logo, $false, $true, 625, 115, 250, 250) | Out-Null }

$s = Add-BaseSlide '01 · HOME' '오늘의 모험을 한눈에' "프로필 · 레벨 · EXP`n오늘의 퀘스트와 진행 상황`n성장한 루키 캐릭터" 8
Add-Portrait $s (Join-Path $cache 'emulator.png')

$s = Add-BaseSlide '02 · NOTIFICATIONS' '친구 활동과 퀘스트 소식을 바로 확인' "친구 신청`n새로운 일간 퀘스트`n완료 보상과 액세서리 획득`n`n알림을 누르면 관련 화면으로 즉시 이동합니다." 10
Add-Portrait $s (Join-Path $cache 'notif4.png')

$s = Add-BaseSlide '03 · QUESTS' '일간 · 주간 · AI 퀘스트' "짧은 일상 행동부터 주간 목표까지.`nAI가 상황에 맞춘 나만의 퀘스트도 추천합니다." 8
Add-Portrait $s (Join-Path $cache 'quests.png')

$s = Add-BaseSlide 'APP FLOW · LIVE' '실제 터치로 이어지는 주요 기능' "알림 → 친구 요청`n일간/주간/AI 퀘스트`n그룹 → 친구 → 랭킹`n`n화면의 터치 표시를 따라 확인하세요." 55
$media = $s.Shapes.AddMediaObject2((Join-Path $cache 'app-tour.mp4'), $false, $true, 585, 30, 300, 480)
$media.AnimationSettings.PlaySettings.PlayOnEntry = $true
$media.AnimationSettings.PlaySettings.HideWhileNotPlaying = $false

$s = Add-BaseSlide '04 · SOCIAL & GROWTH' '함께 성장하고 기록으로 남기기' "친구 목록과 랭킹`n퀘스트 완료 기록 · 누적 EXP`n도감 · 업적 · 칭호" 8
Add-Portrait $s (Join-Path $cache 'my4.png')

$s = Add-BaseSlide '05 · CUSTOMIZE' '루키는 고정, 액세서리만 변경' "퀘스트 수행 → EXP/보상 획득`n액세서리 선택 → 미리보기 → 적용`n마이페이지에서 바뀐 루키 확인" 25
$media = $s.Shapes.AddMediaObject2((Join-Path $cache 'accessory.mp4'), $false, $true, 585, 30, 300, 480)
$media.AnimationSettings.PlaySettings.PlayOnEntry = $true
$media.AnimationSettings.PlaySettings.HideWhileNotPlaying = $false

$s = Add-BaseSlide '06 · ADMIN WEB' '서비스 전체 현황을 운영자가 관리' "사용자 · 퀘스트 · 완료 · EXP 지표`n인기 퀘스트와 최근 활동을 한 화면에서 확인합니다." 10
Add-Landscape $s (Join-Path $cache 'admin-dashboard.png')

$s = Add-BaseSlide '07 · ADMIN QUEST' '새 퀘스트 등록' "새로운 카페 방문하기`n오늘 가보지 않았던 새로운 카페를 방문해보세요.`n일간 · 직접 완료 · 15 EXP" 10
Add-Landscape $s (Join-Path $cache 'admin-quest-form.png')

$s = Add-BaseSlide '08 · SYNC' '등록 즉시 하나의 백엔드로 연동' "관리자 웹에서 저장한 퀘스트가`n사용자 앱의 퀘스트 목록에 반영됩니다.`n`nADMIN WEB → REST API → APP" 10
Add-Landscape $s (Join-Path $cache 'admin-quest-created.png')

$s = Add-BaseSlide 'LIFEQUEST' '퀘스트 → 성장 → 보상 → 꾸미기' "일상의 작은 행동이 EXP와 보상이 되고,`n루키와 함께한 모험의 기록으로 쌓입니다." 9
if (Test-Path $logo) { $s.Shapes.AddPicture($logo, $false, $true, 650, 125, 220, 220) | Out-Null }

$deck.SaveAs($pptPath)
$deck.CreateVideo($videoPath, $true, 5, 1080, 30, 85)
while ($deck.CreateVideoStatus -eq 1) { Start-Sleep -Seconds 5 }
if ($deck.CreateVideoStatus -ne 3) { throw "PowerPoint video export failed: $($deck.CreateVideoStatus)" }
$deck.Close()
$ppt.Quit()
[Runtime.InteropServices.Marshal]::ReleaseComObject($deck) | Out-Null
[Runtime.InteropServices.Marshal]::ReleaseComObject($ppt) | Out-Null
Write-Output $videoPath
