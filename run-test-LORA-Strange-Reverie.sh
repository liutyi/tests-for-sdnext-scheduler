#!/usr/bin/env bash
set -euo pipefail

# run-test.sh — combine server + model parameters and execute a test script
#
# Usage:
#   ./run-test.sh --server SERVER --model MODEL --test TEST
#   ./run-test.sh SERVER MODEL TEST
#
# Run with missing/invalid arguments to see available servers, models, tests.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
SERVER_DIR="$SCRIPT_DIR/server-parameters"
MODEL_DIR="$SCRIPT_DIR/model-parameters"
TEST_DIRS=("AiArt-tests" "couture-tests" "liutyi-tests" "other-tests")

SERVER=""
MODEL=""
TEST=""

# ---- arg parsing: supports --server/--model/--test OR 3 positionals ----
if [[ $# -gt 0 && "$1" != --* ]]; then
    SERVER="${1:-}"
    MODEL="${2:-}"
    TEST="${3:-}"
else
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --server) SERVER="${2:-}"; shift 2 ;;
            --model)  MODEL="${2:-}"; shift 2 ;;
            --test)   TEST="${2:-}"; shift 2 ;;
            -h|--help) shift ;;
            *) echo "❌ Unknown argument: $1" >&2; shift ;;
        esac
    done
fi

# ---- helpers to list available options (dir + .sh stripped) ----
list_servers() {
    for f in "$SERVER_DIR"/*.sh; do
        [ -e "$f" ] || continue
        basename "$f" .sh
    done
}

list_models() {
    for f in "$MODEL_DIR"/*.sh; do
        [ -e "$f" ] || continue
        basename "$f" .sh
    done
}

# prints "name<TAB>dir" for every test script across all test dirs
list_tests() {
    for d in "${TEST_DIRS[@]}"; do
        local dir="$SCRIPT_DIR/$d"
        [ -d "$dir" ] || continue
        for f in "$dir"/*.sh; do
            [ -e "$f" ] || continue
            printf "%s\t%s\n" "$(basename "$f" .sh)" "$d"
        done
    done
}

# resolves a test name to a full path; empty result + return 1 on no/ambiguous match
find_test_path() {
    local name="$1"
    local matches=()
    for d in "${TEST_DIRS[@]}"; do
        local candidate="$SCRIPT_DIR/$d/$name.sh"
        [ -e "$candidate" ] && matches+=("$candidate")
    done
    if [[ ${#matches[@]} -eq 1 ]]; then
        echo "${matches[0]}"
        return 0
    elif [[ ${#matches[@]} -gt 1 ]]; then
        echo "❌ Test name '$name' is ambiguous, found in multiple directories:" >&2
        printf '   %s\n' "${matches[@]}" >&2
        return 1
    else
        return 1
    fi
}

print_available() {
    echo
    echo "Available servers:"
    list_servers | sed 's/^/  - /'
    echo
    echo "Available models:"
    list_models | sed 's/^/  - /'
    echo
    echo "Available tests:"
    list_tests | sort | awk -F'\t' '{printf "  - %-35s [%s]\n", $1, $2}'
}

# ---- validation ----
missing=()

if [[ -z "$SERVER" ]]; then
    missing+=("server")
elif [[ ! -f "$SERVER_DIR/$SERVER.sh" ]]; then
    echo "❌ Unknown server: $SERVER" >&2
    missing+=("server")
fi

if [[ -z "$MODEL" ]]; then
    missing+=("model")
elif [[ ! -f "$MODEL_DIR/$MODEL.sh" ]]; then
    echo "❌ Unknown model: $MODEL" >&2
    missing+=("model")
fi

TEST_PATH=""
if [[ -z "$TEST" ]]; then
    missing+=("test")
else
    if ! TEST_PATH="$(find_test_path "$TEST")"; then
        [[ -z "$TEST_PATH" ]] && echo "❌ Unknown test: $TEST" >&2
        missing+=("test")
    fi
fi

if [[ ${#missing[@]} -gt 0 ]]; then
    echo
    echo "Usage: $(basename "$0") --server SERVER --model MODEL --test TEST"
    echo "   or: $(basename "$0") SERVER MODEL TEST"
    echo
    echo "Missing/invalid: ${missing[*]}"
    print_available
    exit 1
fi

# ---- run ----
echo "▶ server: $SERVER"
echo "▶ model:  $MODEL"
echo "▶ test:   $TEST  ($TEST_PATH)"
echo

set -a
source "$SERVER_DIR/$SERVER.sh"
source "$MODEL_DIR/$MODEL.sh"
set +a

sed -i 's/local prompt="\$2"/local prompt="StrangeDaal. $2 <lora:Strange Reverie - Krea2_000002500-bf16:1.0>"/' $TEST_PATH
exec bash "$TEST_PATH"
sed -i 's/local prompt="StrangeDaal\. \$2 <lora:Strange Reverie - Krea2_000002500-bf16:1.0>"/local prompt="$2"/' $TEST_PATH
