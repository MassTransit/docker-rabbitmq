---
name: code-scanning-triage
description: Fetch a repo's GitHub security/quality findings (CodeQL code-scanning alerts, Code Quality findings, and — where available — AI findings) via the API, analyze each, fix the ones worth fixing on a branch + PR, and explain/dismiss the rest with a documented reason. Use when the user asks to triage, analyze, fix, or clean up CodeQL / code scanning / "Code Quality" / AI findings for a repo, or references the Security tab (/security/code-scanning, /security/quality, /security/quality/ai-findings).
---

# Code Scanning & Code Quality Triage

Pull a repository's findings via the GitHub API (no copy-pasting), triage each, **fix the ones that make sense** as a branch + PR, and **explain/dismiss the rest with a reason**. Default to proposing — only write/dismiss/PR after the user confirms policy (Step 0).

## The three surfaces are THREE DIFFERENT APIs — do not conflate them

| Web tab | API | Read | Dismiss via API? | AI fix |
|---|---|---|---|---|
| `/security/code-scanning` (CodeQL security alerts) | `GET /repos/{o}/{r}/code-scanning/alerts` | ✅ | ✅ `PATCH .../alerts/{n}` | ✅ Copilot Autofix `.../alerts/{n}/autofix` |
| `/security/quality` (Code Quality findings) | `GET /repos/{o}/{r}/code-quality/findings` | ✅ | ❌ no documented PATCH (read-only) | ❌ |
| `/security/quality/ai-findings` (AI findings) | **none documented** | ❌ | ❌ | — |

> Critical gotcha learned the hard way: `code-scanning/alerts` and `code-quality/findings` are **separate**. A repo can show 6 findings in the Code Quality tab while `code-scanning/alerts` returns `0`. Always query **both**. The `code-quality/findings` list supports only `state`, `per_page`, `direction`, `before`, `after` — there is **no** `type`/`source`/`tool` filter, so you cannot isolate AI findings through it (`?type=ai` is silently ignored and returns everything).

## Prerequisites (verify first, stop if missing)

- `gh auth status` authenticated. Read works with the `repo` scope (confirmed); dismissing code-scanning alerts (write) needs `repo` or `security_events`.
- Resolve `{owner}/{repo}` from `gh repo view --json nameWithOwner` unless the user named one.
- If `code-quality/setup` / `code-scanning/alerts` returns `403` (feature not enabled), stop and tell the user.

## Step 0 — Confirm policy with the user (once)

1. **Auto-dismiss code-scanning alerts?** Write `state=dismissed` to GitHub, or report-only? (Code-Quality findings can't be dismissed via API regardless — UI only.) Default: report-only.
2. **Fix delivery:** branch + PR, never `main`. Confirm base branch (default: repo default branch).
3. **Scope:** all open findings, or a severity floor (`error`/`warning`+ only, skip `note`)?

## Step 1 — Fetch all three surfaces

```bash
O=owner; R=repo
# 1) CodeQL security alerts
gh api --paginate "repos/$O/$R/code-scanning/alerts?state=open&per_page=100"
# 2) Code Quality findings  (the /security/quality tab — separate API!)
gh api --paginate "repos/$O/$R/code-quality/findings?state=open&per_page=100"
# 3) AI findings — no API: see Step 3
```

Code-scanning alert fields: `number`, `rule.id`, `rule.security_severity_level`, `most_recent_instance.location`, `.message.text`, `tool.name`.
Code-quality finding fields: `number`, `state`, `rule.{id,title,severity,category}`, `location.{path,start_line}`, `message.text`. (No tool/type/source field exists on the object.)

For every finding, **Read the source at the location and its enclosing scope** before judging — the message alone is not enough.

## Step 2 — Copilot Autofix for code-scanning alerts (the AI-assisted fix)

```bash
gh api -X POST "repos/$O/$R/code-scanning/alerts/{n}/autofix" 2>/dev/null || true  # request generation
gh api "repos/$O/$R/code-scanning/alerts/{n}/autofix"                              # read suggestion
```
Treat as a suggestion to verify and adapt, not ground truth. (No autofix exists for code-quality findings — you write those fixes yourself.)

## Step 3 — AI findings — user pastes the JSON (one-click bookmarklet)

There is **no token-accessible API**. The JSON route `.../ai-findings/findings` only answers the GitHub SPA's authenticated fetch: a PAT gets `404`, navigating directly returns `400`, and a plain `fetch` gets a CORS error (the server redirects cross-origin when the request isn't marked as an in-app fetch). The fix is the `X-Requested-With: XMLHttpRequest` header, which the user's browser sends via a **bookmarklet** that runs same-origin (cookie sent automatically — nothing sensitive to share).

