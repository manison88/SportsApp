#!/usr/bin/env bash
# Pushes out/ to the orphan branch ci-results so results can be pulled without artifact downloads.
set -u
git config user.name "witness-ci"
git config user.email "witness-ci@users.noreply.github.com"
echo "run=${RUN_ID} outcome=${RUN_OUTCOME} sha=$(git rev-parse --short HEAD) time=$(date -u +%FT%TZ)" > out/RUN.txt
W=$(mktemp -d)/ci
if git fetch -q origin ci-results 2>/dev/null; then
  git worktree add -q -B ci-results "$W" origin/ci-results
else
  git worktree add -q --detach "$W"
  (cd "$W" && git checkout -q --orphan ci-results)
fi
cd "$W"
git rm -rqf . > /dev/null 2>&1 || true
cp -R "$GITHUB_WORKSPACE/out/." .
git add -A
git commit -qm "CI results for run ${RUN_ID} (${RUN_OUTCOME})" || true
git push -qf origin ci-results
