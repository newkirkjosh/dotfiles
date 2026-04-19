# 1Password

Replaces the WSL setup (npiperelay + socat bridge) — Linux 1Password has a native SSH agent.

## Install

Handled by `packages.yaml`:

- `1password` — GUI app
- `1password-cli` — `op` command-line tool

## Enable the SSH agent

1. Launch 1Password, sign in.
2. Settings → Developer → **Use the SSH agent**.
3. 1Password creates a socket at `~/.1password/agent.sock`.
4. `~/.zshrc` already exports `SSH_AUTH_SOCK` to that path — no extra config needed.

Verify:

```sh
ssh-add -l
# Should list your 1Password-stored SSH keys
```

## Commit signing with 1Password SSH keys

Git can sign commits with the SSH key held in 1Password. Set once per machine:

```sh
# SSH public key lives in 1Password; copy it into the signing key field.
git config --global gpg.format ssh
git config --global user.signingkey "ssh-ed25519 AAAA..."
git config --global commit.gpgsign true

# Point git at 1Password's SSH-sign binary (Linux):
git config --global gpg.ssh.program /opt/1Password/op-ssh-sign
```

The path differs slightly per distro — confirm with `pacman -Ql 1password | grep op-ssh-sign` after install.

## CLI usage

```sh
op signin                    # interactive sign-in
op item get "GitHub Token"   # read a secret
op read "op://Personal/GitHub/token"   # read via secret-reference
```

Use secret references (`op://vault/item/field`) in scripts and templates — never raw values.

## Migration notes from WSL

- Remove `.zshrc` block that spawned `socat` + `npiperelay` — no longer needed.
- Remove `gpg.ssh.program` pointing at `op-ssh-sign-wsl.exe` — replace with the Linux binary path above.
- `~/.aws` / `~/.azure` symlinks into `/mnt/c/...` go away; reconfigure with `aws configure` / `az login` on Arch.

## References

- [1Password for Linux](https://support.1password.com/install-linux/)
- [1Password SSH agent](https://developer.1password.com/docs/ssh/agent)
- [Sign commits with SSH](https://developer.1password.com/docs/ssh/git-commit-signing)
