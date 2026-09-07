$ErrorActionPreference = "Stop"

# Regenerates support/targets-v4.json from:
#   1. support/targets-v3.json  -> verified stable entries (legacy identical
#      payloads; artifacts on disk are size-checked and SHA-256 hashed).
#   2. tools/draft-catalog.json  -> DRAFT profiles for the extended Galaxy
#      catalog. Draft profiles are metadata only (listed in the app catalog so
#      coverage is visible); the app never auto-matches, downloads, or executes
#      them. They become executable only after real per-firmware payloads are
#      built (docs/PORTING.md) and the entry is flipped to "stable".
#
# Requirements: run from the repository root with artifacts/kernelsu checked out.

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

$RawPrefix = "https://raw.githubusercontent.com/BuSung-dev/Root-My-Galaxy-Payloads/main/"

function Convert-Artifact {
    param([Parameter(Mandatory = $true)][psobject]$Artifact)
    $url = $Artifact.url -as [string]
    if (-not $url.StartsWith($RawPrefix)) {
        throw "Unexpected artifact url '$url' (expected prefix $RawPrefix)"
    }
    $rel = $url.Substring($RawPrefix.Length)
    if ($rel -ne [System.Uri]::UnescapeDataString($rel) -or $rel -match '[\\\x00]' -or $rel.Contains("..")) {
        throw "Refusing non-relative url: $rel"
    }
    $file = Join-Path $RepoRoot ($rel.Replace("/", [System.IO.Path]::DirectorySeparatorChar))
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
        throw "Artifact file missing on disk for $rel"
    }
    $len = (Get-Item -LiteralPath $file).Length
    if ($len -ne ($Artifact.size -as [long])) {
        throw "Size mismatch for $rel : recorded $($Artifact.size) but file is $len"
    }
    $hash = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()
    return [ordered]@{ url = $rel; size = $len; sha256 = $hash }
}

# ---------------------------------------------------------------------------
# DRAFT device matrix
#
# The draft catalog lives in tools/draft-catalog.json. Each group:
# verification (payloadId prefix), displayPrefix (device family name),
# models, and rows (version key/label + plausible exact "X.Y.Z" kernel set
# for that line). Matching is exact and version rows are intentionally
# permissive (superset) because a device that is not on a listed kernel simply
# does not match and nothing executes. Order here is also catalog order; the
# Galaxy Watch 7 entries are listed first because they are priority 1.
# ---------------------------------------------------------------------------

# Mirrors dev.busung.s25uroot.SupportManifest.MODEL_RE so a malformed draft
# entry fails here before it ever reaches the app.
$ModelRe = '^(SM-[A-Z0-9]{4,8}|SC-[0-9]{2}[A-Z]|SCG[0-9]{2})$'
$KernelRe = '^\d+\.\d+\.\d+$'

$draftGroups = Get-Content -LiteralPath "tools/draft-catalog.json" -Raw | ConvertFrom-Json

foreach ($group in $draftGroups) {
    if (-not $group.verification -or -not $group.displayPrefix -or $group.models.Count -eq 0 -or $group.rows.Count -eq 0) {
        throw "Malformed draft group: $($group.verification)"
    }
    foreach ($model in $group.models) {
        if ($model -notmatch $ModelRe) {
            throw "Draft model '$model' (in $($group.verification)) fails MODEL_RE"
        }
    }
    foreach ($row in $group.rows) {
        if (-not $row.key -or -not $row.label -or $row.kernels.Count -eq 0) {
            throw "Malformed draft row in $($group.verification)"
        }
        foreach ($kernel in $row.kernels) {
            if ($kernel -notmatch $KernelRe) {
                throw "Draft kernel '$kernel' (in $($group.verification)) fails KERNEL_VERSION_RE"
            }
        }
    }
}

function Merge-MatrixRow {
    param([psobject]$Group, [psobject]$Row)
    $id = "$($Group.verification)-$($Row.key)"
    $name = "$($Group.displayPrefix) | $($Row.label)"
    return [ordered]@{
        payloadId = $id
        displayName = $name
        models = @($Group.models)
        kernelVersions = @($Row.kernels)
        status = "draft"
        exploit = [ordered]@{ url = ""; size = 0; sha256 = "" }
        kernelsu = [ordered]@{ url = ""; size = 0; sha256 = "" }
    }
}

# ---------------------------------------------------------------------------
# Stable entries from v3
# ---------------------------------------------------------------------------
$v3 = Get-Content -LiteralPath "support/targets-v3.json" -Raw | ConvertFrom-Json
if ($v3.schemaVersion -ne 3) {
    throw "Expected schemaVersion 3 in targets-v3.json"
}

$stable = @()
foreach ($entry in $v3.payloads) {
    $converted = [ordered]@{
        payloadId = $entry.payloadId
        displayName = $entry.displayName
        models = @($entry.models)
        kernelVersions = @($entry.kernelVersions)
    }
    if ($entry.PSObject.Properties.Name -contains "requiresFreshP0Session") {
        $converted.requiresFreshP0Session = [bool]$entry.requiresFreshP0Session
    }
    $converted.status = "stable"
    $converted.exploit = Convert-Artifact $entry.exploit
    $converted.kernelsu = Convert-Artifact $entry.kernelsu
    $stable += $converted
}

# ---------------------------------------------------------------------------
# Draft entries from the device matrix
# ---------------------------------------------------------------------------
$drafts = @()
foreach ($group in $draftGroups) {
    foreach ($row in $group.rows) {
        $drafts += Merge-MatrixRow $group $row
    }
}

if (($drafts | Where-Object { $_.payloadId -in ($stable.payloadId) }).Count -gt 0) {
    throw "Duplicate payloadId between stable and draft sets"
}
if (($drafts.payloadId | Group-Object | Where-Object Count -gt 1)) {
    throw "Duplicate payloadId inside draft set"
}

$orderedPayloads = @($stable) + @($drafts)
$manifest = [ordered]@{ schemaVersion = 4; payloads = $orderedPayloads }
$json = $manifest | ConvertTo-Json -Depth 8
Set-Content -LiteralPath "support/targets-v4.json" -Value $json -Encoding UTF8

Write-Output "OK: support/targets-v4.json written with $($stable.Count) stable and $($drafts.Count) draft entries (total $($orderedPayloads.Count))."