#!/bin/bash

DIR="$( cd "$( dirname "$0" )" && pwd )"

# Main directory
cd ${DIR}
cd ..
cd ..
ls

# Auth helper
git config --global credential.helper store
echo "https://${GITHUB_TOKEN}:x-oauth-basic@github.com" >> ~/.git-credentials
echo "" >> ~/.git-credentials
git config --global user.email "${GITHUB_EMAIL}"
git config --global user.name "[fun-bots] Build Server"
git remote set-url origin https://${GITHUB_TOKEN}@github.com/Joe91/fun-bots.git


# Check out Branch
git checkout fun-bots-bizzi

# Add files
git add WebUI/languages/DEFAULT.js
git add ext/Shared/Languages/DEFAULT.lua


# Debug
git status

# Check difference otherwise commit and push
git diff-index --quiet HEAD || git commit -m "[AutoUpdate] Default Language"
git push origin fun-bots-bizzi