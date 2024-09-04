#!/bin/sh
set -e
ROJO_CONFIG="dev.project.json"
DARKLUA_CONFIG=".darklua.json"
SOURCEMAP="darklua-sourcemap.json"
MODEL_ROJO_CONFIG="model.project.json"
LSP_SETTINGS=".luau-analyze.json"
# get if any of the arguments were "--serve"
is_serve=false
build_dir="build"
is_wally=false

if [ ! -d node_modules ]; then
    sh scripts/npm-install.sh
fi

for arg in "$@"
do
	if [ "$arg" = "--serve" ]; then
		is_serve=true
		build_dir="serve"
	fi

	if [ "$arg" = "--wally" ]; then
		echo "wally project detected"
		is_wally=true
	fi
done

# create build directory
echo "clearing and making $build_dir"
rm -f $SOURCEMAP
rm -rf $build_dir
mkdir -p $build_dir

echo "copying contents to $build_dir"

cp -r "$ROJO_CONFIG" "$build_dir/$ROJO_CONFIG"
cp -r "$MODEL_ROJO_CONFIG" "$build_dir/$MODEL_ROJO_CONFIG"
cp -r "$DARKLUA_CONFIG" "$build_dir/$DARKLUA_CONFIG"

if [ "$is_wally" = true ]; then
	echo "wally project detected, copying model.project.json to default.project.json"
	cp -r "$MODEL_ROJO_CONFIG" "$build_dir/default.project.json"
	cp -r "wally.toml" "$build_dir/wally.toml"
fi

cp -r "src" "$build_dir/src"
cp -rL "node_modules" "$build_dir/node_modules"
cp -rL "scripts" "$build_dir/scripts"

cp -r "types" "$build_dir/types"
cp -r "lints" "$build_dir/lints"

cp -r "selene.toml" "$build_dir/selene.toml"
cp -r "stylua.toml" "$build_dir/stylua.toml"
cp -r "$LSP_SETTINGS" "$build_dir/$LSP_SETTINGS"

echo "build sourcemap"
rojo sourcemap "$MODEL_ROJO_CONFIG" -o "$SOURCEMAP"

# process files
echo "running stylua"
stylua "$build_dir/src"

# run darklua
if [ "$is_serve" = true ]; then
	echo "running serve darklua"
	rojo sourcemap --watch "$MODEL_ROJO_CONFIG" -o "$SOURCEMAP" &
	darklua process "src" "$build_dir/src" --config "$DARKLUA_CONFIG" -w & 
	darklua process "node_modules" "$build_dir/node_modules" --config "$DARKLUA_CONFIG" -w & 
else
	echo "running build darklua"
	rojo sourcemap "$build_dir/$MODEL_ROJO_CONFIG" -o "$build_dir/$SOURCEMAP"
	darklua process "src" "$build_dir/src" --config "$DARKLUA_CONFIG" --verbose
	darklua process "node_modules" "$build_dir/node_modules" --config "$DARKLUA_CONFIG" --verbose
fi

# final compile
if [ "$is_serve" = true ]; then
	echo "running serve"
	rojo serve "$build_dir/$ROJO_CONFIG"
else
	echo "build rbxl"
	cd "$build_dir"
	rojo build "$ROJO_CONFIG" -o "Package.rbxl"
fi
