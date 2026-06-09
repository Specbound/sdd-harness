#!/bin/bash
# bootstrap.sh is deprecated — use install.sh instead.
# install.sh is now the single first-time setup entry point.
# All flags are forwarded unchanged.
echo "bootstrap.sh is deprecated. Forwarding to install.sh..." >&2
exec "$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/install.sh" "$@"
