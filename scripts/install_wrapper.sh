#!/bin/bash
set -eo pipefail

cat <<'EOF' > "$DESMUME/DeSmuME_dev.exe"
#!/usr/bin/env bash
exec desmume "$@"
EOF

chmod +x "$DESMUME/DeSmuME_dev.exe"
