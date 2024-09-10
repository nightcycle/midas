#!/bin/sh

set -e

# if [ ! -d node_modules ]; then
npm install
# fi

# if [ ! -d node_modules/.luau-aliases ]; then
npm run prepare
# fi

# for each directory under node_modules, check for a directory named ".vscode", if it exists remove it
for dir in $(find "node_modules" -type d -name ".vscode")
do
	echo "removing $dir"
	rm -rf "$dir"
done

for dir in $(find "node_modules" -type d -name "types")
do
	echo "removing $dir"
	rm -rf "$dir"
done
