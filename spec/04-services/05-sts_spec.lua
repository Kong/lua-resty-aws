setmetatable(_G, nil)

-- -- hock request sending
-- package.loaded["resty.aws.request.execute"] = function(...)
--   return ...
-- end

local AWS = require("resty.aws")
local AWS_global_config = require("resty.aws.config").global

local config = AWS_global_config
local aws = AWS(config)

aws.config.credentials = aws:Credentials {
  accessKeyId = "test_id",
  secretAccessKey = "test_key",
}

-- aws.config.region = "test_region"

local test_assume_role_arn = "arn:aws:iam::123456789012:role/test-role"
local test_role_session_name = "lua-resty-aws-test-assumeRole"

describe("STS service", function()
  local origin_time
  setup(function()
    origin_time = ngx.time
    ngx.time = function () --luacheck: ignore
      return 1667543171
    end
  end)

  teardown(function ()
    ngx.time = origin_time --luacheck: ignore
  end)

  -- before_each(function()
  --   sts = aws:STS()
  -- end)

  -- after_each(function()

  -- end)

  for _, region in ipairs({"us-east-1", "us-east-2", "ap-south-1", "ca-west-1", "eu-west-2", "sa-east-1"}) do
    describe("In Region #" .. region, function ()
      -- before_each(function()
      --   aws.config.region = region
      -- end)

      it("AWS_STS_REGIONAL_ENDPOINT==regional with default endpoint", function ()
        local config = {
          region = region,
          stsRegionalEndpoints = "regional",
          dry_run = true,
        }

        local sts = aws:STS(config)
        local request = sts:assumeRole({
          RoleArn = test_assume_role_arn,
          RoleSessionName = test_role_session_name,
        })

        assert.same(sts.config.stsRegionalEndpoints, "regional")
        -- Check the signing region has been injected
        assert.same(region, sts.config.signingRegion)
        assert.truthy(sts.config._regionalEndpointInjected)
        -- Check the endpoint has been injected
        assert.same(sts.config.endpoint, "https://sts." .. region .. ".amazonaws.com")
        assert.not_nil(request.headers.Authorization:find(region, 1, true))
      end)

      describe("AWS_STS_REGIONAL_ENDPOINT==regional with non-default endpoint", function()
        it("and endpoint is regional domain", function ()
          local config = {
            region = region,
            stsRegionalEndpoints = "regional",
            endpoint = "https://sts." .. region .. ".amazonaws.com",
            dry_run = true,
          }

          local sts = aws:STS(config)
          local request = sts:assumeRole({
            RoleArn = test_assume_role_arn,
            RoleSessionName = test_role_session_name,
          })

          assert.same(sts.config.stsRegionalEndpoints, "regional")
          -- Check the signing region has been injected
          assert.same(region, sts.config.signingRegion)
          assert.truthy(sts.config._regionalEndpointInjected)
          -- Check thes endpoint has not been injected twice
          assert.same(sts.config.endpoint, config.endpoint)
          assert.not_nil(request.headers.Authorization:find(region, 1, true))
        end)

        it("and endpoint is global domain", function ()
          local config = {
            region = region,
            stsRegionalEndpoints = "regional",
            endpoint = "https://sts.amazonaws.com",
            dry_run = true,
          }

          local sts = aws:STS(config)
          local request = sts:assumeRole({
            RoleArn = test_assume_role_arn,
            RoleSessionName = test_role_session_name,
          })

          assert.same(sts.config.stsRegionalEndpoints, "regional")
          -- Check the signing region has been injected
          assert.same(region, sts.config.signingRegion)
          assert.truthy(sts.config._regionalEndpointInjected)
          -- Check the endpoint has been injected
          assert.same(sts.config.endpoint, "https://sts." .. region .. ".amazonaws.com")
          assert.not_nil(request.headers.Authorization:find(region, 1, true))
        end)

        it("and endpoint is region VPC endpoint", function ()
          local config = {
            region = region,
            stsRegionalEndpoints = "regional",
            endpoint = "https://vpce-1234567-abcdefg.sts." .. region .. ".vpce.amazonaws.com",
            dry_run = true,
          }

          local sts = aws:STS(config)
          local request = sts:assumeRole({
            RoleArn = test_assume_role_arn,
            RoleSessionName = test_role_session_name,
          })

          assert.same(sts.config.stsRegionalEndpoints, "regional")
          -- Check the signing region has been injected
          assert.same(region, sts.config.signingRegion)
          assert.truthy(sts.config._regionalEndpointInjected)
          -- Check the endpoint has not been injected when endpoint is a vpc endpoint
          assert.same(sts.config.endpoint, config.endpoint)
          assert.not_nil(request.headers.Authorization:find(region, 1, true))
        end)

        it("and endpoint is AZ VPC endpoint", function ()
          local config = {
            region = region,
            stsRegionalEndpoints = "regional",
            endpoint = "https://vpce-1234567-abcdefg-" .. region .. "c" .. ".sts." .. region .. ".vpce.amazonaws.com",
            dry_run = true,
          }

          local sts = aws:STS(config)
          local request = sts:assumeRole({
            RoleArn = test_assume_role_arn,
            RoleSessionName = test_role_session_name,
          })

          assert.same(sts.config.stsRegionalEndpoints, "regional")
          -- Check the signing region has been injected
          assert.same(region, sts.config.signingRegion)
          assert.truthy(sts.config._regionalEndpointInjected)
          -- Check the endpoint has not been injected when endpoint is a vpc endpoint
          assert.same(sts.config.endpoint, config.endpoint)
          assert.not_nil(request.headers.Authorization:find(region, 1, true))
        end)
      end)

      it("AWS_STS_REGIONAL_ENDPOINT==legacy with default endpoint", function ()
        local config = {
          region = region,
          stsRegionalEndpoints = "legacy",
          dry_run = true,
        }

        local sts = aws:STS(config)
        local request = sts:assumeRole({
          RoleArn = test_assume_role_arn,
          RoleSessionName = test_role_session_name,
        })

        assert.same(sts.config.stsRegionalEndpoints, "legacy")
        assert.same("us-east-1", sts.config.signingRegion)
        assert.is_nil(sts.config._regionalEndpointInjected)
        assert.same(sts.config.endpoint, "https://sts.amazonaws.com")
        assert.not_nil(request.headers.Authorization:find("us-east-1", 1, true))
      end)
    end)
  end

  -- CN Region check, the STS endpoint will be suffixed with ".com.cn"
  -- For CN Region there will be no region injections since globalEndpoint
  -- is not defined for "cn-*/*" in region_config_data.lua
  for _, region in ipairs({"cn-north-1", "cn-northwest-1"}) do
    describe("In Region #" .. region, function ()
      -- before_each(function()
      --   aws.config.region = region
      -- end)

      it("AWS_STS_REGIONAL_ENDPOINT==regional with default endpoint", function ()
        local config = {
          region = region,
          stsRegionalEndpoints = "regional",
          dry_run = true,
        }

        local sts = aws:STS(config)
        local request = sts:assumeRole({
          RoleArn = test_assume_role_arn,
          RoleSessionName = test_role_session_name,
        })

        assert.same(sts.config.stsRegionalEndpoints, "regional")
        assert.is_nil(sts.config.signingRegion)
        assert.falsy(sts.config._regionalEndpointInjected)
        -- Check the endpoint has not been injected
        assert.same(sts.config.endpoint, "sts." .. region .. ".amazonaws.com.cn")
        assert.not_nil(request.headers.Authorization:find(region, 1, true))
      end)

      describe("AWS_STS_REGIONAL_ENDPOINT==regional with non-default endpoint", function()
        it("and endpoint is regional domain", function ()
          local config = {
            region = region,
            stsRegionalEndpoints = "regional",
            endpoint = "https://sts." .. region .. ".amazonaws.com.cn",
            dry_run = true,
          }

          local sts = aws:STS(config)
          local request = sts:assumeRole({
            RoleArn = test_assume_role_arn,
            RoleSessionName = test_role_session_name,
          })

          assert.same(sts.config.stsRegionalEndpoints, "regional")
          assert.is_nil(sts.config.signingRegion)
          assert.falsy(sts.config._regionalEndpointInjected)
          -- Check thes endpoint has not been injected
          assert.same(sts.config.endpoint, config.endpoint)
          assert.not_nil(request.headers.Authorization:find(region, 1, true))
        end)

        it("and endpoint is region VPC endpoint", function ()
          local config = {
            region = region,
            stsRegionalEndpoints = "regional",
            endpoint = "https://vpce-1234567-abcdefg.sts." .. region .. ".vpce.amazonaws.com",
            dry_run = true,
          }

          local sts = aws:STS(config)
          local request = sts:assumeRole({
            RoleArn = test_assume_role_arn,
            RoleSessionName = test_role_session_name,
          })

          assert.same(sts.config.stsRegionalEndpoints, "regional")
          assert.is_nil(sts.config.signingRegion)
          assert.falsy(sts.config._regionalEndpointInjected)
          -- Check the endpoint has not been injected when endpoint is a vpc endpoint
          assert.same(sts.config.endpoint, config.endpoint)
          assert.not_nil(request.headers.Authorization:find(region, 1, true))
        end)

        it("and endpoint is AZ VPC endpoint", function ()
          local config = {
            region = region,
            stsRegionalEndpoints = "regional",
            endpoint = "https://vpce-1234567-abcdefg-" .. region .. "c" .. ".sts." .. region .. ".vpce.amazonaws.com",
            dry_run = true,
          }

          local sts = aws:STS(config)
          local request = sts:assumeRole({
            RoleArn = test_assume_role_arn,
            RoleSessionName = test_role_session_name,
          })

          assert.same(sts.config.stsRegionalEndpoints, "regional")
          assert.is_nil(sts.config.signingRegion)
          assert.falsy(sts.config._regionalEndpointInjected)
          -- Check the endpoint has not been injected when endpoint is a vpc endpoint
          assert.same(sts.config.endpoint, config.endpoint)
          assert.not_nil(request.headers.Authorization:find(region, 1, true))
        end)
      end)

      it("AWS_STS_REGIONAL_ENDPOINT==legacy with default endpoint", function ()
        local config = {
          region = region,
          stsRegionalEndpoints = "legacy",
          dry_run = true,
        }

        local sts = aws:STS(config)
        local request = sts:assumeRole({
          RoleArn = test_assume_role_arn,
          RoleSessionName = test_role_session_name,
        })

        assert.same(sts.config.stsRegionalEndpoints, "legacy")
        assert.is_nil(sts.config.signingRegion)
        assert.falsy(sts.config._regionalEndpointInjected)
        assert.same(sts.config.endpoint, "sts." .. region .. ".amazonaws.com.cn")
        assert.not_nil(request.headers.Authorization:find(region, 1, true))
      end)
    end)
  end
end)
