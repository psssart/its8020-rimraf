#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Written with the help of Claude Code; reviewed by the author.
#
# Sandboxed tests for rimraf. Usage: tests/run.sh PATH-TO-RIMRAF
# Every case runs in a fresh directory under a mktemp -d sandbox in /tmp.
# The root directory check is not tested here on purpose: it would mean passing "/".

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "usage: $0 PATH-TO-RIMRAF" >&2
    exit 2
fi
BIN="$(realpath -- "$1")"
if [[ ! -x "$BIN" ]]; then
    echo "$0: not an executable: $BIN" >&2
    exit 2
fi

SANDBOX="$(mktemp -d /tmp/rimraf-test.XXXXXX)"
cleanup() {
    if [[ -n "$SANDBOX" && "$SANDBOX" == /tmp/* ]]; then
        chmod -R u+rwx "$SANDBOX"
        rm -rf "$SANDBOX"
    fi
}
trap cleanup EXIT

OUT="$SANDBOX/stdout"
ERR="$SANDBOX/stderr"
IN="$SANDBOX/stdin"
RC=0
ERRORS=""
NCASE=0
PASSED=0
FAILED=0
SKIPPED=0

# Runs rimraf with stdin from /dev/null, so a prompt can never wait for the terminal.
run() {
    RC=0
    "$BIN" "$@" >"$OUT" 2>"$ERR" </dev/null || RC=$?
}

# Like run, but the first argument is fed to stdin.
run_input() {
    printf '%s' "$1" >"$IN"
    shift
    RC=0
    "$BIN" "$@" >"$OUT" 2>"$ERR" <"$IN" || RC=$?
}

# Assertions record a failure and never stop the script.
fail() { ERRORS+="    - $*"$'\n'; }
expect_rc() { [[ "$RC" -eq "$1" ]] || fail "exit code $RC, expected $1"; }
expect_gone() { [[ ! -e "$1" && ! -L "$1" ]] || fail "'$1' still exists"; }
expect_exists() { [[ -e "$1" || -L "$1" ]] || fail "'$1' was removed"; }
expect_stdout_empty() { [[ ! -s "$OUT" ]] || fail "stdout is not empty"; }
expect_stderr_empty() { [[ ! -s "$ERR" ]] || fail "stderr is not empty"; }
expect_stdout() { grep -qxF -- "$1" "$OUT" || fail "stdout has no line '$1'"; }
expect_stderr_has() { grep -qF -- "$1" "$ERR" || fail "stderr does not contain '$1'"; }
expect_stdout_lines() {
    local n
    n="$(wc -l <"$OUT")"
    [[ "$n" -eq "$1" ]] || fail "stdout has $n lines, expected $1"
}

# test_case NAME FUNCTION: runs FUNCTION in a fresh directory and prints PASS or FAIL.
test_case() {
    NCASE=$((NCASE + 1))
    local dir="$SANDBOX/case$NCASE"
    mkdir "$dir"
    cd "$dir"
    ERRORS=""
    : >"$OUT"
    : >"$ERR"
    "$2"
    cd "$SANDBOX"
    if [[ -z "$ERRORS" ]]; then
        echo "PASS  $1"
        PASSED=$((PASSED + 1))
    else
        echo "FAIL  $1"
        printf '%s' "$ERRORS"
        sed 's/^/    stderr: /' "$ERR"
        FAILED=$((FAILED + 1))
    fi
}

# Permission checks mean nothing for root, who can write into a chmod 555 directory.
test_case_nonroot() {
    if [[ "$(id -u)" -eq 0 ]]; then
        echo "SKIP  $1 (running as root)"
        SKIPPED=$((SKIPPED + 1))
    else
        test_case "$@"
    fi
}

# --- command line ---

t_help_long() {
    run --help
    expect_rc 0
    expect_stdout "Usage: $BIN [OPTION]... PATH..."
    expect_stderr_empty
}

t_help_short() {
    run -h
    expect_rc 0
    expect_stdout "Usage: $BIN [OPTION]... PATH..."
    expect_stderr_empty
}

t_help_write_error() {
    RC=0
    "$BIN" --help >/dev/full 2>"$ERR" || RC=$?
    expect_rc 1
    expect_stderr_has "write error"
}

t_unknown_short() {
    run -x
    expect_rc 2
    expect_stdout_empty
    expect_stderr_has "invalid option"
    expect_stderr_has "--help"
}

t_unknown_long() {
    run --bogus
    expect_rc 2
    expect_stdout_empty
    expect_stderr_has "unrecognized option"
}

t_no_operand() {
    run
    expect_rc 2
    expect_stdout_empty
    expect_stderr_has "missing operand"
}

t_no_operand_after_options() {
    run -iv --
    expect_rc 2
    expect_stderr_has "missing operand"
}

# --- refusal of "." and ".." ---

# Run from a nested directory, so a broken check could only damage this case's directory.
refuse_dot() {
    mkdir -p a/b/c
    touch a/b/c/f
    cd a/b
    run "$DOT_ARG"
    expect_rc 1
    expect_stdout_empty
    expect_stderr_has "refusing to remove '.' or '..'"
    expect_exists c/f
    expect_exists ../b
    cd ../..
}

t_refusal_continues() {
    mkdir -p a/b
    touch a/b/f
    cd a/b
    run . f ..
    expect_rc 1
    expect_gone f
    expect_exists ../b
    cd ../..
}

# --- files, symlinks, empty directories ---

t_regular_file() {
    echo data >file
    run file
    expect_rc 0
    expect_gone file
    expect_stdout_empty
    expect_stderr_empty
}

t_empty_dir() {
    mkdir dir
    run dir/
    expect_rc 0
    expect_gone dir
}

t_symlink_to_file() {
    echo data >target
    ln -s target link
    run link
    expect_rc 0
    expect_gone link
    expect_exists target
}

t_dangling_symlink() {
    ln -s nowhere link
    run link
    expect_rc 0
    expect_gone link
}

t_nonexistent() {
    run missing
    expect_rc 1
    expect_stdout_empty
    expect_stderr_has "cannot remove 'missing': No such file or directory"
}

t_permission_denied() {
    mkdir ro
    touch ro/f
    chmod 555 ro
    run ro/f
    expect_rc 1
    expect_exists ro/f
    expect_stderr_has "cannot remove 'ro/f': Permission denied"
}

t_one_of_several_fails() {
    touch one three
    run one missing three
    expect_rc 1
    expect_gone one
    expect_gone three
    expect_stderr_has "cannot remove 'missing'"
}

t_verbose() {
    touch file
    run -v file
    expect_rc 0
    expect_stdout "removed 'file'"
    expect_stdout_lines 1
    expect_stderr_empty
}

t_verbose_write_error() {
    touch file
    RC=0
    "$BIN" -v file >/dev/full 2>"$ERR" </dev/null || RC=$?
    expect_rc 1
    expect_stderr_has "error writing to stdout"
}

# --- recursive deletion ---

t_nested_tree() {
    mkdir -p t/a/b/c t/x
    touch t/f t/a/f t/a/b/c/f t/x/.hidden
    ln -s ../f t/a/link
    run -v t
    expect_rc 0
    expect_gone t
    expect_stdout_lines 10
    expect_stdout "removed 't/a/b/c/f'"
    expect_stdout "removed 't/x/.hidden'"
    # A directory is reported only after its contents.
    [[ "$(tail -n 1 "$OUT")" == "removed 't'" ]] || fail "last line is not \"removed 't'\""
}

t_spaces_and_dash() {
    mkdir -p -- "-dir with space/sub dir"
    touch -- "-dir with space/sub dir/- file" ./-f
    run -- "-dir with space" -f
    expect_rc 0
    expect_gone "./-dir with space"
    expect_gone ./-f
}

t_symlink_to_outside_dir() {
    mkdir -p outside/keep tree
    touch outside/keep/k
    ln -s ../outside tree/link
    run tree
    expect_rc 0
    expect_gone tree
    expect_exists outside/keep/k
}

t_symlink_with_slash() {
    mkdir -p outside/keep
    touch outside/keep/k
    ln -s outside link
    run link/
    expect_rc 0
    expect_gone link
    expect_exists outside/keep/k
}

t_unremovable_subdir() {
    mkdir -p u/a/ro
    touch u/a/ro/f
    chmod 555 u/a/ro
    run u
    expect_rc 1
    expect_exists u/a/ro/f
    expect_stderr_has "cannot remove 'u/a/ro/f': Permission denied"
}

t_unreadable_subdir() {
    mkdir -p u/locked
    chmod 000 u/locked
    run u
    expect_rc 1
    expect_exists u/locked
    expect_stderr_has "cannot remove 'u/locked': Permission denied"
}

t_error_then_next_arg() {
    mkdir -p e1/ro e2/s
    touch e1/ro/f e2/s/f
    chmod 555 e1/ro
    run e1 e2
    expect_rc 1
    expect_exists e1/ro/f
    expect_gone e2
}

t_deep_tree() {
    local p=deep i
    for ((i = 0; i < 100; i++)); do
        p="$p/d"
    done
    mkdir -p "$p"
    touch "$p/leaf"
    run deep
    expect_rc 0
    expect_gone deep
}

# --- interactive mode ---

answer_case() {
    mkdir -p d/sub
    touch d/sub/f
    run_input "$ANSWER" -i d
    expect_rc 0
    expect_stdout_empty
    expect_stderr_has "rimraf: remove 'd' recursively? [y/N] "
    if [[ "$EXPECT" == gone ]]; then
        expect_gone d
    else
        expect_exists d/sub/f
    fi
}

t_interactive_eof() {
    mkdir d
    run -i d
    expect_rc 0
    expect_exists d
}

t_interactive_long_line() {
    mkdir a b
    local long
    long="$(printf 'y%.0s' {1..5000})"
    run_input "$long"$'\ny\n' -i a b
    expect_rc 0
    expect_exists a
    expect_gone b
}

t_interactive_per_argument() {
    mkdir a b c
    run_input $'n\ny\n' -i a b c
    expect_rc 0
    expect_exists a
    expect_gone b
    expect_exists c
}

t_interactive_verbose() {
    mkdir -p a/s
    run_input $'y\n' -i -v a
    expect_rc 0
    expect_stdout_lines 2
    expect_stdout "removed 'a'"
    expect_stderr_has "recursively?"
}

t_interactive_refused_not_asked() {
    mkdir -p x/y
    touch x/y/f
    cd x/y
    run_input $'y\n' -i . f
    expect_rc 1
    expect_gone f
    [[ "$(grep -c "recursively?" "$ERR")" -eq 1 ]] || fail "expected exactly one prompt"
    cd ../..
}

test_case "--help prints usage to stdout" t_help_long
test_case "-h prints usage to stdout" t_help_short
test_case "--help to a full device fails" t_help_write_error
test_case "unknown short option" t_unknown_short
test_case "unknown long option" t_unknown_long
test_case "no operand" t_no_operand
test_case "no operand after options" t_no_operand_after_options

for DOT_ARG in . .. ./ ../ .// c/. c/./ c/.. x/.. ./.; do
    test_case "refuse '$DOT_ARG'" refuse_dot
done
test_case "refusal does not stop other arguments" t_refusal_continues

test_case "regular file" t_regular_file
test_case "empty directory with trailing slash" t_empty_dir
test_case "symlink to a file keeps the target" t_symlink_to_file
test_case "dangling symlink" t_dangling_symlink
test_case "non-existent path" t_nonexistent
test_case_nonroot "file in a read-only directory" t_permission_denied
test_case "one of several arguments fails" t_one_of_several_fails
test_case "-v prints removed entries" t_verbose
test_case "-v to a full device fails" t_verbose_write_error

test_case "nested tree with -v" t_nested_tree
test_case "names with spaces and a leading dash" t_spaces_and_dash
test_case "symlink to a directory outside the tree" t_symlink_to_outside_dir
test_case "symlink to a directory with trailing slash" t_symlink_with_slash
test_case_nonroot "unremovable nested subdirectory" t_unremovable_subdir
test_case_nonroot "unreadable nested subdirectory" t_unreadable_subdir
test_case_nonroot "error in one argument, next one is removed" t_error_then_next_arg
test_case "100 levels of nesting" t_deep_tree

for ANSWER in $'y\n' $'Y\n' $'yes\n' yes; do
    EXPECT=gone
    test_case "-i answer $(printf '%q' "$ANSWER") removes" answer_case
done
for ANSWER in $'n\n' $'\n' $'YES\n' $'yesyes\n' $'yes please\n'; do
    EXPECT=kept
    test_case "-i answer $(printf '%q' "$ANSWER") keeps" answer_case
done
test_case "-i with stdin at EOF keeps" t_interactive_eof
test_case "-i long answer does not leak into next prompt" t_interactive_long_line
test_case "-i asks once per argument" t_interactive_per_argument
test_case "-i with -v" t_interactive_verbose
test_case "-i does not ask about refused arguments" t_interactive_refused_not_asked

echo
echo "$PASSED passed, $FAILED failed, $SKIPPED skipped"
[[ "$FAILED" -eq 0 ]]
