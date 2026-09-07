$ErrorActionPreference = "Stop"

# Regenerates support/targets-v4.json from:
#   1. support/targets-v3.json  -> verified stable entries (legacy identical
#      payloads; artifacts on disk are size-checked and SHA-256 hashed).
#   2. the device matrix below  -> DRAFT profiles for the extended Galaxy
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
# Each group: verification (payloadId prefix), displayPrefix (device family
# name), models, and rows (version key/label + plausible exact "X.Y.Z" kernel
# set for that line). Matching is exact and version rows are intentionally
# permissive (superset) because a device that is not on a listed kernel simply
# does not match and nothing executes. Order here is also catalog order; the
# Galaxy Watch 7 entries are listed first because they are priority 1.
# ---------------------------------------------------------------------------

$draftGroups = @(

  # ---- Galaxy Watch 7 (PRIORITY 1) and companion Wear OS devices ----------
  @{
    verification = "watch7"; displayPrefix = "Galaxy Watch 7";
    models = @("SM-L300", "SM-L305U", "SM-L305F", "SM-L310", "SM-L315U", "SM-L315F");
    rows = @(@{ key = "wearos5"; label = "Wear OS 5 / One UI Watch 6"; kernels = @("6.1.62") })
  },
  @{
    verification = "watch7"; displayPrefix = "Galaxy Watch 7";
    models = @("SM-L300", "SM-L305U", "SM-L305F", "SM-L310", "SM-L315U", "SM-L315F");
    rows = @(@{ key = "wearos6"; label = "Wear OS 6 / One UI 8 Watch"; kernels = @("6.1.68") })
  },
  @{
    verification = "watch7"; displayPrefix = "Galaxy Watch 7";
    models = @("SM-L300", "SM-L305U", "SM-L305F", "SM-L310", "SM-L315U", "SM-L315F");
    rows = @(@{ key = "wearos7"; label = "Wear OS 7 / One UI 9 Watch (2026)"; kernels = @("6.1.74") })
  },
  @{
    verification = "watchu"; displayPrefix = "Galaxy Watch Ultra";
    models = @("SM-L700", "SM-L705F", "SM-L705U", "SM-L705N");
    rows = @(@{ key = "wearos5"; label = "Wear OS 5 / One UI Watch 6"; kernels = @("6.1.62") })
  },
  @{
    verification = "watchu"; displayPrefix = "Galaxy Watch Ultra";
    models = @("SM-L700", "SM-L705F", "SM-L705U", "SM-L705N");
    rows = @(@{ key = "wearos6"; label = "Wear OS 6 / One UI 8 Watch"; kernels = @("6.1.68") })
  },
  @{
    verification = "watch6"; displayPrefix = "Galaxy Watch 6 / 6 Classic";
    models = @("SM-R950", "SM-R955", "SM-R960", "SM-R965");
    rows = @(@{ key = "oneuiwatch5"; label = "Wear OS 4 / One UI Watch 5"; kernels = @("6.1.40") })
  },
  @{
    verification = "watch5"; displayPrefix = "Galaxy Watch 5 / 5 Pro";
    models = @("SM-R910", "SM-R915", "SM-R920", "SM-R925");
    rows = @(@{ key = "wearos35"; label = "Wear OS 3.5"; kernels = @("5.10.226") })
  },
  @{
    verification = "watch4"; displayPrefix = "Galaxy Watch 4 / 4 Classic";
    models = @("SM-R860", "SM-R865", "SM-R880", "SM-R885");
    rows = @(@{ key = "wearos3"; label = "Wear OS 3"; kernels = @("5.10.170", "5.10.226") })
  },

  # ---- Galaxy S22 family (Exynos 2200 / kernel 5.10.x) --------------------
  @{
    verification = "s22"; displayPrefix = "Galaxy S22 family";
    models = @("SM-S9010", "SM-S901B", "SM-S901E", "SM-S901N", "SM-S901U", "SM-S901U1", "SM-S901W", "SM-S901Z", "SC-53A", "SCG11",
               "SM-S9060", "SM-S906B", "SM-S906E", "SM-S906N", "SM-S906U", "SM-S906U1", "SM-S906W", "SM-S906Z", "SC-53B", "SCG12",
               "SM-S9080", "SM-S908B", "SM-S908E", "SM-S908N", "SM-S908Q", "SM-S908U", "SM-S908U1", "SM-S908W", "SM-S908Z", "SC-53C", "SCG13");
    rows = @(
      @{ key = "oneui-4.1"; label = "One UI 4.1 (Android 12)"; kernels = @("5.10.43", "5.10.66", "5.10.81") },
      @{ key = "oneui-5.0"; label = "One UI 5.0 (Android 13)"; kernels = @("5.10.110") },
      @{ key = "oneui-5.1"; label = "One UI 5.1 (Android 13)"; kernels = @("5.10.125", "5.10.142") },
      @{ key = "oneui-6.0"; label = "One UI 6.0 (Android 14)"; kernels = @("5.10.198") },
      @{ key = "oneui-6.1"; label = "One UI 6.1 (Android 14)"; kernels = @("5.10.208", "5.10.212", "5.10.221") },
      @{ key = "a16-2026"; label = "One UI 7/8 update line (Android 16, 2026)"; kernels = @("5.10.240", "5.10.246", "5.10.252") }
    )
  },

  # ---- Galaxy S21 family (Exynos 2100 / kernel 5.10.x) --------------------
  @{
    verification = "s21"; displayPrefix = "Galaxy S21 family";
    models = @("SM-G9910", "SM-G991B", "SM-G991E", "SM-G991N", "SM-G991U", "SM-G991U1", "SM-G991W", "SC-52A", "SCG07",
               "SM-G9960", "SM-G996B", "SM-G996E", "SM-G996N", "SM-G996U", "SM-G996U1", "SM-G996W", "SC-52B", "SCG08",
               "SM-G9980", "SM-G998B", "SM-G998E", "SM-G998N", "SM-G998U", "SM-G998U1", "SM-G998W", "SC-52C", "SCG09");
    rows = @(
      @{ key = "oneui-3.1"; label = "One UI 3.1 (Android 11)"; kernels = @("5.10.43", "5.10.59") },
      @{ key = "oneui-4.1"; label = "One UI 4.x (Android 12)"; kernels = @("5.10.66", "5.10.81", "5.10.110") },
      @{ key = "oneui-5.1"; label = "One UI 5.x (Android 13)"; kernels = @("5.10.125", "5.10.142") },
      @{ key = "oneui-6.0"; label = "One UI 6.0 (Android 14)"; kernels = @("5.10.198") },
      @{ key = "oneui-6.1"; label = "One UI 6.1 (Android 14)"; kernels = @("5.10.208", "5.10.212") }
    )
  },
  @{
    verification = "s21fe-5.10"; displayPrefix = "Galaxy S21 FE";
    models = @("SM-G990B", "SM-G990B2", "SM-G990E", "SM-G990N", "SM-G990U", "SM-G990U1", "SM-G990W2", "SM-G9900");
    rows = @(
      @{ key = "oneui-4.1"; label = "One UI 4.1 (Android 12)"; kernels = @("5.10.66", "5.10.81") },
      @{ key = "oneui-5.1"; label = "One UI 5.x (Android 13)"; kernels = @("5.10.125", "5.10.142") },
      @{ key = "oneui-6.0"; label = "One UI 6.0 (Android 14)"; kernels = @("5.10.198") },
      @{ key = "oneui-6.1"; label = "One UI 6.1 (Android 14)"; kernels = @("5.10.208", "5.10.212") }
    )
  },

  # ---- Galaxy S20 / Note20 / S20 FE (kernel 5.4.x then 5.10.x) ------------
  @{
    verification = "s20"; displayPrefix = "Galaxy S20 family";
    models = @("SM-G980F", "SM-G9810", "SM-G981B", "SM-G981N", "SM-G981U", "SM-G981U1", "SM-G981W", "SM-G981V", "SC-51A", "SCG01",
               "SM-G985F", "SM-G985N", "SM-G9860", "SM-G986B", "SM-G986N", "SM-G986U", "SM-G986U1", "SM-G986W", "SC-51B", "SCG02",
               "SM-G9880", "SM-G988B", "SM-G988N", "SM-G988U", "SM-G988U1", "SM-G988W", "SC-51C", "SCG03");
    rows = @(
      @{ key = "oneui-2.5"; label = "One UI 2.5 (Android 10)"; kernels = @("5.4.40", "5.4.59") },
      @{ key = "oneui-3.1"; label = "One UI 3.x (Android 11)"; kernels = @("5.4.86", "5.4.98", "5.4.113") },
      @{ key = "oneui-4.1"; label = "One UI 4.x (Android 12)"; kernels = @("5.4.158", "5.4.170", "5.4.180") },
      @{ key = "oneui-5.1"; label = "One UI 5.x (Android 13)"; kernels = @("5.4.198", "5.4.210") },
      @{ key = "oneui-6.0"; label = "One UI 6.0 (Android 14)"; kernels = @("5.4.224", "5.4.237") }
    )
  },
  @{
    verification = "note20-5.10"; displayPrefix = "Galaxy Note20 family";
    models = @("SM-N980F", "SM-N981B", "SM-N981N", "SM-N981U", "SM-N981U1", "SM-N981W",
               "SM-N9860", "SM-N986B", "SM-N986N", "SM-N986U", "SM-N986U1", "SM-N986W");
    rows = @(
      @{ key = "oneui-3.1"; label = "One UI 3.x (Android 11)"; kernels = @("5.4.86", "5.4.98") },
      @{ key = "oneui-4.1"; label = "One UI 4.x (Android 12, kernel 5.10)"; kernels = @("5.10.66", "5.10.81", "5.10.110") },
      @{ key = "oneui-5.1"; label = "One UI 5.x (Android 13, kernel 5.10)"; kernels = @("5.10.125", "5.10.142") }
    )
  },
  @{
    verification = "s20fe-5.10"; displayPrefix = "Galaxy S20 FE";
    models = @("SM-G780F", "SM-G7810", "SM-G781B", "SM-G781N", "SM-G781U", "SM-G781U1", "SM-G781W");
    rows = @(
      @{ key = "oneui-3.1"; label = "One UI 3.x (Android 11)"; kernels = @("5.4.86", "5.4.98") },
      @{ key = "oneui-4.1"; label = "One UI 4.x (Android 12, kernel 5.10)"; kernels = @("5.10.66", "5.10.81", "5.10.110") },
      @{ key = "oneui-5.1"; label = "One UI 5.x (Android 13, kernel 5.10)"; kernels = @("5.10.125", "5.10.142") },
      @{ key = "oneui-6.1"; label = "One UI 6.x (Android 14, kernel 5.10)"; kernels = @("5.10.198", "5.10.208") }
    )
  },

  # ---- Galaxy S23 family (kernel 5.15.x) ----------------------------------
  @{
    verification = "s23-5.15"; displayPrefix = "Galaxy S23 family";
    models = @("SM-S9110", "SM-S911B", "SM-S911E", "SM-S911N", "SM-S911U", "SM-S911U1", "SM-S911W",
               "SM-S9160", "SM-S916B", "SM-S916E", "SM-S916N", "SM-S916U", "SM-S916U1", "SM-S916W",
               "SM-S9180", "SM-S918B", "SM-S918E", "SM-S918N", "SM-S918Q", "SM-S918U", "SM-S918U1", "SM-S918W");
    rows = @(
      @{ key = "oneui-5.1"; label = "One UI 5.x (Android 13)"; kernels = @("5.15.153", "5.15.189") },
      @{ key = "oneui-6.1"; label = "One UI 6.1 (Android 14)"; kernels = @("5.15.209", "5.15.231") },
      @{ key = "a15-2026"; label = "Android 15 update line (2026)"; kernels = @("5.15.244", "5.15.248") }
    )
  },
  @{
    verification = "s23fe-5.15"; displayPrefix = "Galaxy S23 FE";
    models = @("SM-S7110", "SM-S711B", "SM-S711E", "SM-S711N", "SM-S711U", "SM-S711U1", "SM-S711W");
    rows = @(
      @{ key = "oneui-5.1"; label = "One UI 5.1 (Android 13)"; kernels = @("5.15.153") },
      @{ key = "oneui-6.1"; label = "One UI 6.1 (Android 14)"; kernels = @("5.15.209") }
    )
  },

  # ---- Galaxy Z Fold / Flip (5.15 / 6.1 / 6.6 eras) ------------------------
  @{
    verification = "z5-5.15"; displayPrefix = "Galaxy Z Fold 5 family";
    models = @("SM-F9460", "SM-F946B", "SM-F946N", "SM-F946U", "SM-F946U1", "SM-F946W",
               "SM-F7310", "SM-F731B", "SM-F731N", "SM-F731U", "SM-F731U1", "SM-F731W");
    rows = @(@{ key = "oneui-5.1"; label = "One UI 5.x (Android 13)"; kernels = @("5.15.189") })
  },
  @{
    verification = "z6-6.6"; displayPrefix = "Galaxy Z Fold 6 / Flip 6";
    models = @("SM-F9560", "SM-F956B", "SM-F956N", "SM-F956S", "SM-F956U", "SM-F956U1", "SM-F956W",
               "SM-F7410", "SM-F741B", "SM-F741N", "SM-F741S", "SM-F741U", "SM-F741U1", "SM-F741W");
    rows = @(@{ key = "oneui-6.1"; label = "One UI 6.1 (Android 14)"; kernels = @("6.6.46", "6.6.102") })
  },

  # ---- Galaxy Tab S8 / S9 / S10 / FE ---------------------------------------
  @{
    verification = "ts8-5.10"; displayPrefix = "Galaxy Tab S8 family";
    models = @("SM-X700", "SM-X700N", "SM-X706B", "SM-X706N",
               "SM-X800", "SM-X800N", "SM-X806B", "SM-X806N",
               "SM-X900", "SM-X900N", "SM-X906B", "SM-X906N");
    rows = @(
      @{ key = "oneui-4.1"; label = "One UI 4.x (Android 12)"; kernels = @("5.10.66", "5.10.81", "5.10.110") },
      @{ key = "oneui-5.1"; label = "One UI 5.x (Android 13)"; kernels = @("5.10.125", "5.10.142") },
      @{ key = "oneui-6.1"; label = "One UI 6.1 (Android 14)"; kernels = @("5.10.198", "5.10.208") }
    )
  },
  @{
    verification = "ts9-5.15"; displayPrefix = "Galaxy Tab S9 family";
    models = @("SM-X710", "SM-X7100", "SM-X710N", "SM-X716B", "SM-X716N", "SM-X716U",
               "SM-X810", "SM-X8100", "SM-X810N", "SM-X816B", "SM-X816N", "SM-X816U",
               "SM-X910", "SM-X9100", "SM-X910N", "SM-X916B", "SM-X916N", "SM-X916U", "SM-X916W");
    rows = @(
      @{ key = "oneui-5.1"; label = "One UI 5.x (Android 13)"; kernels = @("5.15.188", "5.15.189") },
      @{ key = "oneui-6.1"; label = "One UI 6.1 (Android 14)"; kernels = @("5.15.209") }
    )
  },
  @{
    verification = "ts9fe-5.15"; displayPrefix = "Galaxy Tab S9 FE family";
    models = @("SM-X510", "SM-X510N", "SM-X516B", "SM-X516U", "SM-X610", "SM-X616B");
    rows = @(@{ key = "oneui-6.1"; label = "One UI 6.1 (Android 14)"; kernels = @("5.15.209") })
  },
  @{
    verification = "ts10-6.1"; displayPrefix = "Galaxy Tab S10 family";
    models = @("SM-X820", "SM-X820N", "SM-X826B", "SM-X826U", "SM-X920", "SM-X920N", "SM-X926B", "SM-X926U");
    rows = @(@{ key = "oneui-6.1"; label = "One UI 6.x (Android 14)"; kernels = @("6.1.62") })
  },

  # ---- Galaxy A / M midrange (5.10 / 5.15 eras) ----------------------------
  @{
    verification = "a52s-5.10"; displayPrefix = "Galaxy A52s 5G";
    models = @("SM-A528B");
    rows = @(@{ key = "oneui-6.1"; label = "One UI 6.x (Android 14)"; kernels = @("5.10.226", "5.10.237") })
  },
  @{
    verification = "a54-5.15"; displayPrefix = "Galaxy A54 5G";
    models = @("SM-A5460", "SM-A546B", "SM-A546E", "SM-A546N", "SM-A546S", "SM-A546U1", "SM-A546W", "SM-A546V");
    rows = @(
      @{ key = "oneui-5.1"; label = "One UI 5.x (Android 13)"; kernels = @("5.15.199") },
      @{ key = "oneui-6.1"; label = "One UI 6.1 (Android 14)"; kernels = @("5.15.209") }
    )
  },
  @{
    verification = "a55-5.15"; displayPrefix = "Galaxy A55 5G";
    models = @("SM-A5560", "SM-A556B", "SM-A556E", "SM-A556N", "SM-A556S", "SM-A556U1", "SM-A556W");
    rows = @(
      @{ key = "oneui-6.0"; label = "One UI 6.0 (Android 14)"; kernels = @("5.15.199") },
      @{ key = "oneui-6.1"; label = "One UI 6.1 (Android 14)"; kernels = @("5.15.209") }
    )
  },
  @{
    verification = "m54-5.15"; displayPrefix = "Galaxy M54 5G";
    models = @("SM-M546B", "SM-M546F");
    rows = @(@{ key = "oneui-6.0"; label = "One UI 6.x (Android 14)"; kernels = @("5.15.199", "5.15.209") })
  },
  @{
    verification = "m55-5.15"; displayPrefix = "Galaxy M55 5G";
    models = @("SM-M556B", "SM-M556F");
    rows = @(@{ key = "oneui-6.0"; label = "One UI 6.x (Android 14)"; kernels = @("5.15.199", "5.15.209") })
  },
  @{
    verification = "m53-5.10"; displayPrefix = "Galaxy M53 5G";
    models = @("SM-M536B");
    rows = @(@{ key = "oneui-5.1"; label = "One UI 5.x (Android 13)"; kernels = @("5.10.237") })
  },

  # ---- Galaxy S24 family: remaining regional variants ----------------------
  @{
    verification = "s24-models-6.1"; displayPrefix = "Galaxy S24 series";
    models = @("SM-S921U", "SM-S921U1", "SM-S921W", "SM-S9210", "SM-S921E",
               "SM-S926U", "SM-S926U1", "SM-S926W", "SM-S9260", "SM-S926N", "SM-S926E",
               "SM-S928U", "SM-S928N", "SM-S928E");
    rows = @(
      @{ key = "oneui-6.1"; label = "One UI 6.1 (Android 14)"; kernels = @("6.1.145", "6.1.157") },
      @{ key = "a15-2026"; label = "Android 15 update line (2026)"; kernels = @("6.1.171") }
    )
  }
)

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