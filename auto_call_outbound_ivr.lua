--JSON = (loadfile "/etc/freeswitch/scripts/JSON.lua")()
JSON = (loadfile "/usr/local/freeswitch/scripts/JSON.lua")()
callenumber = argv[1]
-- callenumber = "+84"..string.sub(argv[1], 2);

variable_string = argv[2]

callerIdNumber = argv[3]
if callerIdNumber == nil then
  callerIdNumber = "2432007362"
end

call_id = argv[4]
if call_id == nil then
  call_id = ""
end

server_ip = argv[5]
if server_ip == nil then
  server_ip = "113.191.37.250:5060"
end

fsname = "[" .. callenumber .. "] AUTO_CALL_MBF_TESSTTTT_API >>>> "
fileExt = ".wav"
DTMF = "-"

url_api_vbee_dtmf = argv[6]
if url_api_vbee_dtmf == nil then
  url_api_vbee_dtmf = "https://api-dev.vbeecore.com/api/ezcall/event_dtmf post"
end
if string.sub(url_api_vbee_dtmf, -4) ~= "post" then
  url_api_vbee_dtmf = url_api_vbee_dtmf .. " post"
end

ringing_timeout = argv[7]
if ringing_timeout == nil then
  ringing_timeout = ""
else
  ringing_timeout = ringing_timeout + 5
end

freeswitch.consoleLog(
  "info",
  fsname ..
    " Bat dau SCRIPT: AUTO_CALL_OUTBOUND_IVR.lua variable_string :" ..
      variable_string ..
        " \n url_api_vbee_dtmf= " .. url_api_vbee_dtmf .. "\n ringing_timeout= " .. ringing_timeout .. "\n"
)

api = freeswitch.API()

local backdaipplan = JSON:decode(variable_string)
dialplan = JSON:decode(variable_string)
dialplan.back = backdaipplan

campaign_id = dialplan.campaign_id
if campaign_id == nil then
  campaign_id = ""
end

-- g_RecordDir = "/usr/local/freeswitch/sounds/record/";
g_RecordDir = "/var/lib/freeswitch/recordings/"

uuid = api:executeString("create_uuid")
if call_id == nil then
  call_id = uuid
end

local timeRecord = os.date("%H%M%S")
local dateRecord = os.date("%Y%m%d")
local timePath = os.date("%Y/%m/%d")
record_name = "Vbee_" .. campaign_id .. "_" .. callenumber .. "_" .. os.date("%Y%m%d") .. "_" .. uuid .. fileExt
recordPath = timePath .. "/" .. record_name
customer_record_path = g_RecordDir.."read_"..recordPath

sleep_before_hangup = 1000
before_hangup = ""

local_ip = server_ip
if callerIdNumber == "0794015310" or callerIdNumber == "0904656845" then
  local_ip = "43.239.223.35"
end

-- dialA = "{url_api_vbee_dtmf="..url_api_vbee_dtmf..",record_path="..recordPath..",call_id="..call_id..",origination_uuid="..uuid..",ignore_early_media=true,origination_caller_id_number="..callerIdNumber..",effective_caller_id_number="..callerIdNumber..",call_timeout=20}sofia/internal/"..callenumber.."@"..server_ip;
dialA =
  "{url_api_vbee_dtmf=" ..
  url_api_vbee_dtmf ..
    ",record_path=" ..
      recordPath ..
        ",call_id=" ..
          call_id ..
            ",origination_uuid=" ..
              uuid ..
                ",ignore_early_media=true,origination_caller_id_number=" ..
                  callerIdNumber ..
                    ",effective_caller_id_number=" ..
                      callerIdNumber ..
                        ",call_timeout=" ..
                          ringing_timeout ..
                            ",originate_timeout=" ..
                              ringing_timeout .. ",customer_record_path=" .. customer_record_path .. ",sip_h_Call-ID=" .. record_name .. ",sip_h_X-Answer=helloworld" ..
				"}sofia/internal/" .. callenumber .. "@" .. local_ip
