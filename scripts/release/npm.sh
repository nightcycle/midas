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
package_json_contents=$(cat "package.json")

# swap out version
goal_version_line="\"version\": \"$GOAL_VERSION_STR\","
target_version_line=$(echo "$package_json_contents" | grep -F "\"version\": ")
package_json_contents=$(echo "$package_json_contents" | awk -v target="$target_version_line" -v goal="$goal_version_line" '{gsub(target, goal)}1')

# swap out name
goal_name_line="\"name\": \"@$REPO_OWNER/$REPO_NAME\","
target_name_line=$(echo "$package_json_contents" | grep -F "\"name\": ")
package_json_contents=$(echo "$package_json_contents" | awk -v target="$target_name_line" -v goal="$goal_name_line" '{gsub(target, goal)}1')

# remove the line starting with "url":
package_json_contents=$(echo "$package_json_contents" | sed '/"url":/d')
goal_url_line="\"type\": \"git\",\"url\": \"git+https://github.com/$REPO_OWNER/$REPO_NAME.git\""
target_url_line=$(echo "$package_json_contents" | grep -F "\"type\": \"git\"")
package_json_contents=$(echo "$package_json_contents" | awk -v target="$target_url_line" -v goal="$goal_url_line" '{gsub(target, goal)}1')


# swap out description
goal_desc_line="\"description\": \"$REPO_DESC\","
target_desc_line=$(echo "$package_json_contents" | grep -F "\"description\": ")
package_json_contents=$(echo "$package_json_contents" | awk -v target="$target_desc_line" -v goal="$goal_desc_line" '{gsub(target, goal)}1')

# update file
echo "$package_json_contents" > "package.json"

# read json file
rojo_config_contents=$(cat "$ROJO_CONFIG")
target_json_name_line=$(echo "$rojo_config_contents" | grep -F "\"name\": ")
goal_json_name_line="  \"name\": \"$REPO_NAME\","
rojo_config_contents=$(echo "$rojo_config_contents" | awk -v target="$target_json_name_line" -v goal="$goal_json_name_line" '{gsub(target, goal)}1')

# update file
echo "$rojo_config_contents" > "$ROJO_CONFIG"
