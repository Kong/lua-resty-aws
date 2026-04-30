local cjson = require "cjson"
local pl_stringx = require "pl.stringx"

describe("operations protocol", function()


  local build_request
  local operation, operation_with_payload_field
  local operation_with_requestUri_params_and_query_param_input
  local operation_with_requestUri_params_without_plus_and_query_param_input
  local config, config_with_payload
  local params, params_with_payload
  local params_with_requestUri_params_and_query_param_input
  local params_with_uri_params
  local snapshot
  local binary_data

  setup(function()
    snapshot = assert:snapshot()
    assert:set_parameter("TableFormatLevel", -1)
    build_request = require("resty.aws.request.build")
  end)


  teardown(function()
    build_request = nil
    package.loaded["resty.aws"] = nil
    package.loaded["resty.aws.request.build"] = nil
    snapshot:revert()
  end)


  before_each(function()
    binary_data = "abcd" --"\00\01\02\03"

    operation = {
      name = "AssumeRole",
      http = {
        method = "POST",
        requestUri = "/{Operation+}/{InstanceId}?nice",
      },
      input = {
        type = "structure",
        locationName = "mainXmlElement",  -- only for rest-xml protocol
        xmlNamespace = {                  -- only for rest-xml protocol
          uri = "cool-name-space"
        },
        required = {
          "RoleArn",
          "RoleSessionName"
        },
        members = {
          -- uri location
          InstanceId = {
            type = "string",
            location = "uri",
            locationName = "InstanceId"
          },
          Operation = {
            type = "string",
            location = "uri",
            locationName = "Operation"
          },
          RawBody = {
            type = "blob",
          },
          -- querystring location
          UserId = {
            type = "string",
            location = "querystring",
            locationName = "UserId"
          },
          -- header location
          Token = {
            type = "string",
            location = "header",
            locationName = "X-Sooper-Secret"
          },
          -- members without location
          RoleArn = {
            type = "string",
          },
          RoleSessionName = {
            type = "string",
          },
          BinaryData = {
            type = "blob",
          },
          subStructure = {
            locationName = "someSubStructure",
            type = "structure",
            members = {
              hello = {
                type = "string",
              },
              world = {
                type = "string",
              },
            }
          },
          subList = {
            type = "list",
            member = {
              type = "integer",
              locationName = "listELement"
            }
          }
        }
      }
    }

    operation_with_payload_field = {
      name = "PutObject",
      http = {
        method = "PUT",
        requestUri = "/{Bucket}/{Key+}"
      },
      input = {
        type = "structure",
        required = {
          "Bucket",
          "Key"
        },
        members = {
          Bucket = {
            type = "string",
            location = "uri",
            locationName = "Bucket"
          },
          Key = {
            type = "string",
            location = "uri",
            locationName = "Key"
          },
          Body = {
            type = "blob",
          },
        },
        payload = "Body"
      },
    }

    operation_with_requestUri_params_and_query_param_input = {
      name = "PutObject",
      http = {
        method = "PUT",
        requestUri = "/{Bucket}/{Key+}?testparam=testparamvalue"
      },
      input = {
        type = "structure",
        required = {
          "Bucket",
          "Key"
        },
        members = {
          TestMember = {
            type = "string",
          },
          Bucket = {
            type = "string",
            location = "uri",
            locationName = "Bucket"
          },
          Key = {
            type = "string",
            location = "uri",
            locationName = "Key"
          },
        },
      },
    }

    operation_with_requestUri_params_without_plus_and_query_param_input = {
      name = "PutObject",
      http = {
        method = "PUT",
        requestUri = "/{Bucket}/{Key}?testparam=testparamvalue"
      },
      input = {
        type = "structure",
        required = {
          "Bucket",
          "Key"
        },
        members = {
          TestMember = {
            type = "string",
          },
          Bucket = {
            type = "string",
            location = "uri",
            locationName = "Bucket"
          },
          Key = {
            type = "string",
            location = "uri",
            locationName = "Key"
          },
        },
      },
    }

    config = {
      apiVersion = "2011-06-15",
      --endpointPrefix = "sts",
      signingName = "sts",
      globalEndpoint = "sts.amazonaws.com",
      --protocol = "query",
      serviceAbbreviation = "AWS STS",
      serviceFullName = "AWS Security Token Service",
      serviceId = "STS",
      signatureVersion = "v4",
      uid = "sts-2011-06-15",
      xmlNamespace = "https://sts.amazonaws.com/doc/2011-06-15/"
    }

    config_with_payload = {
      apiVersion = "2006-03-01",
      signingName = "s3",
      globalEndpoint = "s3.amazonaws.com",
      --protocol = "query",
      serviceAbbreviation = "AWS S3",
      serviceFullName = "AWS Object Storage",
      serviceId = "S3",
      signatureVersion = "v4",
      uid = "s3-2006-03-01",
      xmlNamespace = "https://s3.amazonaws.com/doc/2006-03-01/"
    }

    params = {
      RoleArn = "hello",
      RoleSessionName = "world",
      InstanceId = "42",
      Operation = "hello world",
      UserId = "Arthur Dent",
      Token = "towel",
      subStructure = {
        hello = "the default hello thinghy",
        world = "the default world thinghy"
      },
      subList = { 1, 2 ,3, },
      BinaryData = binary_data,
    }

    params_with_payload = {
      Bucket = "hello",
      Key = "world",
      Body = binary_data,
    }

    params_with_requestUri_params_and_query_param_input = {
      Bucket = "hello",
      Key = "world",
      TestMember = "testvalue",
    }

    params_with_uri_params = {
      Bucket = "hello world",
      Key = "test/abc",
      TestMember = "testvalue",
    }

  end)


  it("errors on a bad protocol", function()

    config.protocol = "shake hands"

    assert.has.error(function()
      build_request(operation, config, params)
    end, "Bad config, field protocol is invalid, got: 'shake hands'")
  end)


  it("query: params go into query table, target action+version added", function()

    config.protocol = "query"

    local request = build_request(operation, config, params)
    assert.same({
      headers = {
        ["X-Sooper-Secret"] = "towel",
        ["X-Amz-Target"] = "sts.AssumeRole",
        ["Host"] = "sts.amazonaws.com",
      },
      method = 'POST',
      path = '/hello%20world/42',
      host = 'sts.amazonaws.com',
      port = 443,
      query = {
        RoleArn = 'hello',
        RoleSessionName = 'world',
        UserId = "Arthur Dent",
        Action = "AssumeRole",
        Version = "2011-06-15",
        nice = '',
        BinaryData = binary_data,
        ["someSubStructure.hello"] = "the default hello thinghy",
        ["someSubStructure.world"] = "the default world thinghy",
        ["subList.listELement.1"] = "1",
        ["subList.listELement.2"] = "2",
        ["subList.listELement.3"] = "3",
      }
    }, request)
  end)

  it("query: undefined location params go into query table, with requestUri query params added", function ()
    config_with_payload.protocol = "query"

    local request = build_request(operation_with_requestUri_params_and_query_param_input,
                                  config_with_payload, params_with_requestUri_params_and_query_param_input)
    assert.same({
      headers = {
        ["X-Amz-Target"] = "s3.PutObject",
        ["Host"] = "s3.amazonaws.com",
      },
      method = 'PUT',
      path = '/hello/world',
      host = 's3.amazonaws.com',
      port = 443,
      query = {
        Action = "PutObject",
        Version = "2006-03-01",
        testparam = "testparamvalue",
        TestMember = "testvalue",
      }
    }, request)
  end)

  it("query: correctly escape URI location params with plus sign", function ()
    config_with_payload.protocol = "query"

    local request = build_request(operation_with_requestUri_params_and_query_param_input,
                                  config_with_payload, params_with_uri_params)
    assert.same({
      headers = {
        ["X-Amz-Target"] = "s3.PutObject",
        ["Host"] = "s3.amazonaws.com",
      },
      method = 'PUT',
      path = '/hello%20world/test/abc',
      host = 's3.amazonaws.com',
      port = 443,
      query = {
        Action = "PutObject",
        Version = "2006-03-01",
        testparam = "testparamvalue",
        TestMember = "testvalue",
      }
    }, request)
  end)

  it("query: correctly escape URI location params without plus sign", function ()
    config_with_payload.protocol = "query"

    local request = build_request(operation_with_requestUri_params_without_plus_and_query_param_input,
                                  config_with_payload, params_with_uri_params)
    assert.same({
      headers = {
        ["X-Amz-Target"] = "s3.PutObject",
        ["Host"] = "s3.amazonaws.com",
      },
      method = 'PUT',
      path = '/hello%20world/test%2Fabc',
      host = 's3.amazonaws.com',
      port = 443,
      query = {
        Action = "PutObject",
        Version = "2006-03-01",
        testparam = "testparamvalue",
        TestMember = "testvalue",
      }
    }, request)
  end)


  it("rest-json: querystring, uri, header and body params", function()

    config.protocol = "rest-json"

    local request = build_request(operation, config, params)
    if request and request.body then
      -- cannot reliably compare non-canonicalized json, so decode to Lua table
      request.body = assert(cjson.decode(request.body))
    end

    assert.same({
      headers = {
        ["X-Sooper-Secret"] = "towel",
        ["Content-Length"] = 172,
        ["Content-Type"] = "application/x-amz-json-1.0",
        ["X-Amz-Target"] = "sts.AssumeRole",
        ["Host"] = "sts.amazonaws.com",
      },
      method = 'POST',
      path = '/hello%20world/42',
      host = 'sts.amazonaws.com',
      port = 443,
      body = {
        subStructure = {
          hello = "the default hello thinghy",
          world = "the default world thinghy",
        },
        subList = { 1,2,3 },
        RoleArn = "hello",
        RoleSessionName = "world",
        BinaryData = binary_data,
      },
      query = {
        UserId = "Arthur Dent",
        nice = '',
      },
    }, request)
  end)


  it("json: querystring, uri, header and body params", function()

    config.protocol = "json"

    local request = build_request(operation, config, params)
    if request and request.body then
      -- cannot reliably compare non-canonicalized json, so decode to Lua table
      request.body = assert(cjson.decode(request.body))
    end

    assert.same({
      headers = {
        ["X-Sooper-Secret"] = "towel",
        ["Content-Length"] = 172,
        ["Content-Type"] = "application/x-amz-json-1.0",
        ["X-Amz-Target"] = "sts.AssumeRole",
        ["Host"] = "sts.amazonaws.com",
      },
      method = 'POST',
      path = '/hello%20world/42',
      host = 'sts.amazonaws.com',
      port = 443,
      body = {
        subStructure = {
          hello = "the default hello thinghy",
          world = "the default world thinghy",
        },
        subList = { 1,2,3 },
        RoleArn = "hello",
        RoleSessionName = "world",
        BinaryData = binary_data,
      },
      query = {
        UserId = "Arthur Dent",
        nice = '',
      }
    }, request)
  end)

  it("json: querystring, uri, header and body params, with payload field", function()

    config_with_payload.protocol = "json"

    local request = build_request(operation_with_payload_field, config_with_payload, params_with_payload)

    assert.same({
      headers = {
        ["Content-Length"] = 4,
        ["X-Amz-Target"] = "s3.PutObject",
        ["Host"] = "s3.amazonaws.com",
      },
      method = 'PUT',
      path = '/hello/world',
      host = 's3.amazonaws.com',
      port = 443,
      body = binary_data,
      query = {},
    }, request)
  end)


  it("rest-xml: querystring, uri, header and body params", function()

    config.protocol = "rest-xml"

    local request = build_request(operation, config, params)
    if request and request.body then
      -- cannot reliably compare non-canonicalized json, so decode to Lua table
      local body_lines = pl_stringx.splitlines(request.body)
      for i, line in ipairs(body_lines) do
        body_lines[i] = pl_stringx.strip(line, ' ')
      end
      request.body = assert(require("pl.xml").parse(table.concat(body_lines, "")))
      local to_lua = function(t)
        -- convert LOM to comparable Lua table
        for i, v in ipairs(t) do
          if type(v) == "table" and v.tag then
            t[v.tag] = v
            v.tag = nil
            t[i] = nil
            if type(v.attr) == "table" and not next(v.attr) then
              -- delete empty attr table
              v.attr = nil
            end
          end
        end
      end
      to_lua(request.body)
      to_lua(request.body.someSubStructure)
    end

    assert.same({
      headers = {
        ["X-Sooper-Secret"] = "towel",
        ["Content-Length"] = 456,
        ["Content-Type"] = "application/xml",
        ["X-Amz-Target"] = "sts.AssumeRole",
        ["Host"] = "sts.amazonaws.com",
      },
      method = 'POST',
      path = '/hello%20world/42',
      host = 'sts.amazonaws.com',
      port = 443,
      body = {
        RoleArn = {
          [1] = 'hello' },
        RoleSessionName = {
          [1] = 'world' },
        BinaryData = {
          [1] = binary_data },
        attr = {
          [1] = 'xmlns',
          xmlns = 'cool-name-space' },
        someSubStructure = {
          hello = {
            [1] = 'the default hello thinghy' },
          world = {
            [1] = 'the default world thinghy' } },
        subList = {
          [1] = {
            [1] = '1',
            attr = {},
            tag = 'listELement' },
          [2] = {
            [1] = '2',
            attr = {},
            tag = 'listELement' },
          [3] = {
            [1] = '3',
            attr = {},
            tag = 'listELement' } },
        tag = 'mainXmlElement' },
      query = {
        UserId = "Arthur Dent",
        nice = '',
      }
    }, request)
  end)


  it("ec2: querystring, uri, header and body params", function()

    config.protocol = "ec2"

    local request = build_request(operation, config, params)

    -- body is order-insensitive (pairs() ordering); parse and compare as table
    local body_len = #request.body
    local function parse_body(s)
      local t = {}
      for kv in s:gmatch("[^&]+") do
        local k, v = kv:match("^([^=]*)=(.*)$")
        t[ngx.unescape_uri(k)] = ngx.unescape_uri(v)
      end
      return t
    end
    local parsed_body = parse_body(request.body)
    request.body = nil
    assert.equal(body_len, request.headers["Content-Length"])
    request.headers["Content-Length"] = nil

    assert.same({
      Action = "AssumeRole",
      Version = "2011-06-15",
      RoleArn = "hello",
      RoleSessionName = "world",
      BinaryData = binary_data,
      ["someSubStructure.hello"] = "the default hello thinghy",
      ["someSubStructure.world"] = "the default world thinghy",
      ["listELement.1"] = "1",
      ["listELement.2"] = "2",
      ["listELement.3"] = "3",
    }, parsed_body)

    assert.same({
      headers = {
        ["X-Sooper-Secret"] = "towel",
        ["Content-Type"] = "application/x-www-form-urlencoded",
        ["X-Amz-Target"] = "sts.AssumeRole",
        ["Host"] = "sts.amazonaws.com",
      },
      method = 'POST',
      path = '/hello%20world/42',
      host = 'sts.amazonaws.com',
      port = 443,
      query = {
        UserId = "Arthur Dent",
        nice = '',
      },
    }, request)
  end)


  it("ec2: nested struct-list with nested list (Filters-style)", function()
    local op = {
      name = "DescribeInstances",
      http = { method = "POST", requestUri = "/" },
      input = {
        type = "structure",
        members = {
          Filters = {
            type = "list",
            member = {
              locationName = "Filter",
              type = "structure",
              members = {
                Name = { type = "string" },
                Values = {
                  type = "list",
                  member = {
                    locationName = "Value",
                    type = "string",
                  },
                },
              },
            },
          },
        },
      },
    }
    local cfg = {
      apiVersion = "2016-11-15",
      globalEndpoint = "ec2.amazonaws.com",
      protocol = "ec2",
      signatureVersion = "v4",
    }
    local p = {
      Filters = {
        { Name = "instance-state-name", Values = { "running", "stopped" } },
        { Name = "tag:Env",              Values = { "prod" } },
      },
    }

    local request = build_request(op, cfg, p)
    local parsed = {}
    for kv in request.body:gmatch("[^&]+") do
      local k, v = kv:match("^([^=]*)=(.*)$")
      parsed[ngx.unescape_uri(k)] = ngx.unescape_uri(v)
    end

    assert.same({
      Action = "DescribeInstances",
      Version = "2016-11-15",
      ["Filter.1.Name"]    = "instance-state-name",
      ["Filter.1.Value.1"] = "running",
      ["Filter.1.Value.2"] = "stopped",
      ["Filter.2.Name"]    = "tag:Env",
      ["Filter.2.Value.1"] = "prod",
    }, parsed)
    assert.equal("application/x-www-form-urlencoded", request.headers["Content-Type"])
  end)


  it("ec2: empty list emits no entries", function()
    config.protocol = "ec2"
    params.subList = {}

    local request = build_request(operation, config, params)
    for kv in request.body:gmatch("[^&]+") do
      assert.is_nil(kv:find("listELement", 1, true), "did not expect listELement in body, got: " .. kv)
    end
  end)


  it("ec2: map honors key/value locationName", function()
    local op = {
      name = "CreateTags",
      http = { method = "POST", requestUri = "/" },
      input = {
        type = "structure",
        members = {
          Tags = {
            type = "map",
            key   = { type = "string", locationName = "Key" },
            value = { type = "string", locationName = "Value" },
          },
        },
      },
    }
    local cfg = {
      apiVersion = "2016-11-15",
      globalEndpoint = "ec2.amazonaws.com",
      protocol = "ec2",
      signatureVersion = "v4",
    }
    local p = { Tags = { Env = "prod", Owner = "team" } }

    local request = build_request(op, cfg, p)
    local parsed = {}
    for kv in request.body:gmatch("[^&]+") do
      local k, v = kv:match("^([^=]*)=(.*)$")
      parsed[ngx.unescape_uri(k)] = ngx.unescape_uri(v)
    end

    -- pairs() ordering means we don't know which entry is .1 vs .2; collect pairs
    local pairs_seen = {}
    for i = 1, 2 do
      local k = parsed["Tags.entry." .. i .. ".Key"]
      local v = parsed["Tags.entry." .. i .. ".Value"]
      assert.is_not_nil(k, "missing Tags.entry." .. i .. ".Key")
      assert.is_not_nil(v, "missing Tags.entry." .. i .. ".Value")
      pairs_seen[k] = v
    end
    assert.same({ Env = "prod", Owner = "team" }, pairs_seen)

    -- and the literal .key/.value form must NOT be present
    for k in pairs(parsed) do
      assert.is_nil(k:find(".entry.%d+%.key$"), "unexpected literal .key segment: " .. k)
      assert.is_nil(k:find(".entry.%d+%.value$"), "unexpected literal .value segment: " .. k)
    end
  end)


  it("ec2: map without locationName falls back to literal key/value", function()
    local op = {
      name = "Whatever",
      http = { method = "POST", requestUri = "/" },
      input = {
        type = "structure",
        members = {
          Attrs = {
            type = "map",
            key   = { type = "string" },
            value = { type = "string" },
          },
        },
      },
    }
    local cfg = {
      apiVersion = "2016-11-15",
      globalEndpoint = "ec2.amazonaws.com",
      protocol = "ec2",
      signatureVersion = "v4",
    }
    local p = { Attrs = { foo = "bar" } }

    local request = build_request(op, cfg, p)
    local parsed = {}
    for kv in request.body:gmatch("[^&]+") do
      local k, v = kv:match("^([^=]*)=(.*)$")
      parsed[ngx.unescape_uri(k)] = ngx.unescape_uri(v)
    end

    assert.equal("foo", parsed["Attrs.entry.1.key"])
    assert.equal("bar", parsed["Attrs.entry.1.value"])
  end)


  it("query: nested list of structs uses .member. infix", function()
    local op = {
      name = "DescribeAlarms",
      http = { method = "POST", requestUri = "/" },
      input = {
        type = "structure",
        members = {
          Filters = {
            type = "list",
            member = {
              type = "structure",
              members = {
                Name = { type = "string" },
                Values = {
                  type = "list",
                  member = { type = "string" },
                },
              },
            },
          },
        },
      },
    }
    local cfg = {
      apiVersion = "2010-08-01",
      globalEndpoint = "monitoring.amazonaws.com",
      protocol = "query",
      signatureVersion = "v4",
    }
    local p = {
      Filters = {
        { Name = "Alarm", Values = { "a", "b" } },
      },
    }

    local request = build_request(op, cfg, p)

    assert.equal("Alarm", request.query["Filters.member.1.Name"])
    assert.equal("a",     request.query["Filters.member.1.Values.member.1"])
    assert.equal("b",     request.query["Filters.member.1.Values.member.2"])
  end)


end)
