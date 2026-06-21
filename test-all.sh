#!/usr/bin/env bash
# test-all.sh — run a make target across every MVL example.
#
# Usage:
#   ./test-all.sh                  # default: run `make check` everywhere
#   ./test-all.sh test             # run `make test` everywhere
#   ./test-all.sh check test       # run multiple targets per example
#   ./test-all.sh -k coverage      # keep going on failure (default: fail fast)
#   ./test-all.sh -e crud_api      # only run on the matching example(s)
#   ./test-all.sh -x crud_api      # skip the matching example(s)
#
# Examples are auto-discovered: any subdirectory containing a Makefile.
# Targets not present in an example's Makefile are skipped (not an error).

set -u

KEEP_GOING=0
INCLUDE=()
EXCLUDE=()
TARGETS=()

usage() {
    sed -n 's/^# \{0,1\}//;3,12p' "$0"
    exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -k|--keep-going) KEEP_GOING=1; shift;;
        -e|--example)    INCLUDE+=("$2"); shift 2;;
        -x|--exclude)    EXCLUDE+=("$2"); shift 2;;
        -h|--help)       usage 0;;
        --)              shift; TARGETS+=("$@"); break;;
        -*)              echo "unknown flag: $1" >&2; usage 1;;
        *)               TARGETS+=("$1"); shift;;
    esac
done

[[ ${#TARGETS[@]} -eq 0 ]] && TARGETS=(check)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Discover examples (subdirs with a Makefile)
EXAMPLES=()
for d in */; do
    name="${d%/}"
    [[ -f "$d/Makefile" ]] || continue

    # Apply --example filter (allowlist)
    if [[ ${#INCLUDE[@]} -gt 0 ]]; then
        match=0
        for inc in "${INCLUDE[@]}"; do [[ "$name" == "$inc" ]] && match=1; done
        [[ "$match" -eq 1 ]] || continue
    fi

    # Apply --exclude filter (denylist)
    skip=0
    for exc in "${EXCLUDE[@]}"; do [[ "$name" == "$exc" ]] && skip=1; done
    [[ "$skip" -eq 1 ]] && continue

    EXAMPLES+=("$name")
done

if [[ ${#EXAMPLES[@]} -eq 0 ]]; then
    echo "no matching examples"
    exit 2
fi

GREEN='\033[32m'; RED='\033[31m'; YELLOW='\033[33m'; DIM='\033[2m'; OFF='\033[0m'
PASS=()
FAIL=()
SKIP=()

target_exists() {
    local example="$1" target="$2"
    grep -qE "^${target}:" "$example/Makefile"
}

run_one() {
    local example="$1" target="$2"
    if ! target_exists "$example" "$target"; then
        echo -e "  ${DIM}skip${OFF}    $example: target '$target' not in Makefile"
        SKIP+=("$example:$target")
        return 0
    fi
    echo -e "  ${YELLOW}run${OFF}     $example: make $target"
    if (cd "$example" && make "$target" >/tmp/test-all-$$.log 2>&1); then
        echo -e "  ${GREEN}pass${OFF}    $example: $target"
        PASS+=("$example:$target")
        return 0
    else
        echo -e "  ${RED}fail${OFF}    $example: $target"
        echo -e "${DIM}---- log tail ----${OFF}"
        tail -20 /tmp/test-all-$$.log | sed 's/^/    /'
        echo -e "${DIM}------------------${OFF}"
        FAIL+=("$example:$target")
        return 1
    fi
}

echo "examples: ${EXAMPLES[*]}"
echo "targets:  ${TARGETS[*]}"
echo

rc=0
for ex in "${EXAMPLES[@]}"; do
    for t in "${TARGETS[@]}"; do
        if ! run_one "$ex" "$t"; then
            rc=1
            [[ "$KEEP_GOING" -eq 0 ]] && break 2
        fi
    done
done

rm -f /tmp/test-all-$$.log

echo
echo -e "${GREEN}pass:${OFF} ${#PASS[@]}   ${RED}fail:${OFF} ${#FAIL[@]}   ${DIM}skip:${OFF} ${#SKIP[@]}"
if [[ ${#FAIL[@]} -gt 0 ]]; then
    echo
    echo -e "${RED}failed:${OFF}"
    for f in "${FAIL[@]}"; do echo "  - $f"; done
fi

exit "$rc"
