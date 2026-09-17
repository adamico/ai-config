# issue-card

Shows a GitHub issue's card (title, state, labels, first two body lines, URL) while typing in Claude Code, and opens it with Cmd-click in iTerm2. The repo is taken from the current directory via `gh`; outside a GitHub repo nothing happens.

## Typing `@279` in Claude Code

Claude Code's `fileSuggestion` command receives `{"query", "cwd"}` on every keystroke after `@` and lists whatever lines it prints.

- `@27` lists every issue/PR whose number starts with `27`, one row each.
- `@279` shows the full card first. Picking the first row inserts `#279 [OPEN] Title`.
- Anything not all digits falls through to a `git ls-files` substring search, since this setting replaces the built-in file search.

`#` closes the `@` menu before the command runs, so the trigger is the bare number.

Issues are fetched with `gh api` (newest 300 issues and PRs) and cached for 10 minutes in `~/.cache/issue-card/`.

```json
"fileSuggestion": {
  "type": "command",
  "command": "python3 ~/.claude/issue-card/issue_card.py suggest"
}
```

## Cmd-click `#279` in iTerm2

Settings → Profiles → Advanced → Smart Selection → Edit → add:

- Regex: `#(\d+)`
- Precision: Very High
- Action: Run Command… `/Users/<you>/.claude/issue-card/open-issue.sh \1`

Two iTerm2 quirks shape `open-issue.sh`: the command runs from `/`, and using `\(path)` or any other `\(...)` interpolation in the parameter silently cancels the action. So the script asks iTerm2 for the focused session's directory over AppleScript. Clicks are logged to `/tmp/issue-card-click.log`.

## Install

```sh
ln -s ~/ai-config/claude-code/issue-card ~/.claude/issue-card
```

Needs `gh` (authenticated) and `python3`. Tests: `python3 -m unittest` in this folder.

## Not included

Hover tooltips. iTerm2 annotations can be added from its Python API, but they are pinned to screen cells, and Claude Code redraws and scrolls its own screen, so they end up on the wrong text; scanning every redraw also made the prompt sluggish.
