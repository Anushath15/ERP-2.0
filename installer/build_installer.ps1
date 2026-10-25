# Makes ASK-ERP-2.0-Setup.exe with IExpress (built into Windows, nothing to download).
# Run after `flutter build windows --release`:  powershell -File installer\build_installer.ps1
param([switch]$WithPrintHelper)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$rel = Join-Path $root 'build\windows\x64\runner\Release'
if (-not (Test-Path (Join-Path $rel 'ASK_ERP_2.exe'))) { throw 'Build the Windows release first.' }
$work = Join-Path $env:TEMP 'askerp2-installer-build'
Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory $work | Out-Null
# The print helper (tool\askprint) travels beside the program only when asked for with -WithPrintHelper: it has not yet been proven on a real printer
# (on this laptop it hung with "Microsoft Print to PDF"), so the default installer prints the proven way.
if ($WithPrintHelper) {
  $helper = Join-Path $root 'tool\askprint\target\release\askprint.exe'
  if (Test-Path $helper) { Copy-Item $helper $rel -Force } else { Write-Warning 'askprint.exe not built.' }
} else {
  Remove-Item (Join-Path $rel 'askprint.exe') -Force -ErrorAction SilentlyContinue
}
Compress-Archive -Path (Join-Path $rel '*') -DestinationPath (Join-Path $work 'app.zip') -Force
foreach ($f in 'install.ps1', 'uninstall.ps1', 'install.cmd') { Copy-Item (Join-Path $PSScriptRoot $f) $work }
$out = Join-Path $root 'ASK-ERP-2.0-Setup.exe'
Remove-Item $out -Force -ErrorAction SilentlyContinue
$sed = @"
[Version]
Class=IEXPRESS
SEDVersion=3
[Options]
PackagePurpose=InstallApp
ShowInstallProgramWindow=0
HideExtractAnimation=1
UseLongFileName=1
InsideCompressed=0
CAB_FixedSize=0
CAB_ResvCodeSigning=0
RebootMode=N
InstallPrompt=%InstallPrompt%
DisplayLicense=%DisplayLicense%
FinishMessage=%FinishMessage%
TargetName=%TargetName%
FriendlyName=%FriendlyName%
AppLaunched=%AppLaunched%
PostInstallCmd=%PostInstallCmd%
AdminQuietInstCmd=%AdminQuietInstCmd%
UserQuietInstCmd=%UserQuietInstCmd%
SourceFiles=SourceFiles
[Strings]
InstallPrompt=Install ASK ERP 2.0 on this computer?
DisplayLicense=
FinishMessage=
TargetName=$out
FriendlyName=ASK ERP 2.0 Setup
AppLaunched=cmd.exe /c .\install.cmd
PostInstallCmd=<None>
AdminQuietInstCmd=cmd.exe /c .\install.cmd quiet
UserQuietInstCmd=cmd.exe /c .\install.cmd quiet
FILE0="app.zip"
FILE1="install.ps1"
FILE2="uninstall.ps1"
FILE3="install.cmd"
[SourceFiles]
SourceFiles0=$work\
[SourceFiles0]
%FILE0%=
%FILE1%=
%FILE2%=
%FILE3%=
"@
$sedPath = Join-Path $work 'setup.sed'
Set-Content -Path $sedPath -Value $sed -Encoding ASCII
$p = Start-Process -FilePath "$env:SystemRoot\System32\iexpress.exe" -ArgumentList '/N', '/Q', $sedPath -Wait -PassThru -WindowStyle Hidden
if (-not (Test-Path $out)) { throw "IExpress did not make the installer (exit $($p.ExitCode))." }
'{0}  {1:N1} MB' -f $out, ((Get-Item $out).Length / 1MB)
