local tablex = require "pl.tablex"

describe("stream decoder", function()
  setup(function()
    AWS = require "resty.aws"
  end)

  teardown(function()
    AWS = nil
    package.loaded["resty.aws"] = nil
  end)


  it("decodes multiple messages from a single chunk", function()
    local chunk_in_hex = "000000760000005296d5fade0b3a6576656e742d7479706507000c6d65737361676553746172740d3a636f6e74656e742d747970650700106170706c69636174696f6e2f6a736f6e0d3a6d6573736167652d747970650700056576656e747b22726f6c65223a22617373697374616e74227d6fa8c599000001110000005706f176a90b3a6576656e742d74797065070011636f6e74656e74426c6f636b44656c74610d3a636f6e74656e742d747970650700106170706c69636174696f6e2f6a736f6e0d3a6d6573736167652d747970650700056576656e747b22636f6e74656e74426c6f636b496e646578223a302c2264656c7461223a7b2274657874223a2250692028cf80292069732061206d617468656d61746963616c20636f6e7374616e74207468617420726570726573656e7473207468652063697263756d666572656e63652d746f2d6469616d6574657220726174696f206f66206120636972636c652e204974277320617070726f78696d6174656c7920332e31343135392e227d7d7d4e31940000007d00000056e6680fd60b3a6576656e742d74797065070010636f6e74656e74426c6f636b53746f700d3a636f6e74656e742d747970650700106170706c69636174696f6e2f6a736f6e0d3a6d6573736167652d747970650700056576656e747b22636f6e74656e74426c6f636b496e646578223a307db32e4d340000007a00000051ca2c46650b3a6576656e742d7479706507000b6d65737361676553746f700d3a636f6e74656e742d747970650700106170706c69636174696f6e2f6a736f6e0d3a6d6573736167652d747970650700056576656e747b2273746f70526561736f6e223a22656e645f7475726e227d5fbf09fc000000b90000004ee991d99b0b3a6576656e742d747970650700086d657461646174610d3a636f6e74656e742d747970650700106170706c69636174696f6e2f6a736f6e0d3a6d6573736167652d747970650700056576656e747b226d657472696373223a7b226c6174656e63794d73223a313530367d2c227573616765223a7b22696e707574546f6b656e73223a382c226f7574707574546f6b656e73223a33392c22746f74616c546f6b656e73223a34377d7d5ad2dd7b"
    local _STREAM = require("resty.aws.stream")
    local parser, err = _STREAM:new(chunk_in_hex, true)

    if err then
      assert.equal(err, nil)
      return
    end

    local messages = {}

    while true do
      local msg = parser:next_message()

      if not msg then
        break
      end

      messages[#messages+1] = msg
    end

    assert.same(messages, {
      {
        body = "{\"role\":\"assistant\"}",
        headers = {
            [":event-type"] = "messageStart",
            [":content-type"] = "application/json",
            [":message-type"] = "event",
        },
      },
      {
        body = "{\"contentBlockIndex\":0,\"delta\":{\"text\":\"Pi (π) is a mathematical constant that represents the circumference-to-diameter ratio of a circle. It's approximately 3.14159.\"}}",
        headers = {
            [":event-type"] = "contentBlockDelta",
            [":content-type"] = "application/json",
            [":message-type"] = "event",
        },
      },
      {
        body = "{\"contentBlockIndex\":0}",
        headers = {
            [":event-type"] = "contentBlockStop",
            [":content-type"] = "application/json",
            [":message-type"] = "event",
        },
      },
      {
        body = "{\"stopReason\":\"end_turn\"}",
        headers = {
            [":event-type"] = "messageStop",
            [":content-type"] = "application/json",
            [":message-type"] = "event",
        },
      },
      {
        body = "{\"metrics\":{\"latencyMs\":1506},\"usage\":{\"inputTokens\":8,\"outputTokens\":39,\"totalTokens\":47}}",
        headers = {
            [":event-type"] = "metadata",
            [":content-type"] = "application/json",
            [":message-type"] = "event",
        },
      },
    })
  end)
end)
