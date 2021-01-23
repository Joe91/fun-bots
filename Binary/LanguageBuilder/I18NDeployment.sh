#!/bin/bash

git config --global credential.helper store
echo "https://$($env:GITHUB_LANG_TOKEN)@github.com" > "$env:USERPROFILE\.git-credentials"
git config --global user.email "build@build.fruithost.de"
git config --global user.name "[fun-bots] Build Server"
git clone -q --depth=1 --branch=fun-bots-bizzi https://%GITHUB_LANG_TOKEN%:x-oauth-basic@github.com/Joe91/fun-bots.git %LANG_DIR%
git -C %LANG_DIR% remote set-url origin https://%GITHUB_LANG_TOKEN%:x-oauth-basic@github.com/Joe91/fun-bots.git
git -C %LANG_DIR% checkout fun-bots-bizzi
#cp .\en_US.json %LANG_DIR%\xx_XX.json
#git -C %LANG_DIR% add xx_XX.json
#git -C %LANG_DIR% diff-index --quiet HEAD || git -C %LANG_DIR% commit -m "[AutoUpdate] Default Language (xx_XX.json)"
#git -C %LANG_DIR% push origin fun-bots-bizzi