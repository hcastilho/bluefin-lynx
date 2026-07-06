#!/usr/bin/env bash
set -oue pipefail

# Pre-create the 1Password system groups at fixed gids so that when the
# 1password / 1password-cli RPMs install (in a subsequent module), their
# postinstall `groupadd` sees the groups already exist and skips
# creation. The RPM postinstalls then `chgrp NAME <file>` — which
# resolves to our pinned gid, so ostree stores the file with a numeric
# gid that matches what systemd-sysusers pins on the target
# (see 10-onepassword-groups.conf).
#
# 945 matches an existing /etc/group entry on the maintainer's target
# host; the other two are picked adjacent in the reserved-system range.
# If any of these gids get claimed by another package at build time,
# groupadd will fail loudly and this script exits non-zero — pick new
# numbers rather than trying to auto-fallback.
groupadd -g 943 onepassword
groupadd -g 944 onepassword-mcp
groupadd -g 945 onepassword-cli
