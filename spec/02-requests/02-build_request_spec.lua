local cjson = require "cjson"
local pl_stringx = require "pl.stringx"

describe("operations protocol", function()


  local build_request
  local operation, operation_with_payload_field
  local operation_with_requestUri_params_and_query_param_input
  local config, config_with_payload
  local params, params_with_payload
  local params_with_requestUri_params_and_query_param_input
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

  end)


  it("errors on a bad protocol", function()

    config.protocol = "shake hands"

    assert.has.error(function()
      build_request(operation, config, params)
    end, "Bad config, field protocol is invalid, got: 'shake hands'")
  end)


  it("query: params go into query table, target action+version added", function()

    config.protocol = "query"
    params.subList = nil
    params.subStructure = nil

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


  pending("ec2: querystring, uri, header and body params", function()

    config.protocol = "ec2"

    assert.has.error(function()
      build_request(operation, config, params)
    end, "protocol 'ec2' not implemented yet")
  end)


end)
