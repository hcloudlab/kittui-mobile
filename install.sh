#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/main.sh
source "$PROJECT_DIR/lib/main.sh"

kml_main "$@"
