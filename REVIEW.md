# PR Review

Review conventions for this repository. Reviewers (CodeRabbit, the cross-model review, local review agents) read this file in full, so rules are written out here instead of pointed to.

## Scope

Review the change against the PR's description. A finding about work the PR deliberately leaves out is not a defect; correctness, security and privacy defects in the change always are.

## Checklist

- This repository is public. Flag credentials, tokens, keys, personal details (real names, emails, physical location), private repository or project names, internal URLs, private IP or MAC addresses and network identifiers. Secrets come from 1Password or the local keyring at apply time, never from a committed file.
- Debugging output pasted into `docs/` keeps the cause, fix and verification but replaces real hostnames, IPs and MACs with placeholders.
- A new root file that isn't meant for `$HOME` (docs, agent or review files) is listed in `.chezmoiignore` in the same change; otherwise the next apply copies it into the home directory.
- Packages are declarative: a new package goes into the right `.chezmoidata/*.yaml` layer, not into an ad-hoc install command in a script.
- `run_onchange_` / `run_after_` scripts are named with the verb that matches the action (`install`, `setup`, `configure`, `update`) and are safe to re-run.
- A script with logic (hooks, the secret helper) has its test under `test/`, run by CI.

## Don't flag

- Machine setup itself: this repository exists to set up this machine, so Bazzite, the `arch-dev` distrobox, 1Password's SSH agent and the terminal and desktop tools are expected, not private details.
- Bazzite-native or obvious setup being absent: the Bazzite docs and `ujust --list` cover it by design.
