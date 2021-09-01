--- AWS utility module.
--
-- Provides methods for detecting the AWS Region, as well as fetching metadata.
-- Since the module requires access to the environment variables with metadata
-- URLs, it should preferably be loaded in the `init` phases to make sure it can
-- access the variables required.

local semaphore = require "ngx.semaphore"
local http = require "resty.aws.request.http.http"
local json = require "cjson"

-- get the Env vars here once, load this in the "init" phase to make sure
-- we still have access to those variables
local AWS_REGION = os.getenv "AWS_REGION"
local AWS_DEFAULT_REGION = os.getenv "AWS_DEFAULT_REGION"
local ECS_CONTAINERMETADATA_URI_V4 = os.getenv "ECS_CONTAINERMETADATA_URI_V4"
local ECS_CONTAINERMETADATA_URI_V3 = os.getenv "ECS_CONTAINERMETADATA_URI"
local ECS_CONTAINERMETADATA_URI_V2 = "http://169.254.170.2/v2/"
local IDMS_URI = "http://169.254.169.254"
local METADATA_TIMEOUTS = 5000  -- in milliseconds


local Utils = {}

-- makes a request with error-handling to Lua nil+err format, and decodes result
local function make_request(url, method, headers)
  local httpc = http:new()
  httpc:set_timeouts(METADATA_TIMEOUTS, METADATA_TIMEOUTS, METADATA_TIMEOUTS)

  -- fetch the metadata
  local res, err = httpc:request_uri(url, {
    method = method,
    headers = headers,
  })

  if not res then
    return nil, "failed to get metadata from " .. url .. ": " .. tostring(err)
  end

  if res.status ~= 200 then
    return nil, "failed to get metadata from " .. url .. ": " ..
                tostring(res.status) .. " " .. tostring(res.reason), res.status
  end

  if res.headers["Content-Type"]:find("json") then
    res.body = json.decode(res.body)
  end

  return res.body, res.headers["Content-Type"]
end



do -- getIMDSMetadata
  local IDMSToken

  --- Fetches IDMS Metadata (EC2 and EKS).
  -- Will make a call to the IP address and hence might timeout if ran on anything
  -- else than an EC2-instance.
  -- @param path (optional) path to return data from, default `/latest/meta-data/`
  -- @param version (optional) version of IDMS to use, either "V1" or "V2" (case insensitive, default "V2")
  -- @return body & content-type (if json, the body will be decoded to a Lua table), or nil+err
  function Utils.getIDMSMetadata(subpath, version, retry)
    local version = version and version:upper() or "V2"
    if version ~= "V1" and version ~= "V2" then
      error("unsupported IDMS metadata version: " .. version)
    end

    if subpath then
      assert(subpath:sub(1, 1) == "/", "subpath must begin with '/'")
    else
      subpath = "/latest/meta-data/"
    end

    local httpc = http:new()
    httpc:set_timeouts(METADATA_TIMEOUTS, METADATA_TIMEOUTS, METADATA_TIMEOUTS)

    -- check token, refresh if necessary
    if version ~= "V1" and not IDMSToken then
      local headers = { ["X-aws-ec2-metadata-token-ttl-seconds"] = "21600" }
      local token, err = make_request(IDMS_URI.."/latest/api/token", "PUT", headers)
      if not token then
        return nil, "failed getting IDMSToken: " .. tostring(err)
      end

      IDMSToken = token
    end

    -- fetch the metadata
    local headers
    if version ~= "V1" then
      headers = { ["X-aws-ec2-metadata-token"] = IDMSToken }
    end

    local resp, ct, status = make_request(IDMS_URI .. subpath, nil, headers)
    if version ~= "V1" and status == 401 and not retry then
      -- unauthorized, must refresh token, so clear and recurse as retry
      ngx.log(ngx.DEBUG, "IDMS metadata request returned '401 unauthorized', updating token and retrying")
      IDMSToken = nil
      return Utils.getIDMSMetadata(subpath, version, true)
    end
    return resp, ct
  end
end



--- Fetches ECS Task Metadata. Both for Fargate as well as EC2 based ECS.
-- Support version 2, 3, and 4 (version 2 is NOT available on Fargate).
-- V3 and V4 will return an error if no url is found in the related environment variable, V2 will make a request to
-- the IP address and hence might timeout if ran on anything else than a EC2-based ECS container.
-- @param subpath (optional) path to return data from (default "/metadata" for V2, nothing for V3+)
-- @param version (optional) metadata version to get "V3" or V4" (case insensitive, default "V4")
-- @return body & content-type (if json, the body will be decoded to a Lua table), or nil+err
function Utils.getECSTaskMetadata(subpath, version)
  local url
  local version = version and version:upper() or "V4"
  if version == "V4" then
    url = ECS_CONTAINERMETADATA_URI_V4
    if not url then
      return nil, "ECS metadata url V4 not found in env var ECS_CONTAINERMETADATA_URI_V4"
    end
  elseif version == "V3" then
    url = ECS_CONTAINERMETADATA_URI_V3
    if not url then
      return nil, "ECS metadata url V3 not found in env var ECS_CONTAINERMETADATA_URI"
    end
  elseif version == "V2" then
    url = ECS_CONTAINERMETADATA_URI_V2
    if not subpath then
      subpath = "/metadata"
    end
  else
    error("unsupported ECS metadata version: " .. version)
  end

  if subpath then
    assert(subpath:sub(1, 1) == "/", "subpath must begin with '/'")
    if url:sub(-1,-1) == "/" then
      url = url:sub(1, -2) .. subpath
    else
      url = url .. subpath
    end
  end

  return make_request(url)
