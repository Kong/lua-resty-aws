local pl_path = require "pl.path"
local pl_config = require "pl.config"
local tbl_clear = require "table.clear"
local restore = require "spec.helpers"

local hooked_file = {}

local origin_read = pl_config.read
local origin_isfile = pl_path.isfile

pl_config.read = function(name, ...)
  return hooked_file[name] or origin_read(name, ...)
end

pl_path.isfile = function(name)
  return hooked_file[name] and true or origin_isfile(name)
end

local function hook_config_file(name, content)
  hooked_file[name] = content
end

describe("SharedFileCredentials_spec", function()

  local SharedFileCredentials_spec

  before_each(function()
    -- make ci happy
    restore.setenv("HOME", "/home/ci-test")
    local _ = require("resty.aws.config").global -- load config before anything else

    SharedFileCredentials_spec = require "resty.aws.credentials.SharedFileCredentials"
  end)

  after_each(function()
    restore()
    tbl_clear(hooked_file)
  end)


  it("basical sanity", function()
    local cred = SharedFileCredentials_spec:new {}
    assert(cred:needsRefresh()) -- true; because we has no file
  end)

  it("gets from config", function()
    hook_config_file(pl_path.expanduser("~/.aws/config"), {
      default = {
        aws_access_key_id = "access",
        aws_secret_access_key = "secret",
        aws_session_token = "token",
      }
    })
    local cred = SharedFileCredentials_spec:new {}
    assert.is_false(cred:needsRefresh()) -- false; because we fetch upon instanciation

    local get = {cred:get()}
    assert.is.near(ngx.now() + 10*365*24*60*60, 30, get[5]) -- max delta = 30 seconds

    get[5] = nil
    assert.same({true, "access", "secret", "token"}, get)
  end)

  it("gets from credentials", function()
    hook_config_file(pl_path.expanduser("~/.aws/credentials"), {
      default = {
        aws_access_key_id = "access",
        aws_secret_access_key = "secret",
        aws_session_token = "token",
      }
    })

    local cred = SharedFileCredentials_spec:new {}
    assert.is_false(cred:needsRefresh()) -- false; because we fetch upon instanciation

    local get = {cred:get()}
    assert.is.near(ngx.now() + 10*365*24*60*60, 30, get[5]) -- max delta = 30 seconds

    get[5] = nil
    assert.same({true, "access", "secret", "token"}, get)
  end)

end)
