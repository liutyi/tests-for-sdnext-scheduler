#!/usr/bin/env bash
set -euo pipefail

# run-test.sh — combine server + model (+ optional LoRA) parameters and execute a test script
#
# Usage:
#   ./run-test.sh --server SERVER --model MODEL --test TEST [--lora LORA]
#   ./run-test.sh SERVER MODEL TEST [LORA]
#
# LORA is optional. A lora file (lora-parameters/LORA.sh) defines PROMPT_PREFIX and
# PROMPT_SUFFIX (added around every prompt) and may override any model parameter
# (STEPS, CFG, AG, SAMPLER, GUIDANCENAME, GUIDANCESCALE, ...).
# Without LORA, PROMPT_PREFIX and PROMPT_SUFFIX are empty and prompts are untouched.
#
# Run with missing/invalid arguments to see available servers, models, loras, tests.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
SERVER_DIR="$SCRIPT_DIR/server-parameters"
MODEL_DIR="$SCRIPT_DIR/model-parameters"
LORA_DIR="$SCRIPT_DIR/lora-parameters"
TEST_DIRS=("AiArt-tests" "couture-tests" "liutyi-tests" "other-tests")

SERVER=""
MODEL=""
TEST=""
LORA=""

# ---- arg parsing: supports --server/--model/--test/--lora OR 3-4 positionals ----
if [[ $# -gt 0 && "$1" != --* ]]; then
    SERVER="${1:-}"
    MODEL="${2:-}"
    TEST="${3:-}"
    LORA="${4:-}"
else
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --server) SERVER="${2:-}"; shift 2 ;;
            --model)  MODEL="${2:-}"; shift 2 ;;
            --test)   TEST="${2:-}"; shift 2 ;;
            --lora)   LORA="${2:-}"; shift 2 ;;
            -h|--help) shift ;;
            *) echo "❌ Unknown argument: $1" >&2; shift ;;
        esac
    done
fi

# ---- helpers to list available options (dir + .sh stripped) ----
list_dir() {
    local dir="$1"
    for f in "$dir"/*.sh; do
        [ -e "$f" ] || continue
        basename "$f" .sh
    done
}

list_servers() { list_dir "$SERVER_DIR"; }
list_models()  { list_dir "$MODEL_DIR"; }
list_loras()   { list_dir "$LORA_DIR"; }

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
    echo "Available loras (optional):"
    list_loras | sed 's/^/  - /'
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

# lora is optional, but if given it must exist
if [[ -n "$LORA" && ! -f "$LORA_DIR/$LORA.sh" ]]; then
    echo "❌ Unknown lora: $LORA" >&2
    missing+=("lora")
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
    echo "Usage: $(basename "$0") --server SERVER --model MODEL --test TEST [--lora LORA]"
    echo "   or: $(basename "$0") SERVER MODEL TEST [LORA]"
    echo
    echo "Missing/invalid: ${missing[*]}"
    print_available
    exit 1
fi

# ---- load parameters ----
# order matters: server -> model -> lora (lora may override model parameters)
PROMPT_PREFIX=""
PROMPT_SUFFIX=""

set -a
source "$SERVER_DIR/$SERVER.sh"
source "$MODEL_DIR/$MODEL.sh"
if [[ -n "$LORA" ]]; then
    source "$LORA_DIR/$LORA.sh"
fi
set +a

# ---- run ----
echo "▶ server: $SERVER"
echo "▶ model:  $MODEL"
echo "▶ lora:   ${LORA:-<none>}"
echo "▶ test:   $TEST  ($TEST_PATH)"
if [[ -n "$LORA" ]]; then
    echo "▶ prefix: '$PROMPT_PREFIX'"
    echo "▶ suffix: '$PROMPT_SUFFIX'"
    echo "▶ params: STEPS=${STEPS:-} CFG=${CFG:-} AG=${AG:-} SAMPLER=${SAMPLER:-} GUIDANCENAME=${GUIDANCENAME:-} GUIDANCESCALE=${GUIDANCESCALE:-}"
fi
echo

# No prefix/suffix -> run the test untouched.
if [[ -z "$PROMPT_PREFIX" && -z "$PROMPT_SUFFIX" ]]; then
    exec bash "$TEST_PATH"
fi

# Otherwise run a temporary copy of the test whose prompt line wraps $2 with
# prefix/suffix. The original test file is never modified.
export PROMPT_PREFIX PROMPT_SUFFIX
TMP_TEST="$(mktemp "$(dirname "$TEST_PATH")/.run-test-tmp.XXXXXX.sh")"
trap 'rm -f "$TMP_TEST"' EXIT

sed 's/local prompt="\$2"/local prompt="${PROMPT_PREFIX-}$2${PROMPT_SUFFIX-}"/' "$TEST_PATH" > "$TMP_TEST"

if cmp -s "$TEST_PATH" "$TMP_TEST"; then
    echo "⚠️  '$TEST' has no 'local prompt=\"\$2\"' line; prefix/suffix NOT applied." >&2
fi

rc=0
bash "$TMP_TEST" || rc=$?
exit "$rc"
