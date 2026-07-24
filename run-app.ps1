param(
    [ValidateSet('emulator', 'usb', 'lan', 'ios', 'auto')]
    [string]$Target = 'auto',
    [string]$ApiBaseUrl,
    [string]$DeviceId,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$FlutterArgs
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$runnerArgs = @('run', 'tool/run_app.dart')

if ($Target -eq 'lan') {
    $runnerArgs += '--lan'
}
elseif ($Target -ne 'auto') {
    $runnerArgs += @('--target', $Target)
}
if (-not [string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
    $runnerArgs += @('--api-base-url', $ApiBaseUrl)
}
if (-not [string]::IsNullOrWhiteSpace($DeviceId)) {
    $runnerArgs += @('--device', $DeviceId)
}
if ($FlutterArgs.Count -gt 0) {
    $runnerArgs += '--'
    $runnerArgs += $FlutterArgs
}

Push-Location $repositoryRoot
try {
    & dart @runnerArgs
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
