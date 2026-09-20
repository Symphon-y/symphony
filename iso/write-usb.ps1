<#
.SYNOPSIS
  Writes an autarchy ISO to a USB stick from Windows -- a raw, dd-style write.

.DESCRIPTION
  The Windows counterpart of `dd if=autarchy.iso of=/dev/sdX`, for the
  build-boot-fix loop after scripts/build-iso. Windows has no dd, and the ISO is
  a hybrid image that must be written byte for byte, not copied as files.

  Run it with no -DiskNumber first: it only lists the USB disks it would accept.
  Then run it again with the one you mean. It refuses anything that is not a
  USB disk, the system or boot disk, or a disk smaller than the ISO; it shows
  what is on the disk and makes you type the disk number back before erasing;
  it checks the ISO against its .sha256 first and reads the stick back
  afterwards to prove the write. Needs an elevated (Administrator) PowerShell.

.PARAMETER Iso
  The ISO to write. Default: the newest out/autarchy-*.iso in this repo.

.PARAMETER DiskNumber
  The Windows disk number (Get-Disk) of the USB stick. Omit to just list.

.PARAMETER SkipVerify
  Skip the read-back check after writing.

.EXAMPLE
  .\iso\write-usb.ps1
  .\iso\write-usb.ps1 -DiskNumber 4
#>
[CmdletBinding()]
param(
  [string]$Iso,
  [int]$DiskNumber = -1,
  [switch]$SkipVerify
)

$ErrorActionPreference = 'Stop'

# Raw block devices only accept whole-sector I/O; 4 KiB covers both 512e and
# 4Kn drives, and 4 MiB is a comfortable chunk. Both are multiples of 4096.
$Script:Sector = 4096
$Script:Chunk = 4MB

function Get-RepoRoot {
  Split-Path -Parent $PSScriptRoot
}

function Resolve-IsoPath {
  param([string]$Path)
  if ($Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "No such file: $Path" }
    return (Resolve-Path -LiteralPath $Path).Path
  }
  $found = Get-ChildItem -Path (Join-Path (Get-RepoRoot) 'out') -Filter 'autarchy-*.iso' -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $found) { throw "No ISO given and none found in out/ -- run scripts/build-iso first, or pass -Iso." }
  $found.FullName
}

# Compares against the "<hash>  <name>" line scripts/build-iso leaves next to it.
function Test-IsoChecksum {
  param([string]$Path)
  $sumFile = "$Path.sha256"
  if (-not (Test-Path -LiteralPath $sumFile)) {
    Write-Warning "No $([IO.Path]::GetFileName($sumFile)) next to the ISO -- can't check it before writing."
    return
  }
  $expected = ((Get-Content -LiteralPath $sumFile -TotalCount 1) -split '\s+')[0].ToLowerInvariant()
  Write-Host 'Checking the ISO against its checksum ...'
  $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actual -ne $expected) { throw "Checksum mismatch: the ISO is not the file that was built." }
}

function Get-UsbDisk {
  Get-Disk | Where-Object { $_.BusType -eq 'USB' }
}

function Show-Disk {
  param($Disk)
  '{0,3}  {1,-32} {2,8:N1} GB  {3}' -f $Disk.Number, $Disk.FriendlyName, ($Disk.Size / 1GB), $Disk.PartitionStyle
}

# Every reason to refuse, checked before anything is touched.
function Assert-SafeTarget {
  param($Disk, [long]$IsoBytes)
  if ($Disk.BusType -ne 'USB') { throw "Disk $($Disk.Number) is a $($Disk.BusType) disk, not USB. Refusing." }
  if ($Disk.IsSystem -or $Disk.IsBoot) { throw "Disk $($Disk.Number) is the system/boot disk. Refusing." }
  if ($Disk.Size -lt $IsoBytes) { throw "Disk $($Disk.Number) is smaller than the ISO." }
}

function Assert-Elevated {
  $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
  if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Writing a disk needs an elevated PowerShell (right-click -> Run as administrator).'
  }
}

