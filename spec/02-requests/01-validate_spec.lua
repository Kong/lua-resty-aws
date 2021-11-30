local validate = require "resty.aws.request.validate"

local test_data = {
  {
    shape = {
      type = "double",
      min = 5,
      max = 10,
    },
    cases = {
      {
        description = "valid number is accepted",
        input = 6,
        error = nil
      }, {
        description = "lower edge is accepted",
        input = 5,
        error = nil
      }, {
        description = "upper edge is accepted",
        input = 10,
        error = nil
      }, {
        description = "non-number is rejected",
        input = "hello",
        error = "expected a number (double) value, got 'hello' (string)"
      }, {
        description = "below min is rejected",
        input = -1,
        error = "minimum of 5, got -1"
      }, {
        description = "above max is rejected",
        input = 20,
        error = "maximum of 10, got 20"
      }, {
        description = "above max is rejected (with id)",
        input = 20,
        id = "my.field",
        error = "my.field: maximum of 10, got 20"
      }
    }
  }, {
    shape = {
      type = "integer",
      min = 5,
      max = 10,
    },
    cases = {
      {
        description = "valid number is accepted",
        input = 6,
        error = nil
      }, {
        description = "lower edge is accepted",
        input = 5,
        error = nil
      }, {
        description = "upper edge is accepted",
        input = 10,
        error = nil
      }, {
        description = "non-number is rejected",
        input = "hello",
        error = "expected a number (integer) value, got 'hello' (string)"
      }, {
        description = "below min is rejected",
        input = -1,
        error = "minimum of 5, got -1"
      }, {
        description = "above max is rejected",
        input = 20,
        error = "maximum of 10, got 20"
      }, {
        description = "above max is rejected (with id)",
        input = 20,
        id = "my.field",
        error = "my.field: maximum of 10, got 20"
      }
    }
  }, {
    shape = {
      type = "long",
      min = 5,
      max = 10,
    },
    cases = {
      {
        description = "valid number is accepted",
        input = 6,
        error = nil
      }, {
        description = "lower edge is accepted",
        input = 5,
        error = nil
      }, {
        description = "upper edge is accepted",
        input = 10,
        error = nil
      }, {
        description = "non-number is rejected",
        input = "hello",
        error = "expected a number (long) value, got 'hello' (string)"
      }, {
        description = "below min is rejected",
        input = -1,
        error = "minimum of 5, got -1"
      }, {
        description = "above max is rejected",
        input = 20,
        error = "maximum of 10, got 20"
      }, {
        description = "above max is rejected (with id)",
        input = 20,
        id = "my.field",
        error = "my.field: maximum of 10, got 20"
      }
    }
  }, {
    shape = {
      type = "float",
      min = 5,
      max = 10,
    },
    cases = {
      {
        description = "valid number is accepted",
        input = 6,
        error = nil
      }, {
        description = "lower edge is accepted",
        input = 5,
        error = nil
      }, {
        description = "upper edge is accepted",
        input = 10,
        error = nil
      }, {
        description = "non-number is rejected",
        input = "hello",
        error = "expected a number (float) value, got 'hello' (string)"
      }, {
        description = "below min is rejected",
        input = -1,
        error = "minimum of 5, got -1"
      }, {
        description = "above max is rejected",
        input = 20,
        error = "maximum of 10, got 20"
      }, {
        description = "above max is rejected (with id)",
        input = 20,
        id = "my.field",
        error = "my.field: maximum of 10, got 20"
      }
    }
  }, {
    shape = {
      type = "string", -- there is another one below for enum checking
      min = 5,
      max = 10,
      pattern = "^[abc]+$",
    },
    cases = {
      {
        description = "valid string is accepted",
        input = "abcabc",
        error = nil
      }, {
        description = "lower edge length is accepted",
        input = "abcab",
        error = nil
      }, {
        description = "upper edge length is accepted",
        input = "abcabcabca",
        error = nil
      }, {
        description = "non-string is rejected",
        input = true,
        error = "expected a string value, got 'true' (boolean)"
      -- }, {  -- disabled, JavaScript regex are incompatible with OpenResty
      --   description = "not matching pattern is rejected",
      --   input = "123456789",
      --   error = "value should match pattern: ^[abc]+$"
      }, {
        description = "below min length is rejected",
        input = "abc",
        error = "minimum length of 5"
      }, {
        description = "above max length is rejected",
        input = "abcabcabcabc",
        error = "maximum length of 10"
      }, {
        description = "above max length is rejected (with id)",
        input = "abcabcabcabc",
        id = "my.field",
        error = "my.field: maximum length of 10"
      }
    }
  }, {
    shape = {
      type = "string", -- most string validation are above ^^
      enum = {
        "abc", "def"
      }
    },
    cases = {
      {
        description = "valid string is accepted",
        input = "abc",
        error = nil
      }, {
        description = "non-enum is rejected",
        input = "123",
        error = "value '123' is not allowed, it should be any of: 'abc', 'def'"
      }
    }
  }, {
    shape = {
      type = "blob",
      min = 5,
      max = 10,
    },
    cases = {
      {
        description = "valid string is accepted",
        input = "abcabc",
        error = nil
      }, {
        description = "lower edge length is accepted",
        input = "abcab",
        error = nil
      }, {
        description = "upper edge length is accepted",
        input = "abcabcabca",
        error = nil
      }, {
        description = "non-string is rejected",
        input = true,
        error = "expected a string (blob) value, got 'true' (boolean)"
      }, {
        description = "below min length is rejected",
        input = "abc",
        error = "minimum length of 5"
      }, {
        description = "above max length is rejected",
        input = "abcabcabcabc",
        error = "maximum length of 10"
      }, {
        description = "above max length is rejected (with id)",
        input = "abcabcabcabc",
        id = "my.field",
        error = "my.field: maximum length of 10"
      }
    }
  }, {
    shape = {
      type = "boolean",
    },
    cases = {
      {
        description = "valid boolean (true) is accepted",
        input = true,
        error = nil
      }, {
        description = "valid boolean (false) is accepted",
        input = false,
        error = nil
      }, {
        description = "non-boolean is rejected",
        input = 123,
        error = "expected a boolean value, got '123' (number)"
      }, {
        description = "non-boolean is rejected (with id)",
        input = 123,
        id = "my.field",
        error = "my.field: expected a boolean value, got '123' (number)"
      }, {
        description = "non-boolean (nil) rejected",
        input = nil,
        error = "expected a boolean value, got 'nil' (nil)"
      }
    }
  }, {
    shape = {
      type = "list",
      min = 1,
      max = 3,
      member = {
        type = "integer",
      }
    },
    cases = {
      {
        description = "valid list is accepted",
        input = { 1, 2 },
        error = nil
      }, {
        description = "lower edge length is accepted",
        input = { 1 },
        error = nil
      }, {
        description = "upper edge length is accepted",
        input = { 1, 2, 3 },
        error = nil
      }, {
        description = "non-list (boolean) is rejected",
        input = true,
        error = "expected a table (list) value, got 'true' (boolean)"
      }, {
        description = "non-list (hash-table) is rejected",
        input = { hello = "world" },
        error = "list contains non-numeric indices"
      }, {
        description = "below min length is rejected",
        input = {},
        error = "minimum list length of 1"
      }, {
        description = "above max length is rejected",
        input = { 1, 2, 3, 4, 5 },
        error = "maximum list length of 3"
      }, {
        description = "members are validated",
        input = { 1, 2, true },
        error = "[3]: expected a number (integer) value, got 'true' (boolean)"
      }, {
        description = "members are validated (with id)",
        input = { 1, 2, true },
        id = "my.list",
        error = "my.list[3]: expected a number (integer) value, got 'true' (boolean)"
      }
    }
  }, {
    shape = {
      type = "map",
      min = 2,
      max = 4,
      key = {
        type = "string",
        min = 3,
      },
      value = {
        type = "integer",
        max = 256,
      }
    },
    cases = {
      {
        description = "valid map is accepted",
        input = { one = 1, two = 2, three = 3 },
        error = nil
      }, {
        description = "lower edge size is accepted",
        input = { one = 1, two = 2 },
        error = nil
      }, {
        description = "upper edge size is accepted",
        input = { one = 1, two = 2, three = 3, four = 4 },
        error = nil
      }, {
        description = "non-map (boolean) is rejected",
        input = true,
        error = "expected a table (map) value, got 'true' (boolean)"
      }, {
        description = "below min size is rejected",
        input = { one = 1 },
        error = "minimum map size of 2"
      }, {
        description = "above max size is rejected",
        input = { one = 1, two = 2, three = 3, four = 4, five = 5 },
        error = "maximum map size of 4"
      }, {
        description = "keys are validated",
        input = { x = 1, two = 2, three = 3 },
        error = "x: the key ('x') failed validation: minimum length of 3"
      }, {
        description = "keys are validated (with id)",
        input = { x = 1, two = 2, three = 3 },
        id = "my.field",
        error = "my.field.x: the key ('x') failed validation: minimum length of 3"
      }, {
        description = "values are validated",
        input = { one = 1, two = 2, three = 1024 },
        error = "three: maximum of 256, got 1024"
      }, {
        description = "values are validated (with id)",
        input = { one = 1, two = 2, three = 1024 },
        id = "my.field",
        error = "my.field.three: maximum of 256, got 1024"
      }
    }
  }, {
    shape = {
      type = "structure",
      required = { "must_have_field" },
      members = {
        an_integer = {
          type = "integer",
          max = 256,
        }
      }
    },
    cases = {
      {
        description = "valid structure is accepted",
        input = { must_have_field = true },
        error = nil
      }, {
        description = "unknown member is accepted",
        input = { must_have_field = true, unknown = "john doe" },
        error = nil
      }, {
        description = "non-structure (boolean) is rejected",
        input = true,
        error = "expected a table (structure) value, got 'true' (boolean)"
      }, {
        description = "required members are required",
        input = { unknown = "john doe" },
        error = "must_have_field is required but missing"
      }, {
        description = "required members are required (with id)",
        input = { unknown = "john doe" },
        id = "my.field",
        error = "my.field.must_have_field is required but missing"
      }, {
        description = "members get validated",
        input = { must_have_field = true, an_integer = 1024 },
        error = "an_integer: maximum of 256, got 1024"
      }, {
        description = "members get validated (with id)",
        input = { must_have_field = true, an_integer = 1024 },
        id = "my.field",
        error = "my.field.an_integer: maximum of 256, got 1024"
      }
    }
  }

}




describe("shape validation", function()

  for _, test_set in ipairs(test_data) do
    local shape = test_set.shape

    describe(shape.type .. ":", function()

      for _, case in ipairs(test_set.cases) do

        it(case.description, function()
          local ok, err = validate(case.input, shape, case.id)
          if case.error then
            assert.is.same(case.error, err)
            assert.is.falsy(ok)
          else
            assert.is.Nil(err)
            assert.is.True(ok)
          end
        end)

      end

    end)
  end

end)
