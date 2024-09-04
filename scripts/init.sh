#!/bin/sh
set -e
aftman install
sh scripts/download-types.sh
npm i --package-lock-only
sh scripts/npm-install.sh
sh scripts/build.sh "dev.project.json" --serve