#!/usr/bin/env python3
"""GitHub issue cards for Claude Code's @ menu, iTerm2 hover and Cmd-click.

  issue_card.py suggest          stdin: fileSuggestion JSON {"query", "cwd"}
  issue_card.py url  N [CWD]     prints the issue URL
  issue_card.py card N [CWD]     prints the card
"""
import json
import os
import re
import shutil
import subprocess
import sys
import time

CACHE_DIR = os.path.expanduser("~/.cache/issue-card")
TTL = 600
MAX_ROWS = 15
MAX_LINE = 100
PAGES = 3
GH = shutil.which("gh") or next((p for p in ("/opt/homebrew/bin/gh", "/usr/local/bin/gh") if os.path.exists(p)), "gh")


def is_markdown_noise(line):
    s = line.strip()
    return not s or s.startswith("#") or s.startswith("<!--") or re.fullmatch(r"[-*_=]{3,}", s) is not None


def headline(issue):
    state = issue["state"].upper()
    if "pull_request" in issue:
        state += " PR"
    return f"#{issue['number']} [{state}] {issue['title']}"


def card(issue):
    rows = [headline(issue)]
    labels = [l["name"] for l in issue.get("labels") or []]
    if labels:
        rows.append("    labels: " + ", ".join(labels))
    body = [l.strip() for l in (issue.get("body") or "").splitlines() if not is_markdown_noise(l)]
    rows += ["    " + (l if len(l) <= MAX_LINE else l[:MAX_LINE - 1] + "…") for l in body[:2]]
    rows.append("    " + issue["html_url"])
    return rows


def suggest(query, issues):
    matches = sorted((i for i in issues if str(i["number"]).startswith(query)), key=lambda i: i["number"])
    exact = [i for i in matches if str(i["number"]) == query]
    rows = card(exact[0]) if exact else []
    rows += [headline(i) for i in matches if i not in exact]
    return rows[:MAX_ROWS]


def _gh(args, cwd):
    r = subprocess.run([GH, *args], cwd=cwd, capture_output=True, text=True, timeout=20)
    return r.stdout if r.returncode == 0 else None



def _cached(name, ttl, produce):
    path = os.path.join(CACHE_DIR, name)
    try:
        if time.time() - os.path.getmtime(path) < ttl:
            with open(path) as f:
                return json.load(f)
    except (OSError, ValueError):
        pass
    value = produce()
    if value is not None:
        os.makedirs(CACHE_DIR, exist_ok=True)
        with open(path, "w") as f:
            json.dump(value, f)
    return value


def repo_for(cwd):
    key = "repo-" + re.sub(r"[^A-Za-z0-9]", "_", os.path.abspath(cwd))
    def produce():
        out = _gh(["repo", "view", "--json", "nameWithOwner", "-q", ".nameWithOwner"], cwd)
        return out.strip() if out else None
    return _cached(key, 86400, produce)


def issues_for(repo):
    def produce():
        found = []
        for page in range(1, PAGES + 1):
            out = _gh(["api", f"repos/{repo}/issues?state=all&per_page=100&page={page}"], None)
            if out is None:
                return None
            batch = json.loads(out)
            found += [{k: i.get(k) for k in ("number", "title", "state", "labels", "body", "html_url")}
                      | ({"pull_request": {}} if "pull_request" in i else {}) for i in batch]
            if len(batch) < 100:
                break
        return found
    return _cached("issues-" + repo.replace("/", "__") + ".json", TTL, produce) or []


def find(number, cwd):
    repo = repo_for(cwd)
    if not repo:
        return None
    return next((i for i in issues_for(repo) if str(i["number"]) == str(number)), None)


def _files(query, cwd):
    out = subprocess.run(["git", "ls-files"], cwd=cwd, capture_output=True, text=True).stdout
    q = query.lower()
    return [f for f in out.splitlines() if q in f.lower()][:MAX_ROWS]


def main(argv):
    cmd = argv[1] if len(argv) > 1 else ""
    if cmd == "suggest":
        data = json.load(sys.stdin)
        query, cwd = data.get("query", ""), data.get("cwd") or os.getcwd()
        if query.isdigit():
            repo = repo_for(cwd)
            rows = suggest(query, issues_for(repo)) if repo else []
        else:
            rows = _files(query, cwd)
        print("\n".join(rows))
    elif cmd in ("url", "card") and len(argv) > 2:
        issue = find(argv[2].lstrip("#"), argv[3] if len(argv) > 3 else os.getcwd())
        if issue:
            print(issue["html_url"] if cmd == "url" else "\n".join(card(issue)))


if __name__ == "__main__":
    main(sys.argv)
