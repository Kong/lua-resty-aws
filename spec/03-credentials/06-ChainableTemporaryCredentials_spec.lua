
describe("ChainableTemporaryCredentials", function()

  local AWS = require "resty.aws"
  local ChainableTemporaryCredentials = require "resty.aws.credentials.ChainableTemporaryCredentials"

  setup(function()
    --setup
  end)

  teardown(function()
    --teardown
  end)

  describe("new()", function()

    it("creates a new instance when providing AWS-instance", function()
      local aws = AWS()
      local params = {}
      local creds
      assert.has.no.error(function()
        creds = assert(ChainableTemporaryCredentials:new {
          params = params,
          aws = aws,
        })
      end)
      assert.is_function(creds.sts.assumeRole)
      assert.are.equal(aws.config.credentials, creds.masterCredentials)
      assert.are.equal(params, creds.params)
    end)


    it("accepts params as a single entry array", function()
      local aws = AWS()
      local params = {}
      local creds
      assert.has.no.error(function()
        creds = assert(ChainableTemporaryCredentials:new {
          params = { params },
          aws = aws,
        })
      end)
      assert.is_function(creds.sts.assumeRole)
      assert.are.equal(aws.config.credentials, creds.masterCredentials)
      assert.are.equal(params, creds.params)
    end)


    it("creates a new instance when providing STS-instance", function()
      local sts = AWS():STS()
      local params = {}
      local creds
      assert.has.no.error(function()
        creds = assert(ChainableTemporaryCredentials:new {
          params = params,
          sts = sts,
        })
      end)
      assert.is_function(creds.sts.assumeRole)
      assert.are.equal(sts.config.credentials, creds.masterCredentials)
      assert.are.equal(params, creds.params)
    end)


    it("creates chained credentials from params-array", function()
      local aws = AWS()
      local params_start, params_middle, params_final = {}, {}, {}
      local creds_final
      assert.has.no.error(function()
        creds_final = assert(ChainableTemporaryCredentials:new {
          params = { params_start, params_middle, params_final },
          aws = aws,
        })
      end)

      assert.are.equal(params_final, creds_final.params)

      local creds_middle = creds_final.masterCredentials
      assert.are.equal(params_middle, creds_middle.params)

      local creds_start = creds_middle.masterCredentials
      assert.are.equal(params_start, creds_start.params)

      assert.are.equal(aws.config.credentials, creds_start.masterCredentials)

    end)
  end)

end)
