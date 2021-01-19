setmetatable(_G, nil) -- disable global warnings

-- make sure we can use dev code
package.path = "./src/?.lua;./src/?/init.lua;"..package.path

-- quick debug dump function
local dump = function(...)
  local t = { n = select("#", ...), ...}
  if t.n == 1 and type(t[1]) == "table" then t = t[1] end
  print(require("pl.pretty").write(t))
end





local AWS = require("resty.aws")
local aws = AWS()
local secretsmanager = aws:SecretsManager { region = "us-east-2" }

dump(secretsmanager:GetSecretValue {
  SecretId = "arn:aws:secretsmanager:us-east-2:238406704566:secret:test2-HN1F1k",
})



--[[
local secret = assert(credentials.fetch_secret(creds, {
  SecretId = "arn:aws:secretsmanager:us-east-2:238406704566:secret:test2-HN1F1k",
}))

dump(secret)

local secret = assert(credentials.fetch_secret(creds, {
  SecretId = "arn:aws:secretsmanager:us-east-2:238406704566:secret:KEY_VALUE_test-IHwf2S",
}))

dump(secret)

local secret = assert(credentials.fetch_secret(creds, {
  SecretId = "arn:aws:secretsmanager:us-east-2:238406704566:secret:test3_plain_text-PDPBwp",
}))

dump(secret)
--]]

--require "resty.credentials.aws.api"
