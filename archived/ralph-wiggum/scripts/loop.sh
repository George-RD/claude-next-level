#!/bin/bash
# Ralph Wiggum - External autonomous loop runner
# Runs claude -p in a while-true loop with plan or build prompts
#
# Usage: ./loop.sh [plan|plan-work "scope"] [max_iterations]
# Examples:
#   ./loop.sh              # Build mode, unlimited iterations
#   ./loop.sh 20           # Build mode, max 20 iterations
#   ./loop.sh plan         # Plan mode, unlimited iterations
#   ./loop.sh plan 5       # Plan mode, max 5 iterations
#   ./loop.sh plan-work "user auth with OAuth"   # Scoped planning

set -euo pipefail

# Parse arguments
MODE="build"
PROMPT_FILE="PROMPT_build.md"
MAX_ITERATIONS=0
WORK_SCOPE=""

if [[ "${1:-}" == "plan" ]]; then
    MODE="plan"
    PROMPT_FILE="PROMPT_plan.md"
    MAX_ITERATIONS=${2:-0}
    if [[ -n "$MAX_ITERATIONS" ]] && ! [[ "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
        echo "Error: max_iterations must be a positive integer, got: '$MAX_ITERATIONS'" >&2
        exit 1
    fi
elif [[ "${1:-}" == "plan-work" ]]; then
    MODE="plan-work"
    PROMPT_FILE="PROMPT_plan.md"
    if [[ -z "${2:-}" ]]; then
        echo "Error: plan-work requires a work description"
        echo "Usage: ./loop.sh plan-work \"description of the work\""
        exit 1
    fi
    WORK_SCOPE="$2"
    MAX_ITERATIONS=${3:-5}
    if ! [[ "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
        echo "Error: max_iterations must be a positive integer, got: '$MAX_ITERATIONS'" >&2
        exit 1
    fi
elif [[ "${1:-}" =~ ^[0-9]+$ ]]; then
    MAX_ITERATIONS=$1
    shift
elif [[ -n "${1:-}" ]]; then
    echo "Error: Unknown mode '${1:-}'. Usage: ./loop.sh [plan|plan-work \"scope\"] [max_iterations]" >&2
    exit 1
fi

ITERATION=0
CURRENT_BRANCH=$(git branch --show-current)

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Ralph Wiggum: Autonomous Loop"
echo "Mode:   $MODE"
echo "Prompt: $PROMPT_FILE"
echo "Branch: $CURRENT_BRANCH"
[[ -n "$WORK_SCOPE" ]] && echo "Scope:  $WORK_SCOPE"
[[ $MAX_ITERATIONS -gt 0 ]] && echo "Max:    $MAX_ITERATIONS iterations"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Verify prompt file exists
if [[ ! -f "$PROMPT_FILE" ]]; then
    echo "Error: $PROMPT_FILE not found"
    echo "Run /ralph-wiggum:init first, or create it manually."
    exit 1
fi

# Verify specs exist
if [[ ! -d "specs" ]] || [[ -z "$(ls -A specs/ 2>/dev/null)" ]]; then
    echo "Warning: specs/ directory is empty or missing."
    echo "Ralph works best with specs. Run /ralph-wiggum:spec first."
    echo ""
fi

while true; do
    if [[ $MAX_ITERATIONS -gt 0 ]] && [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
        echo "Reached max iterations: $MAX_ITERATIONS"
        break
    fi

    if [[ "$MODE" == "plan-work" ]]; then
        WORK_SCOPE="$WORK_SCOPE" envsubst < "$PROMPT_FILE" | claude -p \
            --dangerously-skip-permissions \
            --output-format=stream-json \
            --model opus \
            --verbose
    else
        claude -p \
            --dangerously-skip-permissions \
            --output-format=stream-json \
            --model opus \
            --verbose \
            < "$PROMPT_FILE"
    fi

    # Push changes after each iteration (don't let transient failures kill the loop)
    if ! git push origin "$CURRENT_BRANCH" 2>&1; then
        echo "Push failed. Trying to create remote branch..." >&2
        if ! git push -u origin "$CURRENT_BRANCH" 2>&1; then
            echo "Warning: push to '$CURRENT_BRANCH' failed. Continuing loop." >&2
        fi
    fi

    ITERATION=$((ITERATION + 1))
    echo -e "\n\n======================== RALPH ITERATION $ITERATION ========================\n"
done
