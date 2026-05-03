# test/

Lightweight validation for the chezmoi-managed dotfiles. We can't actually
`rpm-ostree install` or spin up `arch-dev` in CI, so these checks focus on
what can be verified statically:

- `.chezmoidata/*.yaml` parses as valid YAML
- Every `.chezmoiscripts/*.sh.tmpl` renders via `chezmoi execute-template`
  and the rendered output passes `bash -n`
- `~/.gitconfig` and `~/.zshrc` render without template errors
- `chezmoi diff --no-pager` runs without erroring

## Run locally

From anywhere:

```bash
~/.local/share/chezmoi/test/validate.sh
```

Or from the repo root:

```bash
test/validate.sh
```

The script exits `0` on success, `1` on any check failure, `2` if a required
tool (chezmoi, yq/python3, bash) is missing.

## Requirements

- `chezmoi` on `PATH`
- `bash`
- Either `yq` (mikefarah's Go version) **or** `python3` with `PyYAML`

## CI

`.github/workflows/validate.yml` runs the same script on every push and PR to
`main` against `ubuntu-latest`. It installs chezmoi, yq, and jq, then primes
`chezmoi init` with dummy `name` / `email` / `signingkey` values so the
`promptStringOnce` calls in `.chezmoi.toml.tmpl` don't block.

## What this does NOT do

- It does not apply files to `$HOME` — running `validate.sh` is read-only with
  respect to the home directory.
- It does not actually install rpm-ostree / brew / flatpak / pacman / mise
  packages. Those scripts are guarded by `.chezmoi.osRelease.id` and render
  to empty on non-Bazzite hosts.
- It does not exercise the distrobox setup. That runs only on a real Bazzite
  host with `distrobox` available.
