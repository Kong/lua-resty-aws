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

Not everything has been implemented,
and testing is hard since it requires access to AWS resources and not just
regular CI.

---

## Example

See [the example](https://kong.github.io/lua-resty-aws/classes/AWS.html) in the documentation.

---

## Usage IMPORTANT!!

### `attempt to yield across C-call boundary` error

This typically happens when initializing from within a `require` call.
See [Global settings](#global-settings) below on how to initialize properly.

### Global settings

This library depends on global settings. Escpecially the core services for authentication
and metadata. Many of those can (also) be specified as environment variables.

Hence it is recommended to populate the global confguration object at application start
in the OpenResty `init` phase. Simply add the following line;

```
        local _ = require("resty.aws.config").global
```

This ensures the environment variables can still be read (in the `init` phase). And
the auto-detection of the AWS region will execute.

### EC2 metadata

The endpoint for EC2 metadata can block (until timeout) if the SDK is used on a non-EC2
machine. In that case you might want to set the `AWS_EC2_METADATA_DISABLED` to a value
different from `false` (which is the default).

```
        export AWS_EC2_METADATA_DISABLED=true
```


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

Copyright: (c) 2020-2022 Kong, Inc.

Author: Thijs Schreijer

License: [Apache 2.0](https://github.com/Kong/lua-resty-aws/blob/main/LICENSE)

---

## History

Versioning is strictly based on [Semantic Versioning](https://semver.org/)

Release process:

1. update the changelog below
1. run `make clean && make dev && make test && make docs`
1. commit, and tag the commit with the version `x.y.z`
1. push the commit and tag
1. run `VERSION=x.y.z make pack`
1. test the created `.rock` file
1. upload using: `VERSION=x.y.z APIKEY=abc... make upload`
1. test installing the rock from LuaRocks

### 1.1.2 (5-Dec-2022)

- fix: auto detection scheme and default to tls [#42](https://github.com/Kong/lua-resty-aws/pull/42)

### 1.1.1 (21-Nov-2022)

- fix: port is repeated when port is not standard [#39](https://github.com/Kong/lua-resty-aws/pull/39)

### 1.1.0 (18-Nov-2022)

- fix: template handling of query string [#36](https://github.com/Kong/lua-resty-aws/pull/36)
- fix: blob param should be in raw body [#36](https://github.com/Kong/lua-resty-aws/pull/36)
- feat: support for credential from file [#36](https://github.com/Kong/lua-resty-aws/pull/36)
- fix: escaping for param in uri [#36](https://github.com/Kong/lua-resty-aws/pull/36)
- fix: handling raw body conflict with body param [#36](https://github.com/Kong/lua-resty-aws/pull/36)
- fix: crash when no type check designated [#36](https://github.com/Kong/lua-resty-aws/pull/36)
- fix: support for "headers" location in API template [#36](https://github.com/Kong/lua-resty-aws/pull/36)
- fix: support new API format (bucket in host) for S3 [#36](https://github.com/Kong/lua-resty-aws/pull/36)

### 1.0.1 (20-Oct-2022)

- fix: for some method incorrect URL is generates because of incorrect handling of "+" in URL template
   [#34](https://github.com/Kong/lua-resty-aws/pull/34)

### 1.0.0 (13-Oct-2022)

- fix: `latest` doesn't indicate the most recent service version
   [#28](https://github.com/Kong/lua-resty-aws/pull/28)

### 0.5.5 (26-Sep-2022)

 - fix: variable names for ECS Conatiner Metatdata were missing an '_'
   [#26](https://github.com/Kong/lua-resty-aws/pull/26)

### 0.5.4 (19-Aug-2022)

 - chore: remove error message when no region is found
   during config initialization [#24](https://github.com/Kong/lua-resty-aws/pull/24)

### 0.5.3 (19-Aug-2022)

 - feat: lazy load API modules
   [#23](https://github.com/Kong/lua-resty-aws/pull/23)

### 0.5.2 (12-Jul-2022)

 - fix: relax validation to not validate some generic metadata fields. Encountered
   while trying to use Lambda [#21](https://github.com/Kong/lua-resty-aws/pull/21)
 - fix: better error handling when credential providers fail to load
   [#22](https://github.com/Kong/lua-resty-aws/pull/22)

### 0.5.1 (01-Jun-2022)

 - feat: socket compatibility; overriding luasocket use in phases now returns
   the existing setting

### 0.5.0 (01-Jun-2022)

 - feat: enable use of regional STS endpoints
 - deps: bumped the [lua-resty-http](https://github.com/ledgetech/lua-resty-http)
   dependency to 0.16 to disable the warnings and use the better connection building logic.
 - fix: added `sock:settimeouts` to the socket compatibility layer.
 - feat: implement a config object based on AWS CLI configuration.
   - for most use cases it will now suffice to load the `config` in the `init` phase
     since it caches al predefined environment variables.
   - BREAKING: getting EC2 credentials will now honor AWS_EC2_METADATA_DISABLED.
     Behaviour might change, but is expected to be very rare.
   - BREAKING: The TokenFileWebIdentityCredentials
     will honor the `role_session_name` setting (file or env) as default name.
     Behaviour might change, but is expected to be very rare.


### 0.4.0 (06-Dec-2021)

 - feat: added TokenFileWebIdentityCredentials. This adds default IAM credentials
   to be picked up on EKS. The default AWS instance creates a CredentialProviderChain
   which includes TokenFileWebIdentity. So on EKS it will now pick up container
   based credentials instead of falling back to the underlying (more coarse) EC2
   credentials.
 - fix: for 'query' type calls, add target action and version, which are required
 - fix: allow for unsigned requests for services requiring that (STS)
 - fix: do not validate patterns as regexes are incompatible

### 0.3 (02-Sep-2021)

 - feat: capability to fetch metadata for ECS tasks (EC2 & Fargate), versions 2, 3, and 4
 - feat: capability to fetch IMDS metadata (EC2 & EKS), versions 1, and 2
 - feat: automatic region detection, check the docs for details (utils module)
 - fix: EC2MetadataCredentials no longer reuses the http-client to prevent issues
   with the underlying compatibility layer.

### 0.2 (05-Aug-2021)

 - fix: rockspec, add Penlight dependency
 - fix: add proper json Content-Type header from meta-data
 - fix: use proper signingName for the signature

### 0.1 (03-Feb-2021) Initial released version
