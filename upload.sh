#!/usr/bin/env bash

# Use "make upload" to invoke this script

ROCK_VERSION=$1-1
LR_API_KEY=$2
#LR_API_KEY=INfSIgkuArccxH9zq9M7enqackTiYtgRM6c9l6Y4


ROCK_FILE=lua-resty-aws-$ROCK_VERSION.src.rock
ROCKSPEC_FILE=lua-resty-aws-$ROCK_VERSION.rockspec

if [ "$ROCK_VERSION" == "-1" ]; then
  echo "First argument (version) is missing."
  exit 1
fi
if [ "$LR_API_KEY" == "" ]; then
  echo "Second argument (LuaRocks api-key) is missing."
  exit 1
fi
if [ ! -f "$ROCKSPEC_FILE" ]; then
  echo "File '$ROCKSPEC_FILE' not found"
  exit 1
fi
if [ ! -f "$ROCK_FILE" ]; then
  echo "File '$ROCK_FILE' not found"
  exit 1
fi

echo "Uploading $ROCKSPEC_FILE..."
curl -f -k -L --silent \
  --user-agent "lua-resty-aws upload script via curl" \
  --form "rockspec_file=@$ROCKSPEC_FILE" \
  --connect-timeout 30 \
  "https://luarocks.org/api/1/$LR_API_KEY/upload" \
  -o "./upload1.json"

LR_ROCK_VERSION_ID=$(jq .version.id < upload1.json)
jq < upload1.json
rm ./upload1.json
echo "Rock ID: $LR_ROCK_VERSION_ID"

echo "Uploading $ROCK_FILE..."
curl -f -k -L --silent \
  --user-agent "lua-resty-aws upload script via curl" \
  --form "rock_file=@$ROCK_FILE" \
  --connect-timeout 30 \
  "https://luarocks.org/api/1/$LR_API_KEY/upload_rock/$LR_ROCK_VERSION_ID" \
  -o "./upload2.json"

jq < upload2.json
rm ./upload2.json
