#!/usr/bin/env bash
# gt-merge-cascade — run gt merge and poll until cascade completes.
#
# Usage: gt-merge-cascade [poll-interval-seconds] [timeout-minutes]
#   defaults: poll=30s, timeout=30m
#
# Stdout (JSON):
#   success: {"result":"success","total_seconds":N,"pr_count":N,"per_pr_seconds":{"288":120,...}}
#   failure: {"result":"failed","reason":"...","detail":"..."}
#
# Exit: 0 on success, non-zero on failure.

set -eu

POLL_INTERVAL="${1:-30}"
TIMEOUT_MINUTES="${2:-30}"
TIMEOUT_SECONDS=$((TIMEOUT_MINUTES * 60))

json_str() { jq -Rs . <<<"$1"; }

fail() {
    printf '{"result":"failed","reason":%s,"detail":%s}\n' "$(json_str "$1")" "$(json_str "${2:-}")"
    exit 1
}

# 1. Validate stack is ready
DRY_RUN="$(gt merge --dry-run 2>&1)" || fail "dry-run-error" "$DRY_RUN"
grep -q "Your stack is ready to merge" <<<"$DRY_RUN" || fail "stack-not-ready" "$DRY_RUN"

# 2. Extract branch list from dry-run
BRANCHES=$(awk '/Preparing to merge:/{f=1; next} /Dry run complete/{f=0} f && /^▸/ {print $2}' <<<"$DRY_RUN")
[ -n "$BRANCHES" ] || fail "no-branches-found" "could not parse dry-run output"

# 3. Map each branch to its PR number
PR_LIST=()
for branch in $BRANCHES; do
    pr=$(gh pr list --head "$branch" --state open --json number -q '.[0].number' 2>/dev/null || true)
    [ -n "$pr" ] && PR_LIST+=("$pr")
done
[ "${#PR_LIST[@]}" -gt 0 ] || fail "no-open-prs" "stack branches have no open PRs"

# 3a. Gate on unresolved review threads. `gt merge` ignores them; we don't.
#     One GraphQL call per PR; returns only an integer count, so context cost is tiny.
REPO_NWO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null) || fail "no-repo" "could not resolve owner/repo"
REPO_OWNER="${REPO_NWO%/*}"
REPO_NAME="${REPO_NWO#*/}"
UNRESOLVED_DETAIL=""
for pr in "${PR_LIST[@]}"; do
    n=$(gh api graphql -f query='query($o:String!,$r:String!,$n:Int!){repository(owner:$o,name:$r){pullRequest(number:$n){reviewThreads(first:50){nodes{isResolved isOutdated}}}}}' \
        -F o="$REPO_OWNER" -F r="$REPO_NAME" -F n="$pr" \
        --jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved==false and .isOutdated==false)] | length' 2>/dev/null || echo "ERR")
    [ "$n" = "ERR" ] && fail "graphql-error" "could not query review threads for PR #$pr"
    [ "$n" -gt 0 ] && UNRESOLVED_DETAIL+="#${pr}:${n} "
done
[ -z "$UNRESOLVED_DETAIL" ] || fail "unresolved-review-threads" "resolve threads before merging: ${UNRESOLVED_DETAIL}"

# 4. Kick off cascade (returns quickly; merge happens server-side)
START_TIME=$(date +%s)
gt merge --no-interactive >/dev/null 2>&1 || fail "gt-merge-failed" "gt merge command returned non-zero"

# 5. Poll until all merged, any close without merge, or timeout
declare -A MERGED_AT
while true; do
    NOW=$(date +%s)
    ELAPSED=$((NOW - START_TIME))
    [ "$ELAPSED" -gt "$TIMEOUT_SECONDS" ] && fail "timeout" "exceeded ${TIMEOUT_MINUTES}m; check 'gt log' for stuck PRs"

    all_merged=true
    for pr in "${PR_LIST[@]}"; do
        [ -n "${MERGED_AT[$pr]:-}" ] && continue
        state=$(gh pr view "$pr" --json state -q .state 2>/dev/null || echo "ERROR")
        case "$state" in
            MERGED) MERGED_AT[$pr]=$NOW ;;
            CLOSED) fail "pr-closed-without-merge" "PR #$pr closed without merging mid-cascade" ;;
            OPEN)   all_merged=false ;;
            ERROR)  all_merged=false ;;  # transient API error; retry next tick
            *)      fail "unexpected-state" "PR #$pr returned state: $state" ;;
        esac
    done

    if $all_merged; then
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))

        # Build per-PR JSON object
        per_pr="{"
        first=true
        for pr in "${PR_LIST[@]}"; do
            $first || per_pr+=","
            per_pr+="\"$pr\":$(( MERGED_AT[$pr] - START_TIME ))"
            first=false
        done
        per_pr+="}"

        printf '{"result":"success","total_seconds":%d,"pr_count":%d,"per_pr_seconds":%s}\n' \
            "$DURATION" "${#PR_LIST[@]}" "$per_pr"
        exit 0
    fi

    sleep "$POLL_INTERVAL"
done