-- dialA = "{url_api_vbee_dtmf="..url_api_vbee_dtmf..",record_path="..recordPath..",call_id="..call_id..",origination_uuid="..uuid..",ignore_early_media=true,origination_caller_id_number="..callerIdNumber..",effective_caller_id_number="..callerIdNumber..",call_timeout=20}sofia/internal/9"..callenumber.."@123.31.36.64"
session = freeswitch.Session(dialA)

msisdn = callenumber

call_direction = "outbound"
waitingTimeForInput = 5000

function writelog(level, content)
  freeswitch.consoleLog(level, "AUTO_CALL_NEXT =========>>>> " .. content .. "\n")
end

function split(str, sep)
  local sep,
    fields = sep or ":", {}
  local pattern = string.format("([^%s]+)", sep)
  string.gsub(
    str,
    pattern,
    function(c)
      fields[#fields + 1] = c
    end
  )
  return fields
end

function processHangUp(reason)
  freeswitch.consoleLog("info", fsname .. " call out action  hangup :" .. reason .. " \n")
  session:hangup()
end

local char_to_hex = function(c)
  return string.format("%%%02X", string.byte(c))
end

local function urlencode(url)
  if url == nil then
    return
  end
  url = url:gsub("\n", "\r\n")
  url = url:gsub("([^%w ])", char_to_hex)
  url = url:gsub(" ", "+")
  return url
end

function encodeUrl(str)
  if (str) then
    str = string.gsub(str, "\n", "\r\n")
    str =
      string.gsub(
      str,
      "([^%w ])",
      function(c)
        return string.format("%%%02X", string.byte(c))
      end
    )
    str = string.gsub(str, " ", "+")
  end
  return str
end

function decodeURI(s)
  if (s) then
    s =
      string.gsub(
      s,
      "%%(%x%x)",
      function(hex)
        return string.char(tonumber(hex, 16))
      end
    )
  end
  return s
end

local hex_to_char = function(x)
  return string.char(tonumber(x, 16))
end

local urldecode = function(url)
  if url == nil then
    return
  end
  url = url:gsub("+", " ")
  url = url:gsub("%%(%x%x)", hex_to_char)
  return url
end

function requestAPIAsyn(requestFunction, requestParams, hasCallback)
  local requestUrl = requestFunction
  if string.sub(requestUrl, -4) ~= "post" then
    requestUrl = requestUrl .. " post "
  end

  if (requestParams ~= nil and type(requestParams) == "table") then
    local paramsUrl = ""
    for k, v in pairs(requestParams) do
      if (paramsUrl == "") then
        paramsUrl = k .. "=" .. v
      else
        paramsUrl = paramsUrl .. "&" .. k .. "=" .. v
      end
    end
    requestUrl = requestUrl .. paramsUrl
  end

  requestUrl = requestUrl .. "&event_timestamp=" .. (os.time() * 1000)

  if hasCallback ~= nil then
    freeswitch.consoleLog("info", fsname .. "  >>> CALL API WiTH UUID >> : " .. requestUrl .. " " .. uuid)
    api:executeString("luarun http_async_callback.lua " .. requestUrl .. " " .. uuid)
  else
    freeswitch.consoleLog("info", fsname .. "  >>> CALL API >> : " .. requestUrl)
    api:executeString("luarun http_async_callback.lua " .. requestUrl)
  end
end

function excute_bridge_mobile(callee_id_number)
  -- bắn sự kiện kết nối tổng đài viên để bên nhận sự kiện nghe máy biết
  freeswitch.consoleLog("info", "PREPARING OPEN BRIDGE CONNECT TO PHONE NUMBER: " .. callee_id_number .. "\n")
  --freeswitch.consoleLog("info",fsname.." excute_bridge_mobile :"..callee_id_number.."\n");
  session:execute("set", "ignore_early_media=true")
  session:execute("set", "instant_ringback=true")
  --	session:execute("set","transfer_ringback=local_stream://default");
  --	session:execute("set","ringback=local_stream://default");

  session:execute(
    "set",
    "transfer_ringback=file_string:///etc/freeswitch/sounds/music/8000/suite-espanola-op-47-leyenda.wav"
  )
  session:execute("set", "ringback=file_string:///etc/freeswitch/sounds/music/8000/ponce-preludio-in-e-major.wav")

  session:execute("set", "hangup_after_bridge=true")
  session:execute("set", "inherit_codec=true")
  session:execute("set", "ignore_display_updates=true")
  session:execute("set", "call_direction=outbound")
  session:execute("set", "continue_on_fail=true")
  session:execute("unset", "call_timeout")
  session:execute("set", "Caller-Caller-ID-Name=" .. callerIdNumber)
  session:execute("set", "Caller-Caller-ID-Number=" .. callerIdNumber)
  session:execute("set", "origination_caller_id_number=" .. callerIdNumber)
  session:execute("set", "effective_caller_id_number=" .. callerIdNumber)
  session:execute("set", "Caller-Callee-ID-Name=" .. callerIdNumber)
  session:execute("set", "Caller-Callee-ID-Number=" .. callerIdNumber)

  session:execute("set", "callee_id_number=" .. callee_id_number)
  -- session:execute("bridge","sofia/internal/"..callee_id_number.."@"..server_ip);
  session:execute(
    "bridge",
    "{url_api_vbee_dtmf=" ..
      url_api_vbee_dtmf ..
        ",record_path=" ..
          recordPath ..
            ",call_id=" ..
              call_id ..
                ",connect_operator=true,callee_id=" ..
                  callee_id_number ..
                    ",call_timeout=" ..
                      ringing_timeout ..
                        ",originate_timeout=" ..
                          ringing_timeout .. "}sofia/external/" .. callee_id_number .. "@" .. server_ip
  )
  local originate_disposition = session:getVariable("originate_disposition")
  freeswitch.consoleLog("info", fsname .. "  Bridged originate_disposition :" .. originate_disposition .. "\n")
  if
    originate_disposition == "USER_NOT_REGISTERED" or originate_disposition == "USER_BUSY" or
      originate_disposition == "NO_USER_RESPONSE" or
      originate_disposition == "NO_ANSWER" or
      originate_disposition == "CALL_REJECTED"
   then
    freeswitch.consoleLog("info", fsname .. "  Bridged originate_disposition " .. originate_disposition .. " \n")
    -- play thông báo user not regis
    processHangUp(originate_disposition)
  end
  return originate_disposition
end

function myHangupHook(s, status, arg)
  freeswitch.consoleLog("info", fsname .. "  myHangupHook STATUS: " .. status .. " \n")

  --	local event_timestamp = (os.time()*1000);
  --	local requestUrl = url_api_vbee_dtmf.." call_id="..call_id.."&key=-&state=hangup&disposition="..status.."&recording_path="..recordPath.."&uuid="..uuid.."&event_timestamp="..event_timestamp;
  --	local result = api:execute("curl", requestUrl);
  --	freeswitch.consoleLog("info", fsname.."  hangup insertLogCDR: "..requestUrl.." RESULT = "..result);

  -- local record1 = api:executeString("uuid_record " .. uuid .. " stop "..g_RecordDir..recordPath)
  -- freeswitch.consoleLog('info',"STOP RECORD ["..g_RecordDir..recordPath.."] :::: ["..event_timestamp.." \n");
end

function checkContinuous(plan)
  if (plan["continuous"] ~= nil) then
    freeswitch.consoleLog("info", " [" .. msisdn .. "] >>>>>>>> XU LY CONTINUOUS >>> >>>>>>\n")
    local result = process(plan["continuous"])
  end
end

loopcount = 0
max_repeat = 2
function process(plan)
  local planDigit = nil
  -- check max repeat of current plan
  if (loopcount > max_repeat) then
    planDigit = {}
    if (plan["start_end_script"] ~= nil) then
      freeswitch.consoleLog("info", "LOOPCOUNT > MAX_REPEAT (" .. loopcount .. " > " .. max_repeat .. ") " .. "\n")
      planDigit.start = plan["start_end_script"]
      planDigit.playback = true
      planDigit.terminators = "none"
      planDigit.timeout = 1
      loopcount = 0
      process(planDigit)
      return 1
    end
    return 1
  end
  freeswitch.consoleLog("info", JSON:encode(plan) .. "\n")
  -- if (plan["greeting"] ~= nil) then
  --   session:execute("playback", plan["greeting"])
  --   local sleep_after_greeting = 500
  --   if (plan["sleep_after_greeting"] ~= nil) then
  --     sleep_after_greeting = tonumber(plan["sleep_after_greeting"])
  --     if (sleep_after_greeting == 0) then
  --       sleep_after_greeting = 500
  --     end
  --   end
  --   session:sleep(sleep_after_greeting)
  -- end

  if plan["repeat_idx"] == nil then
    plan["repeat_idx"] = 1
  else
    plan["repeat_idx"] = plan["repeat_idx"] + 1
  end

  writelog("debug", " Bat dau process PLAN " .. uuid .. "\n ")

  local result = 0

  local waitingTimeForInput = 5000

  if (plan["before_hangup"] ~= nil) then
    before_hangup = plan["before_hangup"]
  end

  if (plan["sleep_before_hangup"] ~= nil) then
    sleep_before_hangup = plan["sleep_before_hangup"]
  end

  if (plan["stop"] ~= nil and plan["stop"] == true) then
    return 1
  end

  if (plan["time_wait_input"] ~= nil) then
    waitingTimeForInput = tonumber(plan["time_wait_input"]) * 1000
    if (waitingTimeForInput == 0) then
      waitingTimeForInput = 1
    end
  end

  if (plan["start"] ~= nil) then
    local i = 0
    local repeat_idx = 0
    if (plan["repeat"] ~= nil) then
      repeat_idx = tonumber(plan["repeat"])
    end

    while (i < repeat_idx + 1) do
      local delay_time = 100
      if (plan["delay_start"] ~= nil) then
        delay_time = tonumber(plan["delay_start"])
        if (delay_time == 0) then
          delay_time = 100
        end
      end
      session:sleep(delay_time)

      freeswitch.consoleLog(
        "info",
        " [" .. msisdn .. "] REPEAT >>>>>>>>[" .. i .. "] [" .. repeat_idx .. "] :::: >>>>>>\n"
      )

      if (not session:ready()) then
        return 1
      end
      local recog = plan["recog"]
      local asr = plan["asr"]

      local min_digits = 0
      if (plan["min_digits"] ~= nil) then
        min_digits = tonumber(plan["min_digits"])
      end

      local max_digits = 1
      if (plan["max_digits"] ~= nil) then
        max_digits = tonumber(plan["max_digits"])
      end

      local tries = 1
      if (plan["tries"] ~= nil) then
        tries = tonumber(plan["tries"])
      end

      local timeout = 1
      if (plan["timeout"] ~= nil) then
        timeout = tonumber(plan["timeout"])
      end

      local playback = nil
      if (plan["playback"] ~= nil) then
        playback = plan["playback"]
      end
      -- plan["playback"] = "true"
      -- for i = 1, 9, 1 do
      --   if (plan["" .. i] ~= nil) then
      --     plan["playback"] = nil
      --     break
      --   end
      -- end

      local terminators = ""
      if (plan["terminators"] ~= nil) then
        terminators = plan["terminators"]
      end

      local digit_timeout = 1
      if (plan["digit_timeout"] ~= nil) then
        digit_timeout = plan["digit_timeout"]
      end

      local callback = ""
      if (plan["callback"] ~= nil) then
        callback = plan["callback"]
      end

      local invalid_file = ""
      if (plan["invalid_file"] ~= nil) then
        invalid_file = plan["invalid_file"]
      end

      local valid_digits = ""
      if (plan["valid_digits"] ~= nil) then
        valid_digits = plan["valid_digits"]
      end

      local retryError = 1
      if (plan["retry_error"] ~= nil) then
        retryError = plan["retry_error"]
      end

      local currentRetryError = 0
      if (plan["current_retry_error"] ~= nil) then
        currentRetryError = plan["current_retry_error"]
      end

      session:flushDigits()
      session:setVariable("read_terminator_used", nil)
      session:setVariable("playback_terminator_used", nil)

      local digit = ""

      if playback ~= nil and playback == true then
        session:setVariable("playback_terminators", terminators)
        session:execute("playback", plan["start"])
        digit = session:getVariable("playback_terminator_used")

        if digit == nil or digit == "" then
          local digitTerminators = ""
          if max_digits > 1 then
            digitTerminators = terminators
          end
          digit = session:getDigits(max_digits, digitTerminators, timeout, timeout, timeout)

          if digit ~= nil and digit ~= "" and plan["validate"] ~= nil then
            if string.match(digit, plan["validate"]) == nil then
              freeswitch.consoleLog(
                "info",
                " >>>>>>>>[" .. msisdn .. "] DIGIT INPUT KHONG MATCH VOI VALIDATE PARTEN \n"
              )
              digit = "wrong_input"
            end
          end
        end
      else
        freeswitch.consoleLog(
          "info",
          " >>>>>>>>[" ..
            msisdn ..
              "] BEGIN PLAY FILE " ..
                min_digits ..
                  " - " .. max_digits .. " - " .. tries .. " - " .. timeout .. " - " .. digit_timeout .. "] \n"
        )
        digit =
          session:playAndGetDigits(
          min_digits,
          max_digits,
          tries,
          timeout,
          terminators,
          plan["start"],
          "",
          valid_digits,
          "",
          digit_timeout
        )
        freeswitch.consoleLog("info", " >>>>>>>> digit-" .. digit .. "- \n")
        if digit ~= nil and digit ~= "" and plan["validate"] ~= nil then
          if string.match(digit, plan["validate"]) == nil then
            freeswitch.consoleLog("info", " >>>>>>>>[" .. msisdn .. "] DIGIT INPUT KHONG MATCH VOI VALIDATE PARTEN \n")
            digit = "wrong_input"
          end
        end

        if digit == nil or digit == "" then
          digit = session:getVariable("read_terminator_used")
        end
      end

      if digit == nil then
        digit = ""
      end

      if digit ~= nil and digit ~= "" and digit ~= "wrong_input" then
        if plan["terminator_mush_used"] ~= nil and plan["terminator_mush_used"] == "true" then
          if session:getVariable("read_terminator_used") == nil then
            freeswitch.consoleLog("info", " >>>>>>>>[" .. msisdn .. "] KHONG NHAN DC TERMINATOR NEN CLEAN DIGIT \n")
            digit = "no_terminator"
          else
            freeswitch.consoleLog(
              "info",
              " >>>>>>>>[" .. msisdn .. "] VAB CO TEMINATOR: " .. session:getVariable("read_terminator_used") .. "\n"
            )
          end
        end
      end

      freeswitch.consoleLog(
        "info",
        " >>>>>>>>[" ..
          msisdn ..
            "] DIGIT NHAN DC [" ..
              callback ..
                "-" ..
                  min_digits ..
                    " - " .. max_digits .. " - " .. tries .. " - " .. timeout .. "] :::: >>>>>>" .. digit .. "\n"
      )

      if (digit ~= nil and digit ~= "") then
        if (callback ~= "") then
          -- if (apiData ~= nil and type(apiData) == "table") then
          --	apiData.back = plan;
          --	result = process(apiData);
          --	if (result == 1) then
          --		return 1
          --	end
          -- end
          freeswitch.consoleLog("info", " [" .. msisdn .. "] >>>>>>>> XU LY CALLBACK >>>>>>\n")
          local params = {}
          params["uuid"] = uuid
          params["caller_id"] = msisdn
          params["event"] = "input"
          params["date"] = dateRecord
          params["digit"] = digit
          params["call_id"] = call_id
          params["did_number"] = destination_number
          params["event_timestamp"] = (os.time() * 1000)

          local apiData = requestAPIAsyn(callback, params)
        else
          local requestUrl =
            url_api_vbee_dtmf ..
            " caller_id=" ..
              callenumber ..
                "&call_id=" .. call_id .. "&key=" .. digit .. "&state=DTMF&disposition=ANSWERED&uuid=" .. uuid
          requestUrl = requestUrl .. "&event_timestamp=" .. api:getTime()
          if plan["node_id"] ~= nill then
	    requestUrl = requestUrl .. "&node_id=" .. plan["node_id"]
	  end
          freeswitch.consoleLog("info", fsname .. "  DTMF INSERT LOG : " .. requestUrl)
          api:executeString("luarun http_async.lua " .. requestUrl)
        end

        DTMF = DTMF .. digit .. "-"
        session:setVariable("DTMF", DTMF)

        if (plan[digit .. "_" .. plan["repeat_idx"]] ~= nil) then
          planDigit = plan[digit .. "_" .. plan["repeat_idx"]]
        else
          if (plan["" .. digit] ~= nil) then
            planDigit = plan["" .. digit]
          elseif (plan["start_wrong_input"] ~= nil and plan["start_end_script"] ~= nil) then
            -- check wrong input
            currentRetryError = currentRetryError + 1
            planDigit = plan
            freeswitch.consoleLog("info", " >>>>>>>>[" .. msisdn .. "] DIGIT WRONG INPUT SCRIPT \n")
            planDigit.origin_start = plan["start"]
            if (plan["timeout"] ~= nil) then
              planDigit.origin_timeout = plan["timeout"]
            end
            planDigit.start = plan["start_wrong_input"]
            planDigit.current_retry_error = currentRetryError
            if (currentRetryError > retryError) then
              freeswitch.consoleLog("info", " >>>>>>>>[" .. msisdn .. "] CHUYEN SANG END SCRIPT \n")
              planDigit.origin_start = plan["start_end_script"]
              planDigit.start = plan["start_wrong_input"]
              planDigit.is_end = true
              planDigit.playback = true
              planDigit.terminators = "none"
            end
            planDigit.timeout = 1
            result = process(planDigit)
            return 1
          end
        end

        if planDigit == nil or planDigit == "" then
          if (plan["default"] ~= nil) then
            freeswitch.consoleLog("info", fsname .. " >>>>>>>> Plan Default >>>>>>\n")
            planDigit = plan["default"]
          end
        end

        if (type(planDigit) == "table") then
          loopcount = 0
          if (planDigit["next"] ~= nil) then
            freeswitch.consoleLog("info", fsname .. " >>>>>>>> XU LY NEXT >>>>>>\n")
            local params = {}
            params["uuid"] = uuid
            params["caller_id"] = msisdn
            params["event"] = "input"
            params["date"] = dateRecord
            params["digit"] = digit
            params["call_id"] = call_id
            params["did_number"] = destination_number
            params["event_timestamp"] = (os.time() * 1000)

            local apiData = nil

            if planDigit["next_notice"] ~= nil and planDigit["next_notice"] ~= "" then
              session:execute("playback", planDigit["next_notice"])
            end

            requestAPIAsyn(planDigit["next"], params, "TRUE")

            if planDigit["next_moh"] ~= nil and planDigit["next_moh"] ~= "" then
              session:streamFile(planDigit["next_moh"])
            else
              session:streamFile("/etc/freeswitch/sounds/ivr/nhacnen.wav")
            end

            local curl_response = session:getVariable("curl_response_data")
            freeswitch.consoleLog("info", fsname .. " >>>>>> curl_response:" .. curl_response .. "\n")
            if (curl_response ~= nil and curl_response ~= "") then
              apiData = JSON:decode(curl_response)
            end

            if (apiData ~= nil and type(apiData) == "table") then
              apiData.back = plan
              result = process(apiData)
              if (result == 1) then
                checkContinuous(plan)
                return 1
              end
            end
          else
            freeswitch.consoleLog("info", fsname .. " >>>>>>>> XU LY KHONG PHAI NEXT >>>>>>\n")
            -- planDigit.back = plan
            result = process(planDigit)
            if (result == 1) then
              checkContinuous(plan)
              return 1
            end
          end
        else
          if (planDigit ~= nil) then
            -- session:execute("playback", planDigit)
            -- local delay_before_playback = 1000
            -- if (plan["delay_before_playback"] ~= nil) then
            --   delay_before_playback = tonumber(plan["delay_before_playback"])
            --   if (delay_before_playback == 0) then
            --     delay_before_playback = 1000
            --   end
            -- end
            -- session:sleep(delay_before_playback)
            local command,
              number = string.match(planDigit, "(mobile)(.*)")
            if (command ~= nil and number ~= nil and number ~= "") then
              freeswitch.consoleLog("info", " [" .. msisdn .. "] >>>>>>>> CHUYEN TIEP CHO TDV >>>> >>>>>>\n")
              excute_bridge_mobile(number)
              return 1
            end

            -- local regex_forward,
            --   digit_forward = string.match(planDigit, "(forward)(.*)")
            -- if (regex_forward ~= nil and digit_forward ~= nil and digit_forward ~= "") then
            --   freeswitch.consoleLog(
            --     "info",
            --     " [" .. msisdn .. "] >>>>>>>> FORWARD DEN NODE [" .. digit_forward .. "] >>>> >>>>>>\n"
            --   )
            --   planDigit = dialplan["" .. digit_forward]
            --   process(planDigit)
            --   return 1
            -- end

            if (planDigit == "dblback") then
              freeswitch.consoleLog("info", " [" .. msisdn .. "] >>>>>>>> Process Back2x>>>> >>>>>>\n")
              if plan.back ~= nil and plan.back.back ~= nil then
                loopcount = 1
                process(plan.back.back)
                return 1
              end
            end

            if (planDigit == "back") then
              freeswitch.consoleLog("info", " [" .. msisdn .. "] >>>>>>>> Process Back >>>> >>>>>>\n")
              loopcount = 1
              if plan.back ~= nil then
                process(plan.back)
                return 1
              end
            end

            if (planDigit == "home") then
              freeswitch.consoleLog(
                "info",
                " [" .. msisdn .. "] >>>>>>>> Process HOME >>>> >>>>>> " .. planDigit .. "\n"
              )
              loopcount = 1
              process(dialplan)
              return 1
            end

            if (planDigit == "continuous") then
              freeswitch.consoleLog("info", " [" .. msisdn .. "] >>>>>>>> Process CONTINUOUS COMMAND >>>> >>>>>>\n")
              checkContinuous(plan)
              return 1
            end

            if (planDigit == "repeat") then
              loopcount = loopcount + 1
              freeswitch.consoleLog(
                "info",
                " [" .. msisdn .. "] >>>>>>>> Process REPEAT >>>> loopcount: " .. loopcount .. " >>>>>>\n"
              )
              process(plan)
              return 1
            end

            if (planDigit == "exit") then
              freeswitch.consoleLog("info", " [" .. msisdn .. "] >>>>>>>> EXIT >>>> >>>>>>\n")
              return 1
            end
          else
            local invalid = ""
            if (plan["invalid_file_" .. plan["repeat_idx"]] ~= nil) then
              invalid = plan["invalid_file_" .. plan["repeat_idx"]]
            else
              if (plan["invalid_file"] ~= nil) then
                invalid = plan["invalid_file"]
              end
            end
            if (invalid ~= nil and invalid ~= "") then
              if (type(invalid) == "table") then
                invalid.back = plan
                local resul = process(invalid)
                if (result == 1) then
                  checkContinuous(plan)
                  return 1
                end
                return 1
              else
                if (invalid == "exit") then
                  freeswitch.consoleLog(
                    "info",
                    " [" .. msisdn .. "] >>>>>>>> EXIT WHEN NOT MATCH ANY DIGIT >>>> >>>>>>\n"
                  )
                  return 1
                end

                session:execute("playback", plan["invalid_file"])
              end
            end
          end
        end
      else
        -- if (plan["timeout_file"] ~= nil) then
        --   if (plan["timeout_file"] == "exit") then
        --     freeswitch.consoleLog("info", " [" .. msisdn .. "] >>>>>>>> EXIT WHEN TIMEOUT >>>> >>>>>>\n")
        --     return 1
        --   end
        --   session:execute("playback", plan["timeout_file"])
        -- end
        -- check error plan then repeat main script
        if (plan["origin_start"] ~= nil) then
          freeswitch.consoleLog("info", fsname .. " >>>>>>>> CHUYEN SANG MAIN SCRIPT >>>>>>\n")

          planDigit = plan
          if (plan["is_end"] == true) then
            planDigit = {}
            planDigit.timeout = 1
            planDigit.playback = true
            planDigit.terminators = "none"
          elseif (plan["origin_timeout"] ~= nil) then
            planDigit.timeout = plan["origin_timeout"]
          end
          planDigit.start = plan["origin_start"]
          planDigit.origin_start = nil
          planDigit.origin_timeout = nil
          process(planDigit)
          return 1
        end

        -- check no response when timeout
        if
          (digit == "" and plan["start_no_response"] ~= nil and plan["start_end_script"] ~= nil and
            plan["is_end"] ~= true)
         then
          currentRetryError = currentRetryError + 1
          planDigit = plan
          freeswitch.consoleLog("info", " >>>>>>>>[" .. msisdn .. "] BAT DAU NO_RESPONSE SCRIPT \n")
          planDigit.origin_start = plan["start"]
          if (plan["timeout"] ~= nil) then
            planDigit.origin_timeout = plan["timeout"]
          end
          planDigit.start = plan["start_no_response"]
          planDigit.current_retry_error = currentRetryError
          if (currentRetryError > retryError) then
            freeswitch.consoleLog("info", " >>>>>>>>[" .. msisdn .. "] CHUYEN SANG END SCRIPT \n")
            planDigit.origin_start = plan["start_end_script"]
            planDigit.start = plan["start_no_response"]
            planDigit.is_end = true
            planDigit.playback = true
            planDigit.terminators = "none"
          end
          planDigit.timeout = 1
          result = process(planDigit)
          return 1
        end
      end

      freeswitch.consoleLog("info", " [" .. msisdn .. "] >>>>>>>> KET THUC XU LY CHUA BI REPEAT >>>>>>\n")

      i = i + 1

      plan["repeat_idx"] = plan["repeat_idx"] + 1

      -- local delay_before_repeat = 1000
      -- if (plan["delay"] ~= nil) then
      --   delay_before_repeat = tonumber(plan["delay"])
      --   if (delay_before_repeat == 0) then
      --     delay_before_repeat = 1000
      --   end
      -- end
      -- session:sleep(delay_before_repeat)
    end

    if (plan["not_match"] ~= nil) then
      if (plan["not_match"] == "exit") then
        freeswitch.consoleLog("info", " [" .. msisdn .. "] >>>>>>>> EXIT WHEN NOT MATCH ANY DIGIT >>>> >>>>>>\n")
        return 1
      end
      session:execute("playback", plan["not_match"])
    end
  end
  checkContinuous(plan)
  return 1
end

dispoA = "None"

while (session:ready() and dispoA ~= "ANSWER") do
  dispoA = session:getVariable("endpoint_disposition")
  freeswitch.consoleLog("INFO", fsname .. "  Leg A disposition is '" .. dispoA .. "'\n")
end

if (session:ready()) then
  destination_number = session:getVariable("destination_number")
  effective_caller_id_number = callerIdNumber
  sip_from_user = session:getVariable("sip_from_user")
  network_addr = session:getVariable("network_addr")
  context = session:getVariable("context")
  channel_name = session:getVariable("channel_name")
  domain_name = session:getVariable("domain_name")
  client_id = session:getVariable("client_id")
  if client_id == nil or client_id == "" then
    client_id = 1
  end

  freeswitch.consoleLog("info", fsname .. " call_out_action :" .. msisdn .. " domain_name : " .. domain_name .. " \n")
  freeswitch.consoleLog(
    "info",
    fsname .. "  call_out_action effective_caller_id_number : " .. effective_caller_id_number .. " \n"
  )
  freeswitch.consoleLog("info", fsname .. "  call_out_action sip_from_user : " .. sip_from_user .. " \n")

  session:setHangupHook("myHangupHook")
  session:answer()
  
  session:setVariable("RECORD_READ_ONLY","true")
  session:execute("record_session", customer_record_path)
  
  --session:setVariable("RECORD_READ_ONLY","false")
  --session:execute("record_session", g_RecordDir .. recordPath)
  
  session:sleep(1000)

  process(dialplan)

  -- if before_hangup ~= "" then
  --   session:sleep(sleep_before_hangup)
  --   session:execute("playback", before_hangup)
  -- end
  processHangUp("NORMAL_CLEARING")
else -- This means the call was not answered ... Check for the reason
  local obCause = session:hangupCause()
  freeswitch.consoleLog("WARNING", fsname .. "  >>>>>=====>>>>> session:hangupCause() = " .. obCause .. "\n")
end


`