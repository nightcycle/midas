#!/bin/sh
set -e

REPO_OWNER=$1
REPO_NAME=$2
REPO_DESC=$3
GOAL_VERSION_STR=$4
ROJO_CONFIG=$5

# remove letters
GOAL_VERSION_STR=$(echo "$GOAL_VERSION_STR" | sed 's/[a-zA-Z]//g')

# read file
wally_toml_contents=$(cat "wally.toml")

# swap out version
goal_version_line="version = \"$GOAL_VERSION_STR\""
target_version_line=$(echo "$wally_toml_contents" | grep -F "version = ")
wally_toml_contents=$(echo "$wally_toml_contents" | awk -v target="$target_version_line" -v goal="$goal_version_line" '{gsub(target, goal)}1')

# swap out name
goal_name_line="name = \"$REPO_OWNER/$REPO_NAME\""
target_name_line=$(echo "$wally_toml_contents" | grep -F "name = ")
wally_toml_contents=$(echo "$wally_toml_contents" | awk -v target="$target_name_line" -v goal="$goal_name_line" '{gsub(target, goal)}1')

# swap out description
goal_desc_line="description = \"$REPO_DESC\""
target_desc_line=$(echo "$wally_toml_contents" | grep -F "description = ")
wally_toml_contents=$(echo "$wally_toml_contents" | awk -v target="$target_desc_line" -v goal="$goal_desc_line" '{gsub(target, goal)}1')

# update file
echo "$wally_toml_contents" > "wally.toml"

# read json file
rojo_config_contents=$(cat "$ROJO_CONFIG")
target_json_name_line=$(echo "$rojo_config_contents" | grep -F "\"name\": ")
goal_json_name_line="  \"name\": \"$REPO_NAME\","
rojo_config_contents=$(echo "$rojo_config_contents" | awk -v target="$target_json_name_line" -v goal="$goal_json_name_line" '{gsub(target, goal)}1')

# update file
echo "$rojo_config_contents" > "$ROJO_CONFIG"
