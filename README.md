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

---

### TLS and certificate failures

The http client defaults to tls name verification. For this to work, the CA store must be set.
With OpenResty this is done through the [`lua_ssl_trusted_certificate`](https://github.com/openresty/lua-nginx-module#lua_ssl_trusted_certificate)
directive. However; the compatibility module used, [`lua-resty-luasocket`](https://github.com/Tieske/lua-resty-luasocket), cannot automatically
read that setting, hence you have to set it manually, see [the docs](https://tieske.github.io/lua-resty-luasocket/modules/resty.luasocket.html#get_luasec_defaults).

---

### Global settings

This library depends on global settings. Especially the core services for authentication
and metadata. Many of those can (also) be specified as environment variables.  Environment
variables can only be accessed during the OpenResty `init` phase.  Thus, to ensure correct
configuration from environment variables, the `resty.aws.config` module must be required on
the top-level of the module using this library:

```Lua
local aws_config = require("resty.aws.config")
```

The `.global` property of the `aws_config` variable can then be used as the global
configuration.  Note that when `.global` is first accessed, automatic region detection
through the AWS metadata service is performed.  Thus, it is not advisable to access
it on the module level unless to avoid startup delays in non-AWS environment, caused by
the requests to the metadata service timing out.

---

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

### Troubleshooting

MacOS has a known issue that the libexpat header file 'expat_config.h' is missing. If you run into that issue, install libexpat manually (eg. `brew install libexpat`). And then include the libexpat location when installing;
        luarocks install lua-resty-aws EXPAT_DIR=/path/to/expat

Details: https://github.com/lunarmodules/luaexpat/issues/32

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

Copyright: (c) 2020-2024 Kong, Inc.

Author: Thijs Schreijer

License: [Apache 2.0](https://github.com/Kong/lua-resty-aws/blob/main/LICENSE)

---

## History

Versioning is strictly based on [Semantic Versioning](https://semver.org/)

Release process:

1. create a release branch `VERSION=x.y.z && git checkout main && git pull && git checkout -b release/$VERSION`
1. update the changelog below
1. run `make clean && make dev && make test && make docs`
1. commit as `release x.y.z`
1. push the branch, create a PR and get it merged.
1. tag the release commit with the version `VERSION=x.y.z && git checkout main && git pull && git tag $VERSION`
1. push the tag
1. run `VERSION=x.y.z make pack`
1. test the created `.rock` file `VERSION=x.y.z && luarocks install lua-resty-aws-$VERSION-1.src.rock`
1. upload using: `VERSION=x.y.z APIKEY=abc... make upload`
1. test installing the rock from LuaRocks


### 1.4.1 (19-Apr-2024)

- fix: patch expanduser function to be more friendly to OpenResty environment
  [111](https://github.com/Kong/lua-resty-aws/pull/111)

### 1.4.0 (20-Mar-2024)

- fix: aws configuration cannot be loaded due to pl.path cannot resolve the path started with ~
  [94](https://github.com/Kong/lua-resty-aws/pull/94)
- fix: fix the bug of missing boolean type with a value of false in the generated request body
  [100](https://github.com/Kong/lua-resty-aws/pull/100)
- security: remove the documentation entry that contains a sample access key from AWS SDK. This
  avoids false postive vulnerability report.
  [102](https://github.com/Kong/lua-resty-aws/pull/102)
- feat: container credential provider now supports using auth token defined in
  AWS_CONTAINER_AUTHORIZATION_TOKEN and AWS_CONTAINER_AUTHORIZATION_TOKEN_FILE.
  [107](https://github.com/Kong/lua-resty-aws/pull/107)
- fix: operations without inputs (eg, some S3 ones) would cause errors to be thrown
  [108](https://github.com/Kong/lua-resty-aws/pull/108)

### 1.3.6 (25-Dec-2023)

- fix: validator failure for some of the field types
  [95](https://github.com/Kong/lua-resty-aws/pull/95)

### 1.3.5 (19-Sep-2023)

- fix: lazily initialize structures to avoid c-boundary errors on require
  [87](https://github.com/Kong/lua-resty-aws/pull/87)

### 1.3.4 (13-Sep-2023)

- fix: remove more module-level uses of config.global
  [83](https://github.com/Kong/lua-resty-aws/pull/83)

### 1.3.3 (13-Sep-2023)

- fix: don't invoke region detection code on the module toplevel and advise against trying to.
  [81](https://github.com/Kong/lua-resty-aws/pull/81)

### 1.3.2 (13-Sep-2023)

- fix: unsigned request should support network related config option
  [79](https://github.com/Kong/lua-resty-aws/pull/79)

### 1.3.1 (17-Aug-2023)

- fix: fix v4 signing request should correctly canonicalized query table as well
  [76](https://github.com/Kong/lua-resty-aws/pull/76)

### 1.3.0 (15-Aug-2023)

- fix: fix AWS_CONTAINER_CREDENTIALS_FULL_URI parsing.
  [#65](https://github.com/Kong/lua-resty-aws/pull/65)
- feat: support configure timeout on service request.
  [#67](https://github.com/Kong/lua-resty-aws/pull/67)
- feat: support configure keepalive idle time on service request connection.
  [#67](https://github.com/Kong/lua-resty-aws/pull/67)
- feat: support configure ssl verify on service request.
  [#67](https://github.com/Kong/lua-resty-aws/pull/67)
- feat: add http/https proxy support for service request
  [#69](https://github.com/Kong/lua-resty-aws/pull/69)
- fix: fix proxy-related global config var name to lowercase.
  [#70](https://github.com/Kong/lua-resty-aws/pull/70)
- feat: EC2 metadata credential provider support IMDSv2
  [#71](https://github.com/Kong/lua-resty-aws/pull/71)

### 1.2.3 (20-Jul-2023)

- fix: fix assumeRole function name on STS.
  [#59](https://github.com/Kong/lua-resty-aws/pull/59)
- fix: fix STS regional endpoint injection in build_request
  [#62](https://github.com/Kong/lua-resty-aws/pull/62)
- fix: replace deprecated pl.xml with luaexpat; fix STS assume role logic.
  [#61](https://github.com/Kong/lua-resty-aws/pull/61)

### 1.2.2 (2-May-2023)

- fix: add the SharedFileCredentials into rockspec so it can be packed and used correctly.
  [#53](https://github.com/Kong/lua-resty-aws/pull/53)
- fix: the field `idempotencyToken` should be allowed and remain unvalidated as an opaque string.
  [#52](https://github.com/Kong/lua-resty-aws/pull/52)

### 1.2.1 (24-Apr-2023)

- fix: fix the rds signer cannot be used in init phase.
  [#50](https://github.com/Kong/lua-resty-aws/pull/50)

### 1.2.0 (1-Mar-2023)

- **IMPORTANT-IMPORTANT-IMPORTANT** feat: enable TLS name verification. This might
  break if your CA store is not the default system one. See [usage notes](#usage-important).
  [#47](https://github.com/Kong/lua-resty-aws/pull/47)
- fix: STS regional endpoints woudl re-inject the region on every authentication
  (after a token expired), causing bad hostnames to be used
  [#45](https://github.com/Kong/lua-resty-aws/issues/45)
- Feat: add RDS.Signer to generate tokens for RDS DB access
  [#44](https://github.com/Kong/lua-resty-aws/issues/44)

### 1.1.2 (7-Dec-2022)

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