1. **Open the HTML findings page** and surface its URL **in your chat reply** (not via `echo` — Claude Code hides Bash output behind "Ran 1 shell command"; no OSC 8 escape sequences, the renderer swallows them):
   ```bash
   REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
   URL="https://github.com/$REPO/security/quality/ai-findings"
   # The bookmarklet lives in whichever browser opens this page, so prefer Chrome
   # (where users typically keep it) and fall back to the default browser.
   open -a "Google Chrome" "$URL" 2>/dev/null || open "$URL" 2>/dev/null || true
   echo "$URL"   # read back, then put in your reply as a Markdown link
   ```
2. Tell the user: on that page, **click the "Copy AI findings" bookmarklet** (one-time install below), which copies the findings JSON to the clipboard; then paste it here.

   Bookmarklet (repo-agnostic — uses `location.pathname`):
   ```
   javascript:(async()=>{try{const r=await fetch(location.pathname.replace(/\/+$/,'')+'/findings',{headers:{Accept:'application/json','X-Requested-With':'XMLHttpRequest'},credentials:'include'});const t=await r.text();await navigator.clipboard.writeText(t);alert('AI findings: HTTP '+r.status+' — '+t.length+' chars copied. Paste to Claude.');}catch(e){alert('Failed: '+e.message);}})();
   ```
   Fallback if no bookmarklet: DevTools → Network → reload → click the `findings` request → **Copy response** → paste.
3. Parse the AI-findings JSON — its shape differs from code-scanning/code-quality:
   ```
   { "fileFindings": [ { "filePath": "...", "commitOid": "...",
       "findings": [ { "message": "...", "startLine": N, "endLine": M,
                       "fixFiles": [ { "filePath": "...", "diff": "<unified diff>" } ] } ] } ] }
   ```
   Each finding = `fileFindings[].filePath` + `findings[].message` + location (`startLine`/`endLine`) + a **suggested fix** at `findings[].fixFiles[].diff` (a ready unified diff). Treat that diff like Copilot Autofix — a suggestion to read and verify, not apply blindly. There is **no** `rule.id`/severity here. If the user skips, note "AI findings: none provided" and continue.

Do not replicate the cookie request yourself — the user supplies the data via the bookmarklet (or Copy-response).

## Step 4 — Triage each finding

- **FIX** — true positive with a clear, low-risk fix. Implement it (guided by Autofix where present, verified), matching surrounding style; group related fixes (e.g. several `cs/missed-readonly-modifier` in one file).
- **IGNORE** — false positive, test-only, unreachable, or an accepted trade-off. Write a one-line reason citing the code by its repo-relative path (e.g. "generic catch is the pool's deliberate resilience boundary — `HW-ReplayCrawlerFB/Herowars/HerowarsApiPool.cs:45`"). Never ignore merely because a fix is awkward.

When uncertain, classify FIX + flag low-confidence rather than dropping it.

## Step 5 — Deliver

- **Fixes:** new branch → apply → build + run tests (read `CLAUDE.md` for commands and any working agreement: branch + PR, monitor CI, never auto-merge) → open PR.
- **Dismiss (code-scanning alerts only, if opted in at Step 0):** set `dismissed_reason` to the value that fits the alert and put your justification in `dismissed_comment`.
  ```bash
  # dismissed_reason must be one of: "false positive" | "won't fix" | "used in tests"
  REASON="won't fix"   # pick per alert
  gh api -X PATCH "repos/$O/$R/code-scanning/alerts/{n}" \
    -f state=dismissed -f dismissed_reason="$REASON" \
    -f dismissed_comment="<your justification>"
  ```
  **Code-Quality findings cannot be dismissed via API** — report the ignore-reasons and tell the user to dismiss them in the UI (or fix them).
- **Report (always):** a table of every finding → decision (Fixed in PR #N / Dismiss-reason / Left-open-reason), with a count summary, separated by surface.

## What the user must provide / enable

1. **AI findings** — no token API; the user **pastes** the JSON when the skill runs (the skill derives the per-repo URL for them — Step 3). Nothing to pre-configure or store.
2. **Dismiss policy** — explicit opt-in to write `state=dismissed` on code-scanning alerts (and awareness that Code-Quality findings are UI-dismiss-only).
3. **Token scope** — `repo` already covers read + code-scanning dismiss; add `security_events` only if a dismiss call returns 403.
4. **Unattended runs** — allowlist `gh api ...code-scanning...` / `...code-quality...` in `.claude/settings.json` (or run `fewer-permission-prompts`) to avoid prompts.
