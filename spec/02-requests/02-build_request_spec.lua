local cjson = require "cjson"

describe("operations protocol", function()


  local build_request
  local operation
  local config
  local params
  local snapshot

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
    operation = {
      name = "AssumeRole",
      http = {
        method = "POST",
        requestUri = "/hello/{InstanceId}"
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

    params = {
      RoleArn = "hello",
      RoleSessionName = "world",
      InstanceId = "42",
      UserId = "Arthur Dent",
      Token = "towel",
      subStructure = {
        hello = "the default hello thinghy",
        world = "the default world thinghy"
      },
      subList = { 1, 2 ,3}
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
      },
      method = 'POST',
      path = '/hello/42',
      query = {
        RoleArn = 'hello',
        RoleSessionName = 'world',
        UserId = "Arthur Dent",
        Action = "AssumeRole",
        Version = "2011-06-15",
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
        ["Content-Length"] = 152,
        ["Content-Type"] = "application/x-amz-json-1.0",
        ["X-Amz-Target"] = "sts.AssumeRole",
      },
      method = 'POST',
      path = '/hello/42',
      body = {
        subStructure = {
          hello = "the default hello thinghy",
          world = "the default world thinghy",
        },
        subList = { 1,2,3 },
        RoleArn = "hello",
        RoleSessionName = "world",
      },
      query = {
        UserId = "Arthur Dent",
      }
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
        ["Content-Length"] = 152,
        ["Content-Type"] = "application/x-amz-json-1.0",
        ["X-Amz-Target"] = "sts.AssumeRole",
      },
      method = 'POST',
      path = '/hello/42',
      body = {
        subStructure = {
          hello = "the default hello thinghy",
          world = "the default world thinghy",
        },
        subList = { 1,2,3 },
        RoleArn = "hello",
        RoleSessionName = "world",
      },
      query = {
        UserId = "Arthur Dent",
      }
    }, request)
  end)


  it("rest-xml: querystring, uri, header and body params", function()

    config.protocol = "rest-xml"

    local request = build_request(operation, config, params)
    if request and request.body then
      -- cannot reliably compare non-canonicalized json, so decode to Lua table
      request.body = assert(require("pl.xml").parse(request.body))
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
        ["Content-Length"] = 424,
        ["Content-Type"] = "application/xml",
        ["X-Amz-Target"] = "sts.AssumeRole",
      },
      method = 'POST',
      path = '/hello/42',
      body = {
        RoleArn = {
          [1] = 'hello' },
        RoleSessionName = {
          [1] = 'world' },
        attr = {
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
