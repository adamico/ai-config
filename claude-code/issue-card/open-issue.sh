#!/bin/bash
# iTerm2 Smart Selection action: open-issue.sh <number>
# iTerm2 runs this from / and its \(...) interpolation silently cancels the action, so ask it for the clicked session's directory.
dir=$(osascript -e 'tell application "iTerm2" to tell current session of current window to get variable named "path"' 2>>/tmp/issue-card-click.log)
echo "$(date +%T) args=[$*] dir=$dir" >> /tmp/issue-card-click.log
url=$(/usr/bin/python3 "$HOME/.claude/issue-card/issue_card.py" url "${1#\#}" "$dir")
echo "  url=[$url]" >> /tmp/issue-card-click.log
[ -n "$url" ] && open "$url"
