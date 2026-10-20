# Removes the ASK ERP 2.0 PROGRAM (files and shortcuts). The shop data (in %LOCALAPPDATA%\ASK ERP 2.0) is NOT removed.
param([string]$From = '', [switch]$Quiet)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
$name = 'ASK ERP 2.0'

# this file lives in the folder that is being removed: run again from a temporary copy
if (-not $From) {
  $dest = Split-Path -Parent $MyInvocation.MyCommand.Path
  $tmp = Join-Path $env:TEMP 'askerp2-uninstall.ps1'
  Copy-Item $MyInvocation.MyCommand.Path $tmp -Force
  $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', ('"' + $tmp + '"'), '-From', ('"' + $dest + '"'))
  if ($Quiet) { $a += '-Quiet' }
  Start-Process powershell.exe -ArgumentList $a -WindowStyle Hidden
  exit 0
}

try { Start-Transcript -Path (Join-Path $env:TEMP 'askerp2-uninstall.log') -Force | Out-Null } catch {}
try {
  $dest = $From
  if (-not $Quiet) {
    $r = [System.Windows.Forms.MessageBox]::Show("Remove $name from this computer?`n`nYour shop data (bills, products, customers) is NOT deleted.", $name, 'YesNo', 'Question')
    if ($r -ne 'Yes') { exit 0 }
  }
  Get-Process ASK_ERP_2 -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith($dest, [StringComparison]::OrdinalIgnoreCase) } | ForEach-Object {
    $_.CloseMainWindow() | Out-Null
  }
  Start-Sleep 3
  if (Get-Process ASK_ERP_2 -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith($dest, [StringComparison]::OrdinalIgnoreCase) }) { throw "$name is open. Close it and remove it again." }
  foreach ($lnk in @((Join-Path ([Environment]::GetFolderPath('Desktop')) "$name.lnk"), (Join-Path ([Environment]::GetFolderPath('Programs')) "$name.lnk"))) {
    if (Test-Path $lnk) { Remove-Item $lnk -Force }
  }
  # only the program folder this installer made (it must hold the program file)
  if ((Test-Path (Join-Path $dest 'ASK_ERP_2.exe')) -and (Test-Path $dest)) {
    # a file can stay locked for a moment after the program closed (virus scan, window closing): try again a few times
    for ($try = 1; $try -le 6 -and (Test-Path $dest); $try++) {
      Remove-Item $dest -Recurse -Force -ErrorAction SilentlyContinue
      if (Test-Path $dest) { Start-Sleep 3 }
    }
    if (Test-Path $dest) { throw 'Some program files are still in use. Close everything and remove it again.' }
  }
  Remove-Item 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\ASKERP2' -Recurse -Force -ErrorAction SilentlyContinue
  if (-not $Quiet) { [System.Windows.Forms.MessageBox]::Show("$name was removed.`nYour shop data was kept.", $name, 'OK', 'Information') | Out-Null }
} catch {
  if (-not $Quiet) { [System.Windows.Forms.MessageBox]::Show("Could not remove it:`n$($_.Exception.Message)", $name, 'OK', 'Error') | Out-Null }
  exit 1
}
