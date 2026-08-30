# bluefin-lynx &nbsp; [![bluebuild build badge](https://github.com/hcastilho/bluefin-lynx/actions/workflows/build.yml/badge.svg)](https://github.com/hcastilho/bluefin-lynx/actions/workflows/build.yml)

Personal [Bluefin-DX](https://projectbluefin.io/) image for `lynx` (ThinkPad X1 Yoga Gen 6), built with [BlueBuild](https://blue-build.org/).

Published to **`ghcr.io/hcastilho/bluefin-lynx`**, rebuilt daily at 06:00 UTC (20 minutes after the upstream ublue images start) and on every push to `main`.

## What's in it

Everything is declared in [`recipes/recipe.yml`](recipes/recipe.yml) — that file is the source of truth. In summary, on top of `ghcr.io/ublue-os/bluefin-dx:latest`:

| Layer | Contents |
|---|---|
| Extra repos | 1Password, Ghostty (COPR), Insync — see [`files/scripts/setup-repos.sh`](files/scripts/setup-repos.sh) |
| `rpm-ostree` | `btop`, `chezmoi`, `d2`, `neovim`, `waydroid`, `ghostty`, `insync`, `strace` |
| `bling` | 1Password (CLI `op`, SSH agent, desktop app, setgid pins on the helper binaries) |
| Homebrew / Flatpak | [`Brewfile`](files/system/usr/share/bluefin-lynx/Brewfile), baked in at `/usr/share/bluefin-lynx/Brewfile` — **not** auto-installed, see [Post-install](#post-install) |
| Flatpak removals | Thunderbird and the GNOME stock apps (Calendar, Contacts, Maps, Weather, Clocks, Cheese, Tour, Connections) |
| GNOME extensions | Screen Rotate (5389) — manual orientation + lock toggle for tablet mode |
| Files | `waydroid-landscape` / `waydroid-portrait` helpers in `/usr/bin` |

Packages inherited from the upstream base layers (not installed here) are inventoried in [`docs/packages.md`](docs/packages.md).

## Installation

Rebasing an existing Fedora Atomic install is a two-step process — first to the *unsigned* ref, so the signing keys and policy files land on disk, then to the *signed* ref.

```bash
# 1. Rebase to the unsigned image to pick up the signing policy
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/hcastilho/bluefin-lynx:latest
systemctl reboot

# 2. Rebase to the signed image
sudo rpm-ostree rebase ostree-image-signed:docker://ghcr.io/hcastilho/bluefin-lynx:latest
systemctl reboot
```

Confirm you landed on the signed ref — the `●` deployment should read `ostree-image-signed:docker://…`:

```bash
rpm-ostree status
```

### Tags

| Tag | Meaning |
|---|---|
| `latest` | Newest successful build. **This is the one to track.** |
| `20260830` | That day's build |
| `20260830-44` | That day's build, on Fedora 44 |
| `44` | Newest build on Fedora 44 |
| `797ac83-44` | Build from a specific commit, on Fedora 44 |

Pinning to a Fedora major (`:44`) rather than `:latest` keeps you off the next major version until you choose to move. Date tags are what you want when rolling back past a bad `latest` — see below.

## Updating

`uupd.timer` handles it automatically (system, Flatpaks and Homebrew). To do it by hand:

```bash
ujust update
```

## Rollback

Atomic updates mean the previous deployment is still on disk. In rough order of escalation:

**1. Roll back to the previous deployment.** The fastest fix when a fresh build breaks something:

```bash
sudo rpm-ostree rollback
systemctl reboot
```

You can also just pick the older entry from the GRUB menu at boot — hold <kbd>Esc</kbd> / <kbd>Shift</kbd> during startup — which is the escape hatch when the new deployment won't boot far enough to run the command above.

**2. Pin a known-good deployment** so it survives future upgrades rather than being garbage-collected. Indexes come from `rpm-ostree status` (0 is the booted one):

```bash
rpm-ostree status              # find the index of the good deployment
sudo ostree admin pin 1        # pin it
sudo ostree admin pin --unpin 1
```

Pin the current deployment *before* a risky change and there's always a way back.

**3. Rebase to a specific dated build** when the breakage predates the deployment still on disk. Pick a date tag from before the regression:

```bash
sudo rpm-ostree rebase ostree-image-signed:docker://ghcr.io/hcastilho/bluefin-lynx:20260826-44
systemctl reboot
```

Once you're back on a working build, re-pin to `:latest` to resume tracking daily builds — a dated tag never moves, so you'd otherwise stop getting updates silently.

**4. Fall back to upstream Bluefin-DX** if the problem is this image rather than a given build of it:

```bash
sudo rpm-ostree rebase ostree-image-signed:docker://ghcr.io/ublue-os/bluefin-dx:latest
systemctl reboot
```

`ujust rebase-helper` wraps most of the above in an interactive assistant if you'd rather not type refs by hand.

## Post-install

- **Homebrew and Flatpak packages** — the Brewfile is baked into the image but not applied automatically:
  ```bash
  brew bundle --file=/usr/share/bluefin-lynx/Brewfile
  ```
- **1Password autofill in Flatpak browsers** — see [`docs/1password-flatpak-browser-integration.md`](docs/1password-flatpak-browser-integration.md). Per-user setup; not baked into the image because the required state lives in each Flatpak's `~/.var/app/` config.

## Building locally

Requires Docker or Podman. The [`Justfile`](Justfile) wraps the BlueBuild CLI container:

```bash
just build          # Docker
just build-podman   # Podman
```

## Verification

Images are signed with [Sigstore](https://www.sigstore.dev/)'s [cosign](https://github.com/sigstore/cosign):

```bash
cosign verify --key cosign.pub ghcr.io/hcastilho/bluefin-lynx
```

## ISO

An offline ISO can be generated with the [BlueBuild instructions](https://blue-build.org/how-to/generate-iso/#_top). ISOs are too large to distribute via GitHub releases, so they aren't published here.
