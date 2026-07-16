# ---------------------------------------------------------------------------
# finops/cost-report.ps1   (Windows twin of cost-report.sh — see it for docs)
#
# Works out what THIS job would have cost on a GitHub-HOSTED runner and prints
# to the runner TERMINAL and to the WEB summary ($env:GITHUB_STEP_SUMMARY).
# Prices: GitHub-hosted private-repo list price, per minute, post-Jan 2026.
# GitHub bills each job rounded UP to the whole minute. Self-hosted is free.
# ---------------------------------------------------------------------------
$ErrorActionPreference = "Stop"

$elapsed = 0; if ($env:ELAPSED_SECONDS) { $elapsed = [int]$env:ELAPSED_SECONDS }
$os      = if ($env:RUNNER_OS)   { $env:RUNNER_OS }   else { "Windows" }
$arch    = if ($env:RUNNER_ARCH) { $env:RUNNER_ARCH } else { "X64" }
$name    = if ($env:RUNNER_NAME) { $env:RUNNER_NAME } else { "this-runner" }
$runsDay = if ($env:RUNS_PER_DAY) { [int]$env:RUNS_PER_DAY } else { 20 }
$workDays= if ($env:WORK_DAYS)    { [int]$env:WORK_DAYS }    else { 22 }
$team    = if ($env:TEAM_SIZE)    { [int]$env:TEAM_SIZE }    else { 6 }

# price table (USD / minute)
$rLinuxX64 = 0.006; $rLinuxArm = 0.005; $rWin = 0.010; $rMac = 0.062

switch ($os) {
  "macOS"   { $rate = $rMac; $mult = 10; $osLabel = "macOS" }
  "Windows" { $rate = $rWin; $mult = 2;  $osLabel = "Windows" }
  default   {
    if ($arch -match "ARM") { $rate = $rLinuxArm } else { $rate = $rLinuxX64 }
    $mult = 1; $osLabel = "Linux"
  }
}

$billed = [math]::Ceiling($elapsed / 60.0); if ($billed -lt 1) { $billed = 1 }
$hostedRun   = $billed * $rate
$monthRuns   = $runsDay * $workDays * $team
$hostedMonth = $hostedRun * $monthRuns
$hostedYear  = $hostedMonth * 12
$drain       = $billed * $mult
$cLinux = $billed * $rLinuxX64
$cWin   = $billed * $rWin
$cMac   = $billed * $rMac

$f4 = { param($v) ("{0:N4}" -f $v) }   # 4-decimal currency
$f2 = { param($v) ("{0:N2}" -f $v) }   # 2-decimal currency

# ---- 1) TERMINAL ----------------------------------------------------------
@"

======================================================================
  FinOps report   $osLabel / $arch   runner: $name
======================================================================
  This job ran on YOUR machine (self-hosted).
  GitHub Actions minutes cost:  `$0.00

  If it had run on a GitHub-HOSTED runner (private-repo list price):
    wall-clock time    : ${elapsed}s  ->  billed as $billed min (rounded up)
    $osLabel rate      : `$$rate/min
    cost of THIS run   : `$$(& $f4 $hostedRun)
    free-minute drain  : $billed min x $mult  =  $drain of your 2,000 free min

  Same $billed billed min, priced on each OS:
    Linux `$$(& $f4 $cLinux)    Windows `$$(& $f4 $cWin)    macOS `$$(& $f4 $cMac)
    -> macOS is ~10x Linux for identical work.

  Projected at $runsDay runs/day x $workDays days x $team people
  = $monthRuns runs/month:
    GitHub-hosted would cost : `$$(& $f2 $hostedMonth)/month  (~`$$(& $f2 $hostedYear)/year)
    You pay (self-hosted)    : `$0.00
    SAVED                    : `$$(& $f2 $hostedMonth)/month
======================================================================
"@ | Write-Host

# ---- 2) WEB summary -------------------------------------------------------
if ($env:GITHUB_STEP_SUMMARY) {
  $md = @"
## FinOps report — $osLabel / $arch · ``$name``

Ran on **your machine** (self-hosted) → **GitHub Actions cost: `$0.00**

| What | Value |
|---|---|
| Wall-clock time | ${elapsed}s |
| Billed as (rounded up) | $billed min |
| $osLabel hosted rate | `$$rate/min |
| **Cost of this run if hosted** | **`$$(& $f4 $hostedRun)** |
| Free-minute drain | $billed × ${mult}× = **$drain min** |

### Same $billed min, priced per OS
| Linux | Windows | macOS |
|---|---|---|
| `$$(& $f4 $cLinux) | `$$(& $f4 $cWin) | `$$(& $f4 $cMac) |

macOS costs **~10× Linux** for identical work — OS choice is a budget lever.

### Projected at team scale
At **$runsDay/day × $workDays days × $team people = $monthRuns runs/month**:

| Period | GitHub-hosted | You pay | Saved |
|---|---|---|---|
| Per run | `$$(& $f4 $hostedRun) | `$0.00 | `$$(& $f4 $hostedRun) |
| Per month | `$$(& $f2 $hostedMonth) | `$0.00 | **`$$(& $f2 $hostedMonth)** |
| Per year | `$$(& $f2 $hostedYear) | `$0.00 | **`$$(& $f2 $hostedYear)** |

<sub>Private-repo list price, GitHub-hosted standard runners, post-Jan 2026. Public repos get unlimited free minutes; this models the private-repo / team-scale case.</sub>
"@
  Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value $md -Encoding utf8
}

# ---- 3) machine-readable output for the race tally job --------------------
if ($env:COST_OUT) {
  "savings_usd=$(& $f4 $hostedRun)" | Out-File -FilePath $env:COST_OUT -Encoding ascii
}
