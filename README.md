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

Installation will be done using LuaRocks, but is currently not yet available
until a first release is made.

For now run `make install`.

---

## Development

To update the SDK version being used edit the version tag in [`update_api_files.sh`](https://github.com/Kong/lua-resty-aws/blob/main/update_api_files.sh)
and then run `make dev`.

Make sure to run `make dev` to pull in the generated files. Documentation can be
generated using [ldoc](https://github.com/lunarmodules/LDoc) by running `make docs`.

---

## Testing

Tests are executed using `busted`, or run `make test`.

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
2. update the rockspec file
3. generate the docs using `ldoc .`
4. commit and tag the release
5. upload rock to LuaRocks


### 0.1 (xx-xxx-2021) Initial released version
