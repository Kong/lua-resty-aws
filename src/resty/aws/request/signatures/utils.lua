-- AWS requests signing utils

local resty_sha256 = require "resty.sha256"
local openssl_hmac = require "resty.openssl.hmac"


local CHAR_TO_HEX = {};
for i = 0, 255 do
  local char = string.char(i)
  local hex = string.format("%02x", i)
  CHAR_TO_HEX[char] = hex
end

local URI_UNRESERVED_CHARS_PATTERN = "[^%w%-%._~]"
local QUERY_STRING_KV_PATTERN = "([^&=]+)=?([^&]*)"


local function hmac(secret, data)
  return openssl_hmac.new(secret, "sha256"):final(data)
end


local function hash(str)
  local sha256 = resty_sha256:new()
  sha256:update(str)
  return sha256:final()
end


local function hex_encode(str) -- From prosody's util.hex
  return (str:gsub(".", CHAR_TO_HEX))
end


local function percent_encode(char)
  return string.format("%%%02X", string.byte(char))
end


local function canonicalise_path(path)
  local segments = {}
  for segment in path:gmatch("/([^/]*)") do
    if segment == "" or segment == "." then
      segments = segments -- do nothing and avoid lint
    elseif segment == " .. " then
      -- intentionally discards components at top level
      segments[#segments] = nil
    else
      segments[#segments+1] = segment:gsub(URI_UNRESERVED_CHARS_PATTERN,
                                                             percent_encode)
    end
  end
  local len = #segments
  if len == 0 then
    return "/"
  end
  -- If there was a slash on the end, keep it there.
  if path:sub(-1, -1) == "/" then
    len = len + 1
    segments[len] = ""
  end
  segments[0] = ""
  segments = table.concat(segments, "/", 0, len)
  return segments
end


local function canonicalise_query_string(query)
  local q = {}
  if type(query) == "string" then
    for key, val in query:gmatch(QUERY_STRING_KV_PATTERN) do
      key = ngx.unescape_uri(key):gsub(URI_UNRESERVED_CHARS_PATTERN, percent_encode)
      val = ngx.unescape_uri(val):gsub(URI_UNRESERVED_CHARS_PATTERN, percent_encode)
      q[#q+1] = key .. "=" .. val
    end

  elseif type(query) == "table" then
    for key, val in pairs(query) do
      key = key:gsub(URI_UNRESERVED_CHARS_PATTERN, percent_encode)
      val = val:gsub(URI_UNRESERVED_CHARS_PATTERN, percent_encode)
      q[#q+1] = key .. "=" .. val
    end

  else
    error("bad query type, expected string or table, got: ".. type(query))
  end

  table.sort(q)
  return table.concat(q, "&")
end


local function add_args_to_query_string(query_args, query_string, sort)
  local q = {}
  if type(query_args) == "string" then
    for key, val in query_args:gmatch(QUERY_STRING_KV_PATTERN) do
      key = tostring(key):gsub(URI_UNRESERVED_CHARS_PATTERN, percent_encode)
      val = tostring(val):gsub(URI_UNRESERVED_CHARS_PATTERN, percent_encode)
      q[#q+1] = key .. "=" .. val
    end

  elseif type(query_args) == "table" then
    for key, val in pairs(query_args) do
      key = tostring(key):gsub(URI_UNRESERVED_CHARS_PATTERN, percent_encode)
      val = tostring(val):gsub(URI_UNRESERVED_CHARS_PATTERN, percent_encode)
      q[#q+1] = key .. "=" .. val
    end

  else
    error("bad query type, expected string or table, got: ".. type(query_args))
  end

  for key, val in query_string:gmatch(QUERY_STRING_KV_PATTERN) do
    key = ngx.unescape_uri(key):gsub(URI_UNRESERVED_CHARS_PATTERN, percent_encode)
    val = ngx.unescape_uri(val):gsub(URI_UNRESERVED_CHARS_PATTERN, percent_encode)
    q[#q+1] = key .. "=" .. val
  end

  if sort then
    table.sort(q)
  end

  return table.concat(q, "&")
end


local function derive_signing_key(kSecret, date, region, service)
  -- TODO: add an LRU cache to cache the generated keys?
  local kDate = hmac("AWS4" .. kSecret, date)
  local kRegion = hmac(kDate, region)
  local kService = hmac(kRegion, service)
  local kSigning = hmac(kService, "aws4_request")
  return kSigning
end


return {
  hmac = hmac,
  hash = hash,
  hex_encode = hex_encode,
  percent_encode = percent_encode,
  canonicalise_path = canonicalise_path,
  canonicalise_query_string = canonicalise_query_string,
  derive_signing_key = derive_signing_key,
  add_args_to_query_string = add_args_to_query_string,
}
