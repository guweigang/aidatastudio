#!/bin/sh
set -eu
exec sh "$(dirname -- "$0")/run-source-workflow.sh" check frontend
