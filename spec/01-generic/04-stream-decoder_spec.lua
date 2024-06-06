local decoder = require("resty.aws.stream")

local tablex = require "pl.tablex"

describe("stream decoder", function()


  local AWS

  setup(function()
    AWS = require "resty.aws"
  end)

  teardown(function()
    AWS = nil
    package.loaded["resty.aws"] = nil
  end)


  it("decodes multiple messages from a single chunk", function()
    local mesh = assert(AWS():AppMesh({ apiVersion = "2019-01-25", region = "us-east-1" }))
    assert.equal("2019-01-25", mesh.config.apiVersion)
  end)


end)
