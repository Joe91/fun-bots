#!/bin/bash
cd /home/jo/Games/vu/client/
exec wine vu.com -gamepath "/home/jo/Games/ea-app/drive_c/Program Files/EA Games/Battlefield 3/" \
  -serverInstancePath "$(winepath -w /home/jo/workspace/VU_Server/)" -server -dedicated -high60 -updateBranch dev \
  > "$(dirname "$0")/vu.log" 2>&1
