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


# fix hashlib require
echo "fixing hashlib require"
bad_script_path="node_modules/@rbxts/rbxts-hashlib/out/init.lua"
bad_script=$(cat "$bad_script_path")
modified_script=$(echo "$bad_script" | sed 's/local Base64 = require(script.Base64)/local Base64 = require(".\/Base64")/')
echo "$modified_script" > "$bad_script_path"