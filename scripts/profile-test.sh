#!/usr/bin/env bash
set -euo pipefail
./tests/test.sh
./tests/gate_self_test.sh
