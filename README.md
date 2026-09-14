# ai-config

Personal AI configuration, customizations, prompts, and tool configurations.

## Contents

- **[antigravity-cli/](antigravity-cli/)**: Custom statusline and configurations for Google Antigravity CLI (`agy`).

---

## Antigravity CLI Statusline

A fast, responsive, informative terminal statusline script for Google Antigravity CLI (`agy`).

### Features

- **State indicator**: Visual agent status (`● READY`, `◆ THINKING`, `⚙ WORKING`, `🔧 TOOL`).
- **Model & Git branch**: Current LLM model name and git branch with dirty indicator.
- **Context window usage**: Visual 15-segment progress bar with color thresholds (white, yellow, red) and percentage.
- **Token telemetry**: Input (▲) and output (▼) token counters formatted in human-readable units (`k`, `M`).
- **Quota & Reset countdown**: Tracks remaining quota percentage with auto-calculated duration left until reset.
- **Agent telemetry**: Live counters for artifacts, subagents, and background tasks.
- **Sandbox badge**: Displays whether the execution sandbox is enabled.
- **Responsive multi-tier layout**: Adapts dynamically to terminal width:
  - **Wide (≥ 140 columns)**: Single continuous bar.
  - **Medium (80–139 columns)**: Two-line layout with box-drawing borders (`╭─`, `╰─`).
  - **Narrow (< 80 columns)**: Minimal compact two-line view.

### Files

- [`antigravity-cli/statusline.sh`](antigravity-cli/statusline.sh): Bash script that parses the JSON payload from `agy` via `jq` and formats the ANSI statusline.
- [`antigravity-cli/statusline.cmd`](antigravity-cli/statusline.cmd): Windows wrapper script to execute `statusline.sh` via Bash.

### Setup

1. Copy or symlink `statusline.sh` and `statusline.cmd` to `~/.gemini/antigravity-cli/`.
2. Configure `~/.gemini/antigravity-cli/settings.json` to enable the custom statusline:

   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "~/.gemini/antigravity-cli/statusline.cmd"
     }
   }
   ```

   *(On Linux/macOS, point `command` directly to `~/.gemini/antigravity-cli/statusline.sh` and ensure it is executable: `chmod +x ~/.gemini/antigravity-cli/statusline.sh`)*.
