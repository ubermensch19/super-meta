# Super Meta — project guide for agents

## One repo, one branch (ALL agents, including every Conductor workspace)

- **GitHub remote (origin):** `git@github.com:ubermensch19/super-meta.git`
  (https://github.com/ubermensch19/super-meta). Push here and nowhere else.
- **Active branch:** `icon-logo-prompt`. All feature work is committed and pushed
  on this branch. Multiple Conductor / ao agents share it, so run
  `git pull --rebase` before pushing to avoid non-fast-forward rejects.
- Do **not** create separate repos, fork the work into another remote, or push
  elsewhere. Ignore these look-alikes: `~/repos/meta-mod` (a worktree stuck on the
  stale `main` branch), `~/repos/meta-rayban-mod` (empty repo), and
  `~/repos/turbometa-rayban-ai` (a third-party reference app, not ours).
- The canonical working copy is the Conductor worktree at
  `.../conductor/workspaces/meta-mod/tunis` on `icon-logo-prompt`. Conductor gives
  each agent its own worktree/folder by design — that's fine, but every one of them
  must target THIS repo + branch above.

## Repo admin caveat

The `gh` token here is a limited GitHub App integration and **cannot create or
rename repositories** (HTTP 403). Git push over SSH works. Repo creation, renames,
and visibility changes must be done by the user in the GitHub UI.

## Layout

- `ios/` — native SwiftUI app (the product). `project.yml` is the XcodeGen source of
  truth; run `xcodegen generate` after adding or removing source files.
- `android/` — React Native (Expo) app.
- `web/` — Vite + React + Tailwind marketing site.
- `resources/` — **gitignored**, study-only reference codebases
  (`turbometa-rayban-ai`, `glasses-ref`, `VisionClaw`). Reference only — do not
  build, ship, or copy verbatim.

## Secrets

`ios/Config/Secrets.xcconfig` holds `DEVELOPMENT_TEAM` + `META_APP_ID` /
`CLIENT_TOKEN` and is gitignored. Never commit credentials.
