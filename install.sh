#!/bin/bash
# Installs the token gate into a project (default: current directory) or globally.
#   ./install.sh                 install into the current directory
#   ./install.sh /path/to/proj   install into that project
#   ./install.sh --global        install into ~/.claude (all projects)
set -e
command -v jq >/dev/null || { echo "jq is required (macOS: brew install jq, Debian/Ubuntu: sudo apt install jq)"; exit 1; }
SRC="$(cd "$(dirname "$0")" && pwd)/.claude"

if [ "$1" = "--global" ]; then
  DEST="$HOME/.claude"; BASE='"$HOME"/.claude'
else
  TARGET="$(cd "${1:-.}" && pwd)"; DEST="$TARGET/.claude"; BASE='"$CLAUDE_PROJECT_DIR"/.claude'
fi
[ "$DEST" = "$SRC" ] && { echo "Run this from your own project, or pass its path: ./install.sh /path/to/project"; exit 1; }

mkdir -p "$DEST/hooks" "$DEST/agents"
cp "$SRC"/hooks/* "$DEST/hooks/" && chmod +x "$DEST"/hooks/*
cp "$SRC"/agents/* "$DEST/agents/"

SETTINGS="$DEST/settings.json"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
if grep -q check-file-size "$SETTINGS"; then
  echo "Hooks already registered in $SETTINGS"
else
  jq --arg r "$BASE/hooks/check-file-size" --arg b "$BASE/hooks/check-bash-read" '
    .hooks.PreToolUse += [
      {matcher:"Read", hooks:[{type:"command", command:$r}]},
      {matcher:"Bash", hooks:[{type:"command", command:$b}]}
    ]' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
  echo "Registered hooks in $SETTINGS"
fi
echo "Installed to $DEST. Restart Claude Code (hooks load at session start)."
