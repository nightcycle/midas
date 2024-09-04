#!/bin/sh
set -e
sh scripts/download-types.sh
sh scripts/build.sh $1
cd "build"
luau-lsp analyze \
	--sourcemap="darklua-sourcemap.json" \
	--ignore="**/Packages/**" \
	--ignore="Packages/**" \
	--ignore="*.spec.luau" \
	--settings=".luau-analyze.json" \
	--definitions="types/globalTypes.d.lua" \
	"src"
selene src