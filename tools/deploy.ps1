# Kopiert das Addon in alle vorhandenen Ziel-Clients.
# Repo-Root ist der Addon-Ordner; .git, docs und tools bleiben draussen.
$src = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

if (-not (Test-Path (Join-Path $src "VuloGearSets.toc"))) {
    throw "Keine TOC in $src - falscher Ordner?"
}

$wow = "C:\Program Files (x86)\World of Warcraft"
$clients = @(
    @{ Name = "Anniversary (TBC)";  Path = "$wow\_anniversary_\Interface\AddOns" }
    @{ Name = "Classic Era / SoD";  Path = "$wow\_classic_era_\Interface\AddOns" }
)

$any = $false
foreach ($c in $clients) {
    if (-not (Test-Path $c.Path)) {
        Write-Output ("uebersprungen: {0} - kein AddOns-Ordner" -f $c.Name)
        continue
    }
    $dst = Join-Path $c.Path "VuloGearSets"
    if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
    New-Item -ItemType Directory -Force $dst | Out-Null

    Get-ChildItem $src -Filter "VuloGearSets*.toc" | Copy-Item -Destination $dst
    foreach ($d in 'Core', 'UI', 'Locales', 'Modules', 'Media') {
        $p = Join-Path $src $d
        if (Test-Path $p) { Copy-Item $p $dst -Recurse -Force }
    }
    Write-Output ("deployed: {0}" -f $c.Name)
    $any = $true
}

if (-not $any) { throw "Kein Ziel-Client gefunden." }
