# CLAUDE.md

## Project Overview

`bluefin-lynx` is a custom Linux OS image built on top of **Bluefin-DX** (a developer-focused Fedora Atomic/Silverblue variant). It uses the [BlueBuild](https://blue-build.org/) system to declaratively compose OCI container images that are published to the GitHub Container Registry and rebased onto a running system via `rpm-ostree`.

Published image: `ghcr.io/hcastilho/bluefin-lynx`

## Repository Structure

```
bluefin-lynx/
├── recipes/recipe.yml          # Main image recipe — the only file that usually needs editing
├── files/
│   ├── scripts/                # Custom shell scripts executed during the build
│   └── system/                 # Files copied verbatim into the image root (etc/, usr/)
├── modules/                    # Custom BlueBuild modules (currently empty)
├── .github/workflows/build.yml # CI/CD — builds and publishes the image
├── cosign.pub                  # Public key for verifying signed image releases
└── README.md
```

## How the Build Works

1. The GitHub Actions workflow (`.github/workflows/build.yml`) triggers on push, PR, daily schedule, or manual dispatch.
2. It calls `blue-build/github-action@v1.11`, which reads `recipes/recipe.yml`.
3. The recipe declares a base image and an ordered list of **modules** (rpm-ostree, brew, flatpaks, scripts, signing, etc.).
4. The resulting OCI image is pushed to `ghcr.io/hcastilho/bluefin-lynx` and signed with cosign.

## Editing the Image

All customizations live in [recipes/recipe.yml](recipes/recipe.yml). Modules are executed **in order**, so placement matters.

### Adding RPM packages

```yaml
- type: rpm-ostree
  install:
    - package-name
```

### Adding a third-party RPM repo

```yaml
- type: rpm-ostree
  repos:
    - https://example.com/repo.repo
  install:
    - package-from-repo
```

### Running arbitrary shell commands during build

```yaml
- type: script
  snippets:
    - "command to run"
```

Or reference a script file from `files/scripts/`:

```yaml
- type: script
  scripts:
    - example.sh
```

### Copying files into the image

Uncomment/add the `files` module and place files under `files/system/` mirroring the target path:

```yaml
- type: files
  files:
    - source: system
      destination: /
```

### Adding system Flatpaks

```yaml
- type: default-flatpaks
  configurations:
    - scope: system
      install:
        - com.example.App
```

## CI/CD Notes

- Builds run automatically at **06:00 UTC daily** (20 min after upstream ublue images rebuild).
- Changes to `*.md` files do **not** trigger a rebuild.
- Only one build runs at a time per branch; a new push cancels the in-progress build.
- `maximize_build_space: true` is set — do not remove it, the image is large.
- Image signing requires `SIGNING_SECRET` to be set in the repository secrets.

## Runtime Package Lists

Some packages are installed at runtime rather than baked into the image, so updates don't require a rebase:

- **Brewfile** — [files/system/usr/share/bluefin-lynx/Brewfile](files/system/usr/share/bluefin-lynx/Brewfile), baked to `/usr/share/bluefin-lynx/Brewfile`. Install: `brew bundle --file=/usr/share/bluefin-lynx/Brewfile`. Supports `brew`, `cask`, `tap`, and `flatpak` entries (flatpak support added in Homebrew 5.0.4, Linux-only).

Flatpaks listed under `default-flatpaks` in [recipes/recipe.yml](recipes/recipe.yml) are reinstalled on every rebase; the Brewfile gives manual control instead.

## Applying a New Image to the Running System

After a build is published, rebase the running system:

```bash
# Switch to the signed image (first time: use ostree-unverified-registry, reboot, then this)
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/hcastilho/bluefin-lynx:latest
systemctl reboot
```

## Verifying Image Signatures

```bash
cosign verify --key cosign.pub ghcr.io/hcastilho/bluefin-lynx:latest
```

## BlueBuild Reference

- Module docs: <https://blue-build.org/reference/modules/>
- Recipe schema: <https://schema.blue-build.org/recipe-v1.json>
- Setup guide: <https://blue-build.org/how-to/setup/>
