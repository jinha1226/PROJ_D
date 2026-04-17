#!/bin/bash
if [ -z "$1" ]; then
  echo "Usage: ./rollback.sh <commit-hash>"
  echo "Example: ./rollback.sh 5e70fb9"
  exit 1
fi
COMMIT=$1

# 1. Delete all tracked files except .gitignore and assets/ulpc/
git ls-files -z | grep -zv '^\.gitignore$' | grep -zv '^assets/ulpc/' | xargs -0 rm -f

# 2. Restore files from target commit (except .gitignore and ulpc)
git checkout "$COMMIT" -- . ':!.gitignore' ':!assets/ulpc/'

# 3. Stage everything (deletions + restored files)
git add -A
git commit -m "test: deploy $COMMIT tree (clean)"
git push
