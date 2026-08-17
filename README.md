# git-sweep-branches

Your merged branches pile up on the remote for months. This finds the ones that are
**yours**, **already merged**, and **older than 30 days** — across every repo on your
machine — and deletes them only if you say so, one by one, per repo, or all at once.

```
$ git-sweep-branches --list
Scanning 14 repositories for branches merged and idle > 30 days...

  [1/14] api — 19
  [2/14] web — 59

api (/home/you/work/api)
  feat/payment-override                     2026-05-11    97d  PR #255 2026-05-11
  fix/blocked-connection-status             2026-03-30   139d  merged into release-candidate
  feat/unified-tariff-plans                 2026-04-10   129d  squash-merged
  ...

103 branch(es) across 6 repo(s).
```

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/Ahmed-Bitcall/git-sweep-branches/main/install.sh | sh
```

That checks your dependencies, drops the script in `~/.local/bin`, offers to fix your
`PATH`, writes a config stub, and smoke-tests the result. Needs
[`gh`](https://cli.github.com) authenticated (`gh auth login`) and bash 3.2+ — stock
macOS bash is fine.

Prefer to read before you run? Clone it and run `./install.sh`, or just copy
`bin/git-sweep-branches` anywhere on your `PATH`.

## Use

```sh
git-sweep-branches                # scan, list, then ask what to delete
git-sweep-branches --list         # list only, never prompts
git-sweep-branches --days 90      # stricter age cutoff
git-sweep-branches --repo ~/work/api --repo ~/work/web
git-sweep-branches --mode one --prune-local
git-sweep-branches --json | jq .  # feed it to something else
```

When there is something to sweep, it asks:

```
Delete these remote branches?
  [a] all at once   [r] repo by repo   [o] one by one   [q] quit
```

Every step is declinable: `N` skips, `q` stops the whole run.

## What counts as "merged"

Three signals, in order — a branch needs only one:

1. **Contained in the default branch.** Resolved per repo with `gh repo view`, so it
   works when your team integrates on something other than `main`.
2. **A merged PR** with that branch as its head.
3. **Squash-merged**: every commit already upstream by patch-id (`git cherry`), which
   is how squashed branches look when ancestry says "unmerged".

Signal 3 is capped at 200 commits ahead so a runaway branch can't stall the scan.

## What it refuses to touch

- The repo's default branch.
- Branches with an **open PR**.
- Branches **checked out** in the repo or any linked worktree.
- Names matching the protected pattern: `main`, `master`, `develop`, `staging`,
  `production`, `release-candidate`, anything containing `sprint`, and anything under
  `backup/`, `archive/`, `prod/`, `demo*`, `release-please*`, `dependabot/`,
  `revert-*`. Override with `--include-protected`, or replace the pattern with
  `--protect REGEX`.
- **Local** branches — untouched unless you pass `--prune-local`.

## Undo

Every deletion is appended to `~/.local/state/git-sweep-branches/deleted-<timestamp>.tsv`
with the branch tip SHA, before the push happens:

```
api    /home/you/work/api    feat/old-thing    3f9a1c2...    2026-08-17T14:02:11
```

Restore any of them:

```sh
cd /home/you/work/api
git push origin 3f9a1c2:refs/heads/feat/old-thing
```

GitHub also keeps deleted branches restorable from the PR page for a while — but the
log is the reliable path.

## Options

| Flag | Meaning |
| --- | --- |
| `--days N` | Minimum age of the last commit (default 30) |
| `--author EMAIL` | Match this tip author; repeatable (default: repo's `user.email`) |
| `--all-authors` | Match everyone, not just you |
| `--repo PATH` | Scan this repo; repeatable |
| `--into REF` | Extra branch that also counts as merged; repeatable |
| `--list` | List only, never prompt |
| `--json` | Machine-readable list, then exit |
| `--mode all\|repo\|one` | Skip the mode question |
| `--prune-local` | Also delete matching local branches |
| `--no-fetch` | Skip `git fetch` (faster, works off stale refs) |
| `--include-protected` | Do not skip protected-looking names |
| `--protect REGEX` | Replace the protected pattern |

## Which repos get scanned

In order: `--repo` flags → `~/.config/git-sweep-branches/repos` (one path per line) →
auto-discovery of every git repo under `$HOME`, up to 2 levels deep. Repos whose
`origin` is not GitHub are skipped.

## Uninstall

```sh
curl -fsSL https://raw.githubusercontent.com/Ahmed-Bitcall/git-sweep-branches/main/install.sh | sh -s -- --uninstall
```

Your config and deletion logs are left alone — the logs are your restore points.

## License

MIT
