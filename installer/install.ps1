# ASK ERP 2.0 installer (runs from the self-extracting Setup.exe). Per-user install: no administrator needed, the shop data is never touched.
param([string]$InstallDir = '', [switch]$Quiet, [switch]$NoShortcuts, [switch]$NoLaunch)
$ErrorActionPreference = 'Stop'
try { Start-Transcript -Path (Join-Path $env:TEMP 'askerp2-install.log') -Force | Out-Null } catch {}
Add-Type -AssemblyName System.Windows.Forms
$name = 'ASK ERP 2.0'
$dest = if ($InstallDir) { $InstallDir } else { Join-Path $env:LOCALAPPDATA 'Programs\ASK ERP 2.0' }
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$zip = Join-Path $here 'app.zip'

function Say($t, $icon = 'Information') { if (-not $Quiet) { [System.Windows.Forms.MessageBox]::Show($t, $name, 'OK', $icon) | Out-Null } }

try {
  # the program must not be open while its files are replaced
  $running = Get-Process ASK_ERP_2 -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith($dest, [StringComparison]::OrdinalIgnoreCase) }
  if ($running) {
    if ($Quiet) { throw 'ASK ERP 2.0 is open. Close it and install again.' }
    $r = [System.Windows.Forms.MessageBox]::Show("ASK ERP 2.0 is open.`nClose it, then press OK to continue (Cancel stops the installation).", $name, 'OKCancel', 'Warning')
    if ($r -ne 'OK') { exit 1 }
    Start-Sleep 2
    if (Get-Process ASK_ERP_2 -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith($dest, [StringComparison]::OrdinalIgnoreCase) }) { throw 'ASK ERP 2.0 is still open. Close it and install again.' }
  }
  if (-not (Test-Path $zip)) { throw 'The installer package is damaged (app.zip is missing).' }
  New-Item -ItemType Directory -Force $dest | Out-Null
  Expand-Archive -Path $zip -DestinationPath $dest -Force
  Copy-Item (Join-Path $here 'uninstall.ps1') (Join-Path $dest 'uninstall.ps1') -Force
  $exe = Join-Path $dest 'ASK_ERP_2.exe'
  if (-not (Test-Path $exe)) { throw 'The program file was not copied.' }

  if (-not $NoShortcuts) {
    $sh = New-Object -ComObject WScript.Shell
    $targets = @((Join-Path ([Environment]::GetFolderPath('Desktop')) "$name.lnk"), (Join-Path ([Environment]::GetFolderPath('Programs')) "$name.lnk"))
    foreach ($t in $targets) {
      $s = $sh.CreateShortcut($t)
      $s.TargetPath = $exe
      $s.WorkingDirectory = $dest
      $s.Description = 'ASK ERP 2.0 - billing and stock'
      $s.Save()
    }
  }

  # Apps & features entry (this user only)
  $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\ASKERP2'
  New-Item -Path $key -Force | Out-Null
  $uninst = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + (Join-Path $dest 'uninstall.ps1') + '"'
  $props = @{ DisplayName = $name; DisplayVersion = '2.0'; Publisher = 'Senthil Enterprises'; InstallLocation = $dest; DisplayIcon = $exe; UninstallString = $uninst; NoModify = 1; NoRepair = 1 }
  foreach ($k in $props.Keys) { New-ItemProperty -Path $key -Name $k -Value $props[$k] -Force | Out-Null }

  if (-not $Quiet) {
    $r = [System.Windows.Forms.MessageBox]::Show("$name is installed.`n`nYour shop data is kept separately and was not touched.`n`nOpen the program now?", $name, 'YesNo', 'Information')
    if ($r -eq 'Yes' -and -not $NoLaunch) { Start-Process $exe -WorkingDirectory $dest }
  } elseif (-not $NoLaunch) {
    Start-Process $exe -WorkingDirectory $dest
  }
  exit 0
} catch {
  Say("The installation did not finish:`n`n$($_.Exception.Message)", 'Error')
  exit 1
}
