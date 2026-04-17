#!/bin/bash
if [ -z "$1" ]; then
  echo "Usage: ./rollback.sh <commit-hash>"
  echo "Example: ./rollback.sh 5e70fb9"
  exit 1
fi
COMMIT=$1
git checkout "$COMMIT" -- . ':!.gitignore' ':!assets/ulpc/'
git add -A
git commit -m "test: deploy $COMMIT tree"
git push
