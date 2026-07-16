#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# finops/cost-report.sh
#
# Works out what THIS job would have cost on a GitHub-HOSTED runner, and how
# much you saved by running it on your own (self-hosted) machine. Prints a
# report to the runner TERMINAL (stdout) and to the WEB summary
# ($GITHUB_STEP_SUMMARY).
#
# Reads from the environment (GitHub sets RUNNER_* automatically):
#   ELAPSED_SECONDS  (required)  wall-clock seconds the work took
#   RUNNER_OS        Linux | Windows | macOS
#   RUNNER_ARCH      X64 | ARM64 | ...
#   RUNNER_NAME      the runner's name (nice for the header)
#   RUNS_PER_DAY     runs/day per person, for projection   (default 20)
#   WORK_DAYS        billable days per month               (default 22)
#   TEAM_SIZE        people triggering CI                  (default 6)
#   COST_OUT         optional file; writes "savings_usd=<n>" for tallying
#
# Prices are GitHub-hosted, PRIVATE-repo list price, per minute, after the
# January 2026 repricing. GitHub bills each job ROUNDED UP to the whole minute.
# Self-hosted runners are free (the proposed $0.002/min self-hosted platform
# fee was postponed indefinitely and never took effect).
# ---------------------------------------------------------------------------
set -euo pipefail

ELAPSED_SECONDS="${ELAPSED_SECONDS:-0}"
OS="${RUNNER_OS:-Linux}"
ARCH="${RUNNER_ARCH:-X64}"
NAME="${RUNNER_NAME:-this-runner}"
RUNS_PER_DAY="${RUNS_PER_DAY:-20}"
WORK_DAYS="${WORK_DAYS:-22}"
TEAM_SIZE="${TEAM_SIZE:-6}"

# --- price table (USD per minute) ------------------------------------------
RATE_LINUX_X64=0.006
RATE_LINUX_ARM=0.005
RATE_WINDOWS=0.010
RATE_MACOS=0.062
# included-minute drain multiplier (how fast a job eats your free 2,000 min)
MULT_LINUX=1
MULT_WINDOWS=2
MULT_MACOS=10

case "$OS" in
  macOS)
    RATE=$RATE_MACOS; MULT=$MULT_MACOS; OSLABEL="macOS" ;;
  Windows)
    RATE=$RATE_WINDOWS; MULT=$MULT_WINDOWS; OSLABEL="Windows" ;;
  *)
    case "$ARCH" in
      ARM64|ARM|arm64) RATE=$RATE_LINUX_ARM ;;
      *)               RATE=$RATE_LINUX_X64 ;;
    esac
    MULT=$MULT_LINUX; OSLABEL="Linux" ;;
esac

# billed minutes = ceil(seconds / 60), minimum 1
BILLED_MIN=$(( (ELAPSED_SECONDS + 59) / 60 ))
[ "$BILLED_MIN" -lt 1 ] && BILLED_MIN=1

# float helper: calc "<expr>" <decimals>
calc() { awk "BEGIN{printf \"%.$2f\", $1}"; }

HOSTED_RUN=$(calc "$BILLED_MIN * $RATE" 4)
MONTH_RUNS=$(( RUNS_PER_DAY * WORK_DAYS * TEAM_SIZE ))
HOSTED_MONTH=$(calc "$HOSTED_RUN * $MONTH_RUNS" 2)
HOSTED_YEAR=$(calc "$HOSTED_RUN * $MONTH_RUNS * 12" 2)
DRAIN=$(( BILLED_MIN * MULT ))

# same billed minutes, priced on each OS (the "OS is a $ lever" lesson)
C_LINUX=$(calc "$BILLED_MIN * $RATE_LINUX_X64" 4)
C_WIN=$(calc "$BILLED_MIN * $RATE_WINDOWS" 4)
C_MAC=$(calc "$BILLED_MIN * $RATE_MACOS" 4)