end



do  -- getCurrentRegion
  local detected = false       -- did we detect already?
  local detected_region = nil  -- our previous detection result
  local detected_error = nil   -- an error message if we had that while detecting


  local function set_region(region, err)
    detected = true
    detected_region = region
    detected_error = err
    if err then
      ngx.log(ngx.INFO, "set AWS auto-detected region to '", region, "' with error msg: ", err)
    else
      ngx.log(ngx.DEBUG, "set AWS auto-detected region to '", region, "'")
    end
  end

  local function parse_region_from_availability_zone(availablity_zone)
    -- this is sub-optimal because it assumes the format of the availability zone
    -- to stay the same, but ECS metadata has no 'region' field, so best we can do.
    local region = availablity_zone:match("^(.+%-%d+)%w+$")
    if not region then
      return nil, "couldn't parse region from '"..availablity_zone.."'"
    end
    return region
  end

  local function detect_region()
    if AWS_REGION then
      ngx.log(ngx.DEBUG, "detecting AWS region from AWS_REGION env variable")
      set_region(AWS_REGION)
      return true
    else
      ngx.log(ngx.DEBUG, "no AWS_REGION env variable")
    end

    if AWS_DEFAULT_REGION then
      ngx.log(ngx.DEBUG, "detecting AWS region from AWS_DEFAULT_REGION env variable")
      set_region(AWS_DEFAULT_REGION)
      return true
    else
      ngx.log(ngx.DEBUG, "no AWS_DEFAULT_REGION env variable")
    end

    if ECS_CONTAINERMETADATA_URI_V4 then
      ngx.log(ngx.DEBUG, "detecting AWS region from ECS_CONTAINERMETADATA_URI_V4 env variable")
      local metadata, err = Utils.getECSTaskMetadata("/task", "V4")
      if not metadata then
        ngx.log(ngx.DEBUG, "failed getting ECS metdata V4: ", err)
      else
        set_region(parse_region_from_availability_zone(metadata.AvailabilityZone))
        return true
      end
    else
      ngx.log(ngx.DEBUG, "no ECS_CONTAINERMETADATA_URI_V4 env variable")
    end

    if ECS_CONTAINERMETADATA_URI_V3 then
      ngx.log(ngx.DEBUG, "detecting AWS region from ECS_CONTAINERMETADATA_URI env variable")
      local metadata, err = Utils.getECSTaskMetadata("/task", "V3")
      if not metadata then
        ngx.log(ngx.DEBUG, "failed getting ECS metdata V4: ", err)
      else
        set_region(parse_region_from_availability_zone(metadata.AvailabilityZone))
        return true
      end
    else
      ngx.log(ngx.DEBUG, "no ECS_CONTAINERMETADATA_URI env variable")
    end

    ngx.log(ngx.DEBUG, "detecting AWS region from IDMSv2 metadata")
    local region, err = Utils.getIDMSMetadata("/latest/meta-data/placement/region", "V2")
    if not region then
      ngx.log(ngx.DEBUG, "failed getting IDMS metadata V2: ", err)
    else
      set_region(region)
      return true
    end

    set_region(nil, "unable to detect AWS region, all options failed")
    return detected_region, detected_error
  end


  local SEMAPHORE_TIMEOUT = 60
  local sema

  local function detect_region_locked()
    local need_lock do
      -- in init and init_worker we can't use semaphores, but there also is
      -- no need for them.
      local phase = ngx.get_phase()
      need_lock = not (phase == "init" or phase == "init_worker")
    end

    if need_lock and sema then
      -- semaphore exists, so someone else is detecting already, wait for that
      ngx.log(ngx.DEBUG, "detect AWS region; wait for other thread result")
      local ok, err = sema:wait(SEMAPHORE_TIMEOUT)
      if not ok then
        return "waiting for semaphore failed: " .. tostring(err)
      end
      return true
    end

    if need_lock then
      -- no semaphore, so create it and do the detection
      local err
      sema, err = semaphore:new(0)
      if not sema then
        return nil, "creating semaphore failed: " .. err
      end
    end

    local ok, err = detect_region()

    if need_lock then
      -- release all waiting threads
      sema:post(math.huge)
      sema = nil
    end

    return ok, err
  end


  --- Auto detects the current AWS region.
  -- It will try the following options (in order);
  --
  -- 1. environment variable `AWS_REGION`
  -- 2. environment variable `AWS_DEFAULT_REGION`
  -- 3. ECS metadata V4 (parse region from "AvailabilityZone") if the environment
  --    variable `ECS_CONTAINERMETADATA_URI_V4` is available
  -- 4. ECS metadata V3 (parse region from "AvailabilityZone") if the environment
  --    variable `ECS_CONTAINERMETADATA_URI` is available
  -- 5. IDMSv2 metadata
  --
  -- The IDMSv2 call makes a call to an IP endpoint, and hence could timeout
  -- (timeout is 5 seconds) if called on anything not being an EC2 or EKS instance.
  --
  -- Note: the result is cached so any consequtive calls will not perform any IO.
  -- @return region, or nil+err
  function Utils.getCurrentRegion()
    if not detected then
      local ok, err = detect_region_locked()
      if not ok then
        ngx.log(ngx.ERR, "failed detecting current AWS region: ", err)
        return nil, "failed detecting current AWS region: " .. tostring(err)
      end
    end

    return detected_region, detected_error
  end
end

return Utils
