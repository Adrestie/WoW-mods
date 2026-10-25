# Puts the thematic HD archives built by reorg_hd.py in place, game closed.
# Old archives (and the HD pack's disabled ones) go to _reorg\anciens: nothing is deleted.
param([string]$Client = "E:\world of warcraft 3.3.5a hd")
$ErrorActionPreference = "Stop"
if (Get-Process wow -ErrorAction SilentlyContinue) { throw "the game is running: close it first" }
$data = Join-Path $Client "Data"
$new = Join-Path $Client "_reorg\nouveaux"
$old = Join-Path $Client "_reorg\anciens"
New-Item -ItemType Directory -Force $old | Out-Null
$moved = @()
foreach ($l in "5","6","7","8","a","b","e","f","s","t","w","x") { $moved += "patch-$l.mpq" }
foreach ($l in "c","i","j","k","u") { $moved += "patch-$l.mpq.disabled" }
foreach ($n in $moved) {
    $p = Join-Path $data $n
    if (Test-Path $p) { Move-Item $p (Join-Path $old $n); "moved out: $n" }
}
foreach ($f in Get-ChildItem $new -Filter "patch-*.MPQ") {
    if (Test-Path (Join-Path $data $f.Name)) { throw "$($f.Name) already in Data" }
    Move-Item $f.FullName (Join-Path $data $f.Name); "moved in: $($f.Name)"
}