# ---------------------------------------------------------------------------
# 1) TERMINAL output (what the student sees on their own laptop)
# ---------------------------------------------------------------------------
cat <<EOF

======================================================================
  FinOps report   ${OSLABEL} / ${ARCH}   runner: ${NAME}
======================================================================
  This job ran on YOUR machine (self-hosted).
  GitHub Actions minutes cost:  \$0.00

  If it had run on a GitHub-HOSTED runner (private-repo list price):
    wall-clock time    : ${ELAPSED_SECONDS}s  ->  billed as ${BILLED_MIN} min (rounded up)
    ${OSLABEL} rate      : \$${RATE}/min
    cost of THIS run   : \$${HOSTED_RUN}
    free-minute drain  : ${BILLED_MIN} min x ${MULT}  =  ${DRAIN} of your 2,000 free min

  Same ${BILLED_MIN} billed min, priced on each OS:
    Linux \$${C_LINUX}    Windows \$${C_WIN}    macOS \$${C_MAC}
    -> macOS is ~10x Linux for identical work.

  Projected at ${RUNS_PER_DAY} runs/day x ${WORK_DAYS} days x ${TEAM_SIZE} people
  = ${MONTH_RUNS} runs/month:
    GitHub-hosted would cost : \$${HOSTED_MONTH}/month  (~\$${HOSTED_YEAR}/year)
    You pay (self-hosted)    : \$0.00
    SAVED                    : \$${HOSTED_MONTH}/month
======================================================================
EOF

# ---------------------------------------------------------------------------
# 2) WEB summary (renders on the workflow run page)
# ---------------------------------------------------------------------------
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "## FinOps report — ${OSLABEL} / ${ARCH} · \`${NAME}\`"
    echo ""
    echo "Ran on **your machine** (self-hosted) → **GitHub Actions cost: \$0.00**"
    echo ""
    echo "| What | Value |"
    echo "|---|---|"
    echo "| Wall-clock time | ${ELAPSED_SECONDS}s |"
    echo "| Billed as (rounded up) | ${BILLED_MIN} min |"
    echo "| ${OSLABEL} hosted rate | \$${RATE}/min |"
    echo "| **Cost of this run if hosted** | **\$${HOSTED_RUN}** |"
    echo "| Free-minute drain | ${BILLED_MIN} × ${MULT}× = **${DRAIN} min** |"
    echo ""
    echo "### Same ${BILLED_MIN} min, priced per OS"
    echo "| Linux | Windows | macOS |"
    echo "|---|---|---|"
    echo "| \$${C_LINUX} | \$${C_WIN} | \$${C_MAC} |"
    echo ""
    echo "macOS costs **~10× Linux** for identical work — OS choice is a budget lever."
    echo ""
    echo "### Projected at team scale"
    echo "At **${RUNS_PER_DAY}/day × ${WORK_DAYS} days × ${TEAM_SIZE} people = ${MONTH_RUNS} runs/month**:"
    echo ""
    echo "| Period | GitHub-hosted | You pay | Saved |"
    echo "|---|---|---|---|"
    echo "| Per run | \$${HOSTED_RUN} | \$0.00 | \$${HOSTED_RUN} |"
    echo "| Per month | \$${HOSTED_MONTH} | \$0.00 | **\$${HOSTED_MONTH}** |"
    echo "| Per year | \$${HOSTED_YEAR} | \$0.00 | **\$${HOSTED_YEAR}** |"
    echo ""
    echo "<sub>Private-repo list price, GitHub-hosted standard runners, post-Jan 2026. Public repos get unlimited free minutes; this models the private-repo / team-scale case.</sub>"
  } >> "$GITHUB_STEP_SUMMARY"
fi

# ---------------------------------------------------------------------------
# 3) machine-readable output for the race tally job
# ---------------------------------------------------------------------------
if [ -n "${COST_OUT:-}" ]; then
  echo "savings_usd=${HOSTED_RUN}" > "$COST_OUT"
fi
