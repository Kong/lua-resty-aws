#!/usr/bin/env bash

# This can be run from the Makefile.

# script to update the AWS SDK from it's source repository (the JS sdk)
# It will convert the service descriptions of the specified SDK version
# (see SDK_VERSION_TAG) into Lua modules and generate a rockspec.

SDK_VERSION_TAG=v2.1353.0

# ----------- nothing to customize below -----------
TARGET=./src/resty/aws/raw-api
SOURCE=./delete-me
TFILE=$(mktemp)
set -e
pushd "$(dirname "$(realpath "$0")")" > /dev/null


# clone repo at requested version
if [ -d $SOURCE ]; then
  echo "directory $SOURCE already exists, delete before updating"
  exit 1
fi
git clone --branch=$SDK_VERSION_TAG --depth=1 https://github.com/aws/aws-sdk-js.git $SOURCE


# get a list of API files
file_list=()
pushd $SOURCE/apis/ > /dev/null
for file_name in `ls -v *.normal.json` ; do
  file_list+=("${file_name%.normal.json}")
done
popd > /dev/null

# remove existing files
echo "removing: $TARGET"
rm -rf "$TARGET"
echo "creating: $TARGET"
mkdir -p "$TARGET"

# Create destination file in Lua format with hardcoded json in there
echo "adding: $TARGET/_README.md"
cat <<EOF > $TARGET/_README.md
# WARNING

Everything in this directory is generated, do not modify, changes will be lost.

To regenerate use the update script in the top directory of this repo.
EOF


# create TOC
FILENAME=$TARGET/table_of_contents.lua
echo "adding: $FILENAME"
echo "return {" >> $FILENAME
for f in "${file_list[@]}"; do
  source_file=$SOURCE/apis/$f.normal.json
  service_id=$(jq -r '.metadata.serviceId' $source_file | tr -d ' ')
  # replace . with - since . can't be in a Lua module name
  f=${f//./-}
  echo '  "'"$service_id:$f"'",' >> $FILENAME
done
echo "}" >> $FILENAME


# copy region config file
FILENAME=$TARGET/region_config_data.lua
echo "adding: $FILENAME"
echo 'local decode = require("cjson").new().decode' >> "$FILENAME"
echo "return assert(decode([===[" >> "$FILENAME"
cat $SOURCE/lib/region_config_data.json >> "$FILENAME"
echo "" >> "$FILENAME"
echo "]===]))" >> "$FILENAME"

# Copy the individual API files
for f in "${file_list[@]}"; do
  source_file=$SOURCE/apis/$f.normal.json
  # remove example keys from documentation to prevent security reports from being triggered
  jq 'walk( if (type == "object") and has("documentation") and (.documentation|contains("wJalrXUtnFEMI")) then del(.documentation) else . end )' "$source_file" >| "$TFILE"
  mv -f "$TFILE" "$source_file"; touch "$TFILE"
  # replace . with - since . can't be in a Lua module name
  target_file=$TARGET/${f//./-}.lua
  echo "adding: $target_file"
  echo 'local decode = require("cjson").new().decode' >> "$target_file"
  echo 'return assert(decode([===[' >> "$target_file"
  cat "$source_file" >> "$target_file"
  echo "" >> "$target_file"
  echo "]===]))" >> "$target_file"
done

# update the rockspec
echo "writing rockspec file"
rockspec=lua-resty-aws-dev-1.rockspec
if [ -f $rockspec ]; then
  rm $rockspec
fi

echo "-- do not edit this file, it is generated and will be overwritten" >> $rockspec
while IFS= read -r line; do
  echo "$line" >> $rockspec
  if [[ "$line" =~ "--START-MARKER--" ]]; then
    break
  fi
done < lua-resty-aws-dev-1.rockspec.template

for f in "${file_list[@]}"; do
  target_file=${f//./-}
  echo "    [\"resty.aws.raw-api.$target_file\"] = \"src/resty/aws/raw-api/$target_file.lua\"," >> $rockspec
done

foundmarker=false
while IFS= read -r line; do
  if [[ "$line" =~ "--END-MARKER--" ]]; then
    foundmarker=true
  fi
  if [[ $foundmarker == true ]]; then
    echo "$line" >> $rockspec
  fi
done < lua-resty-aws-dev-1.rockspec.template

rm -rf $SOURCE
popd > /dev/null

echo "Update complete"
