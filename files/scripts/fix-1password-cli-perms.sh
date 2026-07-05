#!/usr/bin/env bash
set -oue pipefail

# The 1password-cli RPM lands /usr/bin/op setgid to the wrong group on
# rpm-ostree image builds (observed: root:hcastilho-numeric-gid instead of
# root:onepassword-cli). The desktop app's IPC handshake reads the peer's
# effective gid via SO_PEERCRED and rejects anything not in the
# `onepassword-cli` group — so `op` fails with "connection reset" until the
# setgid group is corrected.
chgrp onepassword-cli /usr/bin/op
chmod 2755 /usr/bin/op
