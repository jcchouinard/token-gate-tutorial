# token-gate

Cut Claude Code token use by blocking full reads of big files, and sending that work
to a cheap Haiku subagent instead. A lightweight, standalone take on the idea behind
Spotify's [shunt](https://github.com/spotify/portal-ai-plugins/tree/main/plugins/shunt)
plugin (Apache-2.0), with no Spotify dependencies.

## Use it

1. Install `jq` (macOS: `brew install jq`, Debian/Ubuntu: `sudo apt install jq`).
2. Clone and install into your project:

```bash
git clone https://github.com/jcchouinard/token-gate-tutorial.git
cd token-gate-tutorial
./install.sh /path/to/your/project      # or: ./install.sh --global
```

3. Restart Claude Code in that project. Done.

## What you get

- `.claude/hooks/check-file-size`: a PreToolUse hook that blocks a full `Read` of any file
  over 350 lines (exit code 2, with a message telling Claude what to do instead).
  Reads with `offset` or `limit`, small files and missing files are allowed.
- `.claude/hooks/check-bash-read`: optional, stops `cat`, `head`, `tail`, `less`, `more` on
  big files from dodging the gate.
- `.claude/agents/file-summarizer.md`: a read-only Haiku subagent. Big reads happen in its
  own context and only a short answer returns to your main conversation.

`install.sh` copies these into `.claude/` and merges the hook registration into your
existing `settings.json` (it is safe to run twice).

## Tune it

- Change the threshold: `MIN_LINES=200 claude`
- Remove the Bash hook: delete its entry from `.claude/settings.json`.
- Editing a big file? Claude can still read the section it needs with `offset` and `limit`.
- Keep small files, debugging and architecture work with the main model: delegation costs
  more than it saves there.

## Check it works

In Claude Code run `/hooks` to see the registered hooks. Ask Claude to summarize a file
over 350 lines: the full read should be blocked, then Claude greps, reads a slice, or calls
`file-summarizer`. Measure your own savings with `/context` and `/cost`, in dollars rather
than raw tokens. Results vary with your files and model, so no figures are promised here.
Hook behavior can change between Claude Code versions: see the
[hooks docs](https://docs.claude.com/en/docs/claude-code/hooks).

## Credit

Inspired by [spotify/portal-ai-plugins (shunt)](https://github.com/spotify/portal-ai-plugins/tree/main/plugins/shunt),
Apache-2.0. This is an independent, simplified rewrite. MIT licensed.