# Writes the whole ISO to Path (a raw device, or a file in tests), zero-padding the
# last chunk up to a whole sector as raw devices require.
function Write-Image {
  param([string]$Iso, [string]$Path)
  $total = (Get-Item -LiteralPath $Iso).Length
  $src = [IO.File]::OpenRead($Iso)
  $dst = New-Object IO.FileStream($Path, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::Write, [IO.FileShare]::ReadWrite, $Script:Sector, [IO.FileOptions]::WriteThrough)
  try {
    $buf = New-Object byte[] $Script:Chunk
    $done = 0L
    $lastReport = 0L
    while (($n = $src.Read($buf, 0, $buf.Length)) -gt 0) {
      $padded = [int]([math]::Ceiling($n / $Script:Sector) * $Script:Sector)
      if ($padded -gt $n) { [Array]::Clear($buf, $n, $padded - $n) }
      $dst.Write($buf, 0, $padded)
      $done += $n
      if ($done - $lastReport -ge 256MB -or $done -eq $total) {
        Write-Host ('  written {0:N0} / {1:N0} MB' -f ($done / 1MB), ($total / 1MB))
        $lastReport = $done
      }
    }
    $dst.Flush()
  }
  finally {
    $dst.Dispose()
    $src.Dispose()
  }
}

# SHA-256 of the first $Bytes bytes of Path, read in whole sectors.
function Get-PrefixHash {
  param([string]$Path, [long]$Bytes)
  $stream = New-Object IO.FileStream($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite, $Script:Sector)
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    $buf = New-Object byte[] $Script:Chunk
    $left = $Bytes
    while ($left -gt 0) {
      $want = [int]([math]::Min($left, $buf.Length))
      $ask = [int]([math]::Ceiling($want / $Script:Sector) * $Script:Sector)
      $got = $stream.Read($buf, 0, $ask)
      if ($got -lt $want) { throw "Short read while verifying ($got of $want bytes)." }
      [void]$sha.TransformBlock($buf, 0, $want, $null, 0)
      $left -= $want
    }
    [void]$sha.TransformFinalBlock([byte[]]::new(0), 0, 0)
    ([BitConverter]::ToString($sha.Hash) -replace '-', '').ToLowerInvariant()
  }
  finally {
    $sha.Dispose()
    $stream.Dispose()
  }
}

function Invoke-Main {
  $isoPath = Resolve-IsoPath $Iso
  $isoBytes = (Get-Item -LiteralPath $isoPath).Length
  Write-Host ("ISO: {0} ({1:N0} MB)" -f $isoPath, ($isoBytes / 1MB))

  if ($DiskNumber -lt 0) {
    $usb = @(Get-UsbDisk)
    if ($usb.Count -eq 0) { Write-Host 'No USB disks attached.'; return }
    Write-Host "`nUSB disks (nothing has been touched):"
    $usb | ForEach-Object { Show-Disk $_ }
    Write-Host "`nRun again with -DiskNumber <n> to write to one of them."
    return
  }

  $disk = Get-Disk -Number $DiskNumber
  Assert-SafeTarget $disk $isoBytes
  # Before asking anyone to confirm an erase that could not go ahead anyway.
  Assert-Elevated
  Test-IsoChecksum $isoPath

  Write-Host "`nThis will ERASE everything on:"
  Show-Disk $disk
  Get-Partition -DiskNumber $DiskNumber -ErrorAction SilentlyContinue | ForEach-Object {
    $vol = $_ | Get-Volume -ErrorAction SilentlyContinue
    '      partition {0}: {1,8:N1} GB  {2} {3}' -f $_.PartitionNumber, ($_.Size / 1GB), $vol.FileSystemLabel, $vol.DriveLetter
  }
  $answer = Read-Host "`nType the disk number ($DiskNumber) to erase it and write the ISO"
  if ($answer -ne "$DiskNumber") { throw 'Not confirmed. Nothing was written.' }

  Write-Host "`nClearing disk $DiskNumber ..."
  # A stick that is already raw has nothing to clear; that is fine.
  try { Clear-Disk -Number $DiskNumber -RemoveData -RemoveOEM -Confirm:$false }
  catch { Write-Warning "Clear-Disk: $($_.Exception.Message)" }

  $device = "\\.\PhysicalDrive$DiskNumber"
  Write-Host "Writing to $device ..."
  Write-Image -Iso $isoPath -Path $device

  if (-not $SkipVerify) {
    Write-Host 'Reading it back to verify ...'
    $want = (Get-FileHash -LiteralPath $isoPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $got = Get-PrefixHash -Path $device -Bytes $isoBytes
    if ($got -ne $want) { throw 'Verification FAILED: what is on the stick does not match the ISO. Do not boot it.' }
    Write-Host 'Verified.'
  }

  Update-Disk -Number $DiskNumber -ErrorAction SilentlyContinue
  Write-Host "`nDone. Eject the stick in Windows before pulling it out."
}

# Dot-sourcing (. .\write-usb.ps1) loads the functions without running anything.
if ($MyInvocation.InvocationName -ne '.') { Invoke-Main }
