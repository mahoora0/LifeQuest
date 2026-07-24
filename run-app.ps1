param(
    [ValidateSet('emulator', 'usb', 'lan')]
    [string]$Target = 'emulator',

    [string]$ApiBaseUrl,

    [string]$DeviceId,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$FlutterArgs
)

$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$envPath = Join-Path $repositoryRoot '.env'
$appPath = Join-Path $repositoryRoot 'app'

if (-not (Test-Path -LiteralPath $envPath)) {
    throw "루트 .env 파일이 없습니다. '.env.example'을 '.env'로 복사한 뒤 값을 입력하세요."
}

$envValues = @{}
foreach ($rawLine in Get-Content -LiteralPath $envPath) {
    $line = $rawLine.Trim()
    if (-not $line -or $line.StartsWith('#')) {
        continue
    }

    $separator = $line.IndexOf('=')
    if ($separator -le 0) {
        continue
    }

    $key = $line.Substring(0, $separator).Trim()
    $value = $line.Substring($separator + 1).Trim()
    if ($value.Length -ge 2) {
        $hasDoubleQuotes = $value.StartsWith('"') -and $value.EndsWith('"')
        $hasSingleQuotes = $value.StartsWith("'") -and $value.EndsWith("'")
        if ($hasDoubleQuotes -or $hasSingleQuotes) {
            $value = $value.Substring(1, $value.Length - 2)
        }
    }
    $envValues[$key] = $value
}

$googleClientId = $envValues['GOOGLE_CLIENT_ID']
if ([string]::IsNullOrWhiteSpace($googleClientId)) {
    throw '.env의 GOOGLE_CLIENT_ID에 Google 웹 OAuth 클라이언트 ID를 입력하세요.'
}

if ([string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
    if ($Target -eq 'lan') {
        $ApiBaseUrl = $envValues['FLUTTER_API_BASE_URL']
        if ([string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
            throw "LAN 실행에는 .env의 FLUTTER_API_BASE_URL 또는 '-ApiBaseUrl http://PC_IP:8080/api'가 필요합니다."
        }
    }
    elseif ($Target -eq 'usb') {
        $ApiBaseUrl = 'http://127.0.0.1:8080/api'
    }
    else {
        $ApiBaseUrl = 'http://10.0.2.2:8080/api'
    }
}

if ($Target -eq 'usb') {
    $adbCommand = Get-Command adb -ErrorAction SilentlyContinue
    $adbPath = if ($null -ne $adbCommand) { $adbCommand.Source } else { $null }

    if ([string]::IsNullOrWhiteSpace($adbPath)) {
        $sdkRoots = @(
            $env:ANDROID_HOME,
            $env:ANDROID_SDK_ROOT,
            (Join-Path $env:LOCALAPPDATA 'Android\Sdk'),
            'C:\workspace\utils\Android'
        ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

        foreach ($sdkRoot in $sdkRoots) {
            $candidate = Join-Path $sdkRoot 'platform-tools\adb.exe'
            if (Test-Path -LiteralPath $candidate) {
                $adbPath = $candidate
                break
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace($adbPath)) {
        throw 'adb를 찾을 수 없습니다. Android Studio에서 SDK Platform-Tools를 설치하세요.'
    }

    try {
        $apiUri = [Uri]$ApiBaseUrl
    }
    catch {
        throw "API 주소 형식이 올바르지 않습니다: $ApiBaseUrl"
    }

    $adbArgs = @()
    if (-not [string]::IsNullOrWhiteSpace($DeviceId)) {
        $adbArgs += @('-s', $DeviceId)
    }
    $adbArgs += @('reverse', "tcp:$($apiUri.Port)", "tcp:$($apiUri.Port)")

    & $adbPath @adbArgs
    if ($LASTEXITCODE -ne 0) {
        throw 'adb reverse 설정에 실패했습니다. USB 디버깅 허용 및 연결된 기기를 확인하세요.'
    }
}

$flutter = Get-Command flutter -ErrorAction SilentlyContinue
if ($null -eq $flutter) {
    throw 'flutter를 찾을 수 없습니다. Flutter SDK를 PATH에 추가하세요.'
}

$runArgs = @(
    'run',
    "--dart-define=API_BASE_URL=$ApiBaseUrl",
    "--dart-define=GOOGLE_SERVER_CLIENT_ID=$googleClientId"
)

if (-not [string]::IsNullOrWhiteSpace($DeviceId)) {
    $runArgs += @('-d', $DeviceId)
}
if ($null -ne $FlutterArgs) {
    $runArgs += $FlutterArgs
}

Push-Location $appPath
try {
    & $flutter.Source @runArgs
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
