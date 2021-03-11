# lua-resty-aws


## Overview

AWS SDK for OpenResty. The SDK is generated from the [original AWS JavaScript
repository details](https://github.com/aws/aws-sdk-js/tree/master/apis).

[The documentation](https://kong.github.io/lua-resty-aws/topics/README.md.html)
will mostly cover the specifics for this library, the actual
[services invoked are documented by AWS](https://docs.aws.amazon.com/AWSJavaScriptSDK/latest/).

For a quick start on how to use this library checkout
[the examples of the AWS class](https://kong.github.io/lua-resty-aws/classes/AWS.html).

---

## Status

This library is under early development. Not everything has been implemented,
and testing is hard since it requires access to AWS resources and not just
regular CI.

---

## Installation

Installation is easiest using LuaRocks:

    luarocks install lua-resty-aws

To install from the git repo:

    git clone https://github.com/Kong/lua-resty-aws.git
    cd lua-resty-aws
    make install

---

## Development

To update the SDK version being used edit the version tag in [`update_api_files.sh`](https://github.com/Kong/lua-resty-aws/blob/main/update_api_files.sh)
and then run:

    make dev

Make sure to run `make dev` to pull in the generated files. Documentation can be
generated using [ldoc](https://github.com/lunarmodules/LDoc) by running:

    make docs

Note that distribution is a little more complex than desired. This is because the
repo does not contain all the json files pulled in from the JS sdk. This in turn
means that `luarocks upload` cannot build a rock from the repo (because it is
incomplete after just being pulled).

To work around this the `make pack` command actually builds a .rock file that
is compatible with LuaRocks. The `make upload` target will upload the generated
rock.

See the detailed release instructions at [History](#history).

---

## Testing

Tests are executed using Busted and LuaCheck:

    busted
    luacheck .

or run

    make test

---

## To do

- Implement the request/response objects (more AWS like, currently Lua modules)
- Implement additional signatures (only V4 currently)
- Implement retries from the global config
- Additional tests for other services

---

## Copyright and license

Copyright: (c) 2020-2021 Kong, Inc.

Author: Thijs Schreijer

License: [Apache 2.0](https://github.com/Kong/lua-resty-aws/blob/main/LICENSE)

---

## History

Versioning is strictly based on [Semantic Versioning](https://semver.org/) (please
note that in the pre-1.0 stage the API is not considered stable and can change at
any time, and in any release, major, minor, and patch)

Release process:

1. update the changelog below
1. generate the docs using `ldoc .`
1. run `make clean`
1. commit, and tag the commit with the version `x.y.z`
1. push the commit and tag
1. run `VERSION=x.y.z make pack`
1. test the create `.rock` file
1. upload using: `VERSION=x.y.z APIKEY=abc... make upload`
1. test installing the rock from LuaRocks

### 0.1 (03-Feb-2021) Initial released version
