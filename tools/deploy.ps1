# Kopiert das Addon ins Anniversary-AddOns-Verzeichnis.
# Repo-Root ist der Addon-Ordner; .git, docs und tools bleiben draussen.
$src = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$dst = "C:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\VuloGearSets"

if (-not (Test-Path (Join-Path $src "VuloGearSets.toc"))) {
    throw "Keine TOC in $src - falscher Ordner?"
}
if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
New-Item -ItemType Directory -Force $dst | Out-Null

Copy-Item (Join-Path $src "VuloGearSets.toc") $dst
foreach ($d in 'Core', 'UI', 'Locales', 'Modules', 'Media') {
    $p = Join-Path $src $d
    if (Test-Path $p) { Copy-Item $p $dst -Recurse -Force }
}
Write-Output "Deployed nach $dst"
