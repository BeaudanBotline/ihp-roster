#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: ./.loom/bin/codex-workstream-loop.sh [options]

Options:
  --workstream NAME      Resolve prompt as .loom/workstreams/NAME/prompt.md
  --prompt-file PATH     Prompt file to feed into codex exec
  --iterations N         Number of iterations to run (0 means unlimited, default: 0)
  --model MODEL          Optional codex model override
  --label LABEL          Log filename prefix (default: workstream name or codex-loop)
  --log-dir PATH         Directory for json and last-message logs
  --no-push              Skip git push after each successful iteration
  -h, --help             Show this help
EOF
}

workstream=""
prompt_file=""
iterations=0
model=""
label=""
log_dir=""
push_after_each=1

while [[ $# -gt 0 ]]; do
    case "$1" in
        --workstream)
            workstream="${2:-}"
            shift 2
            ;;
        --prompt-file)
            prompt_file="${2:-}"
            shift 2
            ;;
        --iterations)
            iterations="${2:-}"
            shift 2
            ;;
        --model)
            model="${2:-}"
            shift 2
            ;;
        --label)
            label="${2:-}"
            shift 2
            ;;
        --log-dir)
            log_dir="${2:-}"
            shift 2
            ;;
        --no-push)
            push_after_each=0
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [[ -z "$prompt_file" && -n "$workstream" ]]; then
    prompt_file=".loom/workstreams/$workstream/prompt.md"
fi

if [[ -z "$prompt_file" ]]; then
    echo "Either --workstream or --prompt-file is required." >&2
    exit 1
fi

if [[ ! "$iterations" =~ ^[0-9]+$ ]]; then
    echo "--iterations must be a non-negative integer." >&2
    exit 1
fi

if [[ ! -f "$prompt_file" ]]; then
    echo "Prompt file not found: $prompt_file" >&2
    exit 1
fi

if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
    echo "This script must be run inside a git repository." >&2
    exit 1
fi

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

current_branch="$(git branch --show-current)"
if [[ -z "$current_branch" ]]; then
    echo "Unable to determine the current git branch." >&2
    exit 1
fi

if [[ -z "$label" ]]; then
    if [[ -n "$workstream" ]]; then
        label="$workstream"
    else
        label="codex-loop"
    fi
fi

if [[ -z "$log_dir" ]]; then
    if [[ -n "$workstream" ]]; then
        log_dir=".loom/workstreams/$workstream/logs"
    else
        log_dir=".loom/logs/$label"
    fi
fi

mkdir -p "$log_dir"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Codex loop runner"
echo "Repo:        $repo_root"
echo "Branch:      $current_branch"
echo "Prompt:      $prompt_file"
echo "Iterations:  ${iterations:-0}"
echo "Model:       ${model:-default}"
echo "Logs:        $log_dir"
echo "Push:        $([[ "$push_after_each" -eq 1 ]] && echo enabled || echo disabled)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

iteration=0
while true; do
    if [[ "$iterations" -gt 0 && "$iteration" -ge "$iterations" ]]; then
        echo "Reached max iterations: $iterations"
        break
    fi

    run_number=$((iteration + 1))
    timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
    json_log="$log_dir/${label}-${run_number}-${timestamp}.jsonl"
    last_message="$log_dir/${label}-${run_number}-${timestamp}.last.txt"

    echo
    echo "======================== LOOP $run_number ========================"

    codex_cmd=(
        codex exec
        --dangerously-bypass-approvals-and-sandbox
        --cd "$repo_root"
        --json
        --output-last-message "$last_message"
    )

    if [[ -n "$model" ]]; then
        codex_cmd+=(--model "$model")
    fi

    set +e
    "${codex_cmd[@]}" - < "$prompt_file" | tee "$json_log"
    codex_status=${PIPESTATUS[0]}
    set -e

    if [[ "$codex_status" -ne 0 ]]; then
        echo "Codex iteration $run_number failed with exit code $codex_status" >&2
        exit "$codex_status"
    fi

    if [[ "$push_after_each" -eq 1 ]]; then
        git push
    fi

    iteration="$run_number"
done
