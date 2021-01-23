#!/bin/bash

DIR="$( cd "$( dirname "$0" )" && pwd )"

git config --global credential.helper store
echo "https://${GITHUB_TOKEN}@github.com" > "$USERPROFILE\.git-credentials"
git config --global user.email "build@build.fruithost.de"
git config --global user.name "[fun-bots] Build Server"
git clone -q --depth=1 --branch=fun-bots-bizzi https://${GITHUB_TOKEN}:x-oauth-basic@github.com/Joe91/fun-bots.git %LANG_DIR%
git -C ${DIR} remote set-url origin https://${GITHUB_TOKEN}:x-oauth-basic@github.com/Joe91/fun-bots.git
git -C ${DIR} checkout fun-bots-bizzi
git -C ${DIR} add WebUI/languages/DEFAULT.js
git -C ${DIR} add ext/Shared/Languages/DEFAULT.lua
git -C ${DIR} diff-index --quiet HEAD || git -C ${DIR} commit -m "[AutoUpdate] Default Language"
git -C ${DIR} push origin fun-bots-bizzi