#!/bin/bash
# Tests both hooks with fake tool input. No Claude needed. Run from anywhere.
cd "$(dirname "$0")/../demo" || exit 1
[ -f big.py ] || ../scripts/make-big-file.sh >/dev/null
command -v jq >/dev/null || { echo "jq is required: brew install jq"; exit 1; }

pass=0; fail=0
check() { # name, expected_exit, hook, json
  echo "$4" | .claude/hooks/"$3" 2>/dev/null; got=$?
  if [ "$got" = "$2" ]; then echo "PASS  $1 (exit $got)"; pass=$((pass+1))
  else echo "FAIL  $1 (expected $2, got $got)"; fail=$((fail+1)); fi
}

R=check-file-size; B=check-bash-read
check "full read of big file blocked"      2 $R '{"tool_input":{"file_path":"big.py"}}'
check "read with limit allowed"            0 $R '{"tool_input":{"file_path":"big.py","limit":50}}'
check "read with offset allowed"           0 $R '{"tool_input":{"file_path":"big.py","offset":100}}'
check "small file allowed"                 0 $R '{"tool_input":{"file_path":"small.py"}}'
check "missing file allowed"               0 $R '{"tool_input":{"file_path":"nope.py"}}'
check "cat big file blocked"               2 $B '{"tool_input":{"command":"cat big.py"}}'
check "head -n 50 big file blocked"        2 $B '{"tool_input":{"command":"head -n 50 big.py"}}'
check "cat piped to grep allowed"          0 $B '{"tool_input":{"command":"cat big.py | grep func_1"}}'
check "cat small file allowed"             0 $B '{"tool_input":{"command":"cat small.py"}}'
check "non-read command allowed"           0 $B '{"tool_input":{"command":"git status"}}'
MIN_LINES=10000 check "threshold env var raises limit" 0 $R '{"tool_input":{"file_path":"big.py"}}'

echo; echo "$pass passed, $fail failed"; [ "$fail" = 0 ]
