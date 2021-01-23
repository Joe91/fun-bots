#!/bin/bash

DIR="$( cd "$( dirname "$0" )" && pwd )"

# Auth helper
git config --global credential.helper store
echo https://${GITHUB_TOKEN}:x-oauth-basic@github.com >> ~/.git-credentials
git config --global user.email "build@bizzi.appveyor.com"
git config --global user.name "[fun-bots] Build Server"
git -C ${DIR} remote set-url origin https://${GITHUB_TOKEN}:x-oauth-basic@github.com/Joe91/fun-bots.git

# Debug
echo GitHub-Token: ${GITHUB_TOKEN}
git remote -v

# Check out Branch
#git -C ${DIR} checkout fun-bots-bizzi
git -C ${DIR} checkout -b fun-bots-bizzi origin/fun-bots-bizzi

# Add files
git -C ${DIR} add ../../WebUI/languages/DEFAULT.js
git -C ${DIR} add ../../ext/Shared/Languages/DEFAULT.lua

# Check difference otherwise commit and push
git -C ${DIR} diff-index --quiet HEAD || git -C ${DIR} commit -m "[AutoUpdate] Default Language"
git -C ${DIR} push origin fun-bots-bizzi