#!/bin/bash
exec java -cp "$(dirname -- "${BASH_SOURCE[0]}")/telomere.jar" "$@"
