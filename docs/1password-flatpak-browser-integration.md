# 1Password Browser Integration for Flatpak Browsers

The `bling` module in `recipes/recipe.yml` installs 1Password itself — CLI (`op`), SSH agent, desktop app — and pins the setgid gids on the helper binaries `/usr/bin/op` and `/opt/1Password/1Password-BrowserSupport` so the desktop app accepts their connections.

Browser autofill is a separate mechanism, not touched by bling. On first launch the 1Password app detects which browsers are installed on the host and writes a native-messaging manifest per browser into that browser's standard directory (`~/.mozilla/native-messaging-hosts/`, `~/.config/google-chrome/NativeMessagingHosts/`, etc.). Native (non-Flatpak) browsers read those manifests and exec the helper binary directly — no additional setup needed.

**Flatpak browsers need extra setup**, not baked into this image because the required state lives inside each Flatpak's per-user data directory (`~/.var/app/<browser>/`), not in `/usr`.

## The problem

A Flatpak-sandboxed browser can't reach 1Password by default:

1. **Sandbox hides the host manifest.** The desktop app writes native-messaging manifests to `~/.mozilla/native-messaging-hosts/` and `~/.config/<chromium-family>/NativeMessagingHosts/`. Flatpak Firefox's `~` is redirected to `~/.var/app/org.mozilla.firefox/`, so the browser finds no manifest and behaves as if 1Password isn't installed.
2. **Sandbox restricts host binary exec.** Even if the manifest were visible, its `path` field points at `/usr/lib/opt/1Password/1Password-BrowserSupport` — a host binary the sandboxed browser can't `execve` directly.
3. **Even if it did spawn, the child would be inside the sandbox** — restricted access to `/run/user/1000/*.sock` where the desktop app listens, no ability to satisfy the app's peer-credentials attestation.

## The mechanism that works

Portal-mediated host process spawn, via `flatpak-spawn --host` on the `org.freedesktop.Flatpak` D-Bus interface. Two ingredients:

- **A wrapper script** placed inside the browser's Flatpak data dir (e.g. `~/.var/app/org.mozilla.firefox/data/bin/1password-wrapper.sh`) containing roughly `flatpak-spawn --host /usr/lib/opt/1Password/1Password-BrowserSupport "$@"`. A native-messaging manifest inside the browser's Flatpak config dir points at this wrapper instead of the host binary. The browser sees a legitimate manifest, spawns the wrapper, and the wrapper asks the host to spawn the real helper.
- **An entry in `/etc/1password/custom_allowed_browsers`** adding `flatpak-session-helper`. The desktop app inspects the connecting process's `exe` against a compiled-in allowlist of known-good browser names (`firefox`, `chrome`, `chromium`, etc.). When the wrapper spawns via the portal, the process presenting to the app is `flatpak-session-helper`, which isn't on the built-in list — so the app rejects the connection with a peer-credentials error. `custom_allowed_browsers` is the escape hatch for exactly this case.

## Canonical script

[FlyinPancake/1password-flatpak-browser-integration](https://github.com/FlyinPancake/1password-flatpak-browser-integration) — a small shell script that sets up all of the above. Prompts for the Flatpak app ID and handles Firefox + Chromium-family browsers. Run once per browser:

- Firefox: `org.mozilla.firefox`
- Chromium: `org.chromium.Chromium`
- Similar for Brave, Edge, Vivaldi, etc.

Read the script before running — it uses `sudo` (writes to `/etc/1password/`) and grants `--talk-name=org.freedesktop.Flatpak` to the browser sandbox.

## When to re-run

- After installing a new Flatpak browser you want 1Password autofill in.
- After a major 1Password update if the `1Password-BrowserSupport` binary path changes (the wrapper hardcodes the current path).
- After uninstalling and reinstalling a Flatpak browser — its `~/.var/app/<id>/` is wiped, taking the wrapper and manifest with it.

## Requirements

- 1Password desktop app must be *native*, not Flatpak. Satisfied by this image via the `bling` module in `recipes/recipe.yml`.
- Flatpak version supporting `flatpak-spawn --host`. Any current Flatpak on Bluefin qualifies.
