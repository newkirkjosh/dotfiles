# Global Claude Instructions

## Communication Style
- Concise — lead with the action, not the reasoning
- No trailing summaries, no emojis, no filler words
- Short, direct sentences; one sentence if possible
- Github-flavored markdown

## Memory
Persistent notes live in `~/.claude/projects/-var-home-fuzzyfission/memory/` (Bazzite: `$HOME` resolves to `/var/home/...`, so project keys are `-var-home-`-prefixed). Read them when relevant at session start. Write to them when learning preferences, feedback, or project context that should persist across sessions.

## Skill Invocation
Always check for applicable skills before acting. Even a 1% chance a skill applies means invoke it. Announce which skill is being used before proceeding. Custom skills live in `~/Developer/skills` (repo `newkirkjosh/skills`); `~/.claude/skills/` holds symlinks into it, so edit the repo and follow its `AGENTS.md`.

## Tool Preferences
Prefer dedicated tools over Bash equivalents:
- File search: Glob (not find/ls)
- Content search: Grep (not grep/rg)
- Read files: Read (not cat)
- Edit files: Edit (not sed/awk)
- Write files: Write (not echo/heredoc)
Reserve Bash for operations that have no dedicated tool equivalent.

## Devil's Advocate
Auto-trigger light mode before finalizing any recommendation involving: architectural decisions, irreversible changes, significant investment (user-stated or estimated >1 day — err toward triggering when unknown), go/no-go calls, or unverified assumptions.

Manual heavy mode on: "devil's advocate this", "challenge this", "stress test this", "is this the right call", "poke holes in this".

Skip entirely for: obvious bug fixes, single-file edits with no architectural implications, explanations of existing code, tasks where user said "just do it".

Light mode always uses the labeled **Devil's Advocate** block (Steel-man / Assumptions / Failure modes / Verdict). Max ~150 words. Verdict is `confirmed` or `revised` (lowercase) — never both. Always moves forward after the verdict. Heavy mode uses a three-value verdict (`Confirm` / `Revise` / `Reconsider`, capitalized) defined in the skill file — see the `devils-advocate` skill.

## Pull Requests
Before creating any PR, read the project's `CLAUDE.md` for label and project assignment conventions. Always apply at least one type label and all applicable layer labels. Always assign to the project defined in `CLAUDE.md`. Use `--label` and `--project` flags on `gh pr create`.

## Repo Conventions
- `CLAUDE.md` contains only `@AGENTS.md`. All real instructions go in `AGENTS.md`.
- Scoped rules go in `.claude/rules/`, not nested `AGENTS.md` files.
- Don't propose new git repos or changes to a project's version control setup unless asked.

## Environment
- Host is Bazzite (immutable Fedora Atomic). Build GUI/desktop apps inside the `arch-dev` distrobox, not on the host.
- Claude cannot run `sudo`. When root is needed, give the exact command for me to run with `! <command>`.
- Prefer user-level systemd units (`systemctl --user`) over system services.
- Android emulator: run with `-gpu host`. The software renderers (swiftshader, `-gpu guest`) segfault here.
- Browsers are Flatpaks and can't read hidden dirs like `~/.claude`; copy files to `~/Downloads` before opening them.

## Safety Posture
Confirm before: destructive operations (delete, force-push, drop table), hard-to-reverse operations (amend published commits, remove packages), actions visible to others (push, PR creation, messages). When in doubt, ask.
