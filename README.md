# Cut Claude Code token use by gating big file reads

A standalone, copy-paste version of the idea behind
[shunt](https://github.com/spotify/portal-ai-plugins/tree/main/plugins/shunt)
(spotify/portal-ai-plugins). Shunt blocks large file reads with a hook and
delegates them to a cheaper model. The original needs Spotify's Portal and AiKA.
This version uses only a hook plus a built-in Claude Code subagent on Haiku.

Status: the hook scripts are tested with fake input (`scripts/test-hooks.sh`).
No savings figures are published here on purpose: savings depend on your files and model,
so steps 1 and 7 ask you to measure your own.
Hook details change between Claude Code versions, so check the
[hooks docs](https://docs.claude.com/en/docs/claude-code/hooks) before publishing.

## Folder layout

```
token-gate-tutorial/
  README.md                      this tutorial
  scripts/make-big-file.sh       generates demo/big.py (4000 lines) and demo/small.py
  scripts/test-hooks.sh          tests the hooks without Claude
  demo/.claude/
    settings.json                registers the hooks
    hooks/check-file-size        blocks full Read of big files
    hooks/check-bash-read        optional: blocks cat/head/tail of big files
    agents/file-summarizer.md    the cheap alternative (Haiku subagent)
```

## 1. The problem: measure a baseline first

Claude reads whole files into context, and every later turn pays for them again.

```bash
brew install jq                       # macOS. Debian/Ubuntu: sudo apt install jq
./scripts/make-big-file.sh            # creates demo/big.py
```

To get a true baseline, run it **without** the hooks. Temporarily move the settings file:

```bash
cd demo
mv .claude/settings.json .claude/settings.json.off
claude
```

Ask: `Summarize big.py`, then run `/context` (and `/cost`). Write the numbers in the
table in step 7. Exit, then restore the file:

```bash
mv .claude/settings.json.off .claude/settings.json
```

## 2. The size-gate hook

`demo/.claude/hooks/check-file-size` is a PreToolUse hook for the `Read` tool.

- Targeted reads (`offset` or `limit` set): allowed.
- Small files, or missing files: allowed.
- Full reads over `MIN_LINES` (default 350): blocked with exit code 2. Claude Code
  feeds the stderr message back to Claude, which then changes approach.

Shunt returns JSON (`{"decision": "block", ...}`) instead. Exit code 2 with stderr
is the simpler contract to explain, and it is a documented way to block a tool call.

## 3. Test the hooks without Claude

```bash
./scripts/test-hooks.sh
```

Expected: `11 passed, 0 failed`. It feeds fake tool input to each hook and checks
the exit code (2 blocks, 0 allows). You can also try one by hand:

```bash
cd demo
echo '{"tool_input":{"file_path":"big.py"}}' | .claude/hooks/check-file-size; echo "exit=$?"
```

## 4. Register the hooks

Already done in `demo/.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Read", "hooks": [ { "type": "command",
        "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/check-file-size" } ] },
      { "matcher": "Bash", "hooks": [ { "type": "command",
        "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/check-bash-read" } ] }
    ]
  }
}
```

The Bash hook is optional. It stops Claude from sidestepping the Read hook with
`cat`, `head` or `tail`. Pipes and redirections are let through. Delete the second
block if you only want the Read gate.

To use this in your own project, copy `demo/.claude/` into it.

## 5. Give Claude a cheap alternative

Without an alternative, Claude is just blocked. `demo/.claude/agents/file-summarizer.md`
is a Haiku subagent with read-only tools. The big read happens in its own context,
and only a short answer returns to your main context. (Same idea as shunt's
`bulk-reader`.)

## 6. Try it live

```bash
cd demo
claude
```

Then ask: `Summarize big.py`. You should see the Read get blocked, then Claude either
greps and reads a slice, or calls `file-summarizer`. Check it with `/hooks` and `/agents`
if nothing happens. Hooks load at session start, so restart Claude after editing settings.

## 7. Measure the savings

Ask the same question as the baseline in a fresh session, then run `/context` and `/cost`.
Run 3 or 4 scenarios and report **your own** numbers (shunt's 82 to 94% came from a
4,000+ line Java monorepo with a different delegate).

| Scenario | Lines | Without gate (tokens) | With gate (tokens) | Savings |
|----------|-------|-----------------------|--------------------|---------|
| One large file ("Summarize big.py") | 4,000 | | | |
| Targeted question ("Which functions multiply by 100?") | 4,000 | | | |
| Source + test pair | | | | |
| Several files | | | | |

## 8. When not to delegate

Keep these with the main model (from shunt's README):

- Editing: Claude needs the exact text. Use the escape hatch: re-read just the
  section with `offset` and `limit`.
- Debugging.
- Architecture decisions.
- Small files: the overhead costs more than it saves.

## 9. Wrap-up tips

- Change the threshold: `MIN_LINES=200 claude`
- Use `/compact` and `/clear` between tasks.
- Put project facts in `CLAUDE.md` so Claude does not rediscover them each session.
- Credit: inspired by [spotify/portal-ai-plugins (shunt)](https://github.com/spotify/portal-ai-plugins/tree/main/plugins/shunt), Apache-2.0.
  This version is a simplified rewrite with no Portal or AiKA dependency.

## Sources and further reading

- Original code: [spotify/portal-ai-plugins](https://github.com/spotify/portal-ai-plugins) on GitHub (the shunt plugin lives in `plugins/shunt`)
- Claude Code [hooks documentation](https://docs.claude.com/en/docs/claude-code/hooks)

## Differences from shunt

| | shunt | this tutorial |
|---|---|---|
| Delegate | AiKA modes via Portal CLI | Haiku subagent, built in |
| Block signal | JSON `decision` | exit code 2 + stderr |
| Delivery | plugin | copy `.claude/` folder |
| Code generation (`code-writer`) | yes | not included |
| Threshold env var | `SHUNT_MIN_LINES` | `MIN_LINES` |
