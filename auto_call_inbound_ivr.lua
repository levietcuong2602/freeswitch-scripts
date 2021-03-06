JSON = (loadfile "/usr/local/freeswitch/scripts/JSON.lua")();

package.path = "/usr/share/lua/5.2/?.lua;/usr/local/freeswitch/scripts/utils/?.lua;" .. package.path
pcall(require, "luarocks.require");

local redis = require "redis";

api = freeswitch.API();
uuid = session:getVariable("uuid");

client_redis = redis.connect("127.0.0.1", 6379);

-- caller_number = session:getVariable("caller_id_number")-- caller_number = session:getVariable("caller_id_number");
-- sip_number = session:getVariable("destination_number");
-- sip_number = session:getVariable("destination_number");
caller_number = "0395468807";
sip_number = "0913647743";
-- init variables
call_id = "";
server_ip = "";
variable_string = "";
file_ext = ".wav";
DTMF = "-";
url_callback = "";
url_request = "https://cp-dev.aicallcenter.vn/api/contacts/init-inbound";
url_api_vbee_dtmf = "https://pbx-zone0-api.vbeecore.com/api/v1/calls/callback";

local time_record = os.date("%H%M%S");
local date_record = os.date("%Y%m%d");
local time_path = os.date("%Y/%m/%d");

g_record_dir = "/var/lib/freeswitch/recordings/";
record_path = time_path .. "/" .. string.sub(caller_number, 2) .. "-" .. uuid .. file_ext;
fsname = "[" .. caller_number .. "] AUTO_CALL_INBOUND >>>> ";

-- define function
function requestAPIAsyn(request_function, request_params, has_call_back)
    local request_url = request_function
    if string.sub(request_url, -4) ~= "post" then
        request_url = request_url .. " post "
    end

    if (request_params ~= nil and type(request_params) == "table") then
        local params_url = ""
        for k, v in pairs(request_params) do
            if (params_url == "") then
                params_url = k .. "=" .. v
            else
                params_url = params_url .. "&" .. k .. "=" .. v
            end
        end
        request_url = request_url .. params_url
    end

    request_url = request_url .. "&event_timestamp=" .. (os.time() * 1000)

    freeswitch.consoleLog("info", fsname .. "  >>> CALL API >> : " .. request_url)
    local response = api:execute("curl", request_url)
    return response
end

function getIVR(url_request, caller_id, callee_id)
    local params = {}
    params["caller_id"] = caller_id
    params["callee_id"] = callee_id
    local response = requestAPIAsyn(url_request, params)
    freeswitch.consoleLog("info", "AUTO_CALL_INBOUND_IVR_API ==> IVR: " .. response)
    response = JSON:decode(response)
    if (response["status"] == 1) then
        variable_string = JSON:encode(response["results"]["dial_plan"])
        url_callback = response["results"]["call_back"]
        server_ip = response["results"]["sip_ip"]
    end
end

function includes(tables, value)
    for _, v in ipairs(tables) do
        if (v == value) then
            return true;
        end
    end
    return false;
end

function executeBrigdeMobile(callee_id_number)
    freeswitch.consoleLog("info", "Prepare open bridge connect to phone number " .. callee_id_number .. "\n");

    -- TODO
    return false;
end

function executeBrigdeSoftphone(callee_id_number)
    freeswitch.consoleLog("info", "Prepare open bridge connect to softphone " .. callee_id_number .. "\n");

    session:execute("set", "ignore_early_media=true");
    session:execute("set", "instant_ringback=true");
    session:execute("set", "transfer_ringback=file_string:///usr/local/freeswitch/sounds/music/8000/suite-espanola-op-47-leyenda.wav");
    session:execute("set", "ringback=file_string:///usr/local/freeswitch/sounds/music/8000/ponce-preludio-in-e-major.wav");
    session:execute("set", "hangup_after_bridge=true");
    session:execute("set", "inherit_codec=true");
    session:execute("set", "ignore_display_updates=true");
    session:execute("set", "call_direction=outbound");
    session:execute("set", "continue_on_fail=true");
    session:execute("set", "call_direction=outbound");
    session:execute("set", "continue_on_fail=true");
    session:execute("set", "bridge_filter_dtmf=true");
    session:setVariable("effective_caller_id_number", destination_number);
    session:setVariable("origination_caller_id_number", destination_number)
    session:execute("set", "bridge_terminate_key=*") -- set phim bam de nguoi dung back lại khi dang bridge
    session:execute("set", "call_timeout=30") -- set phim bam de nguoi dung back lại khi dang brid

    local string_bridge = "{url_api_vbee_dtmf=" .. url_api_vbee_dtmf ..
        ",record_path=" .. record_path ..
        ",call_id=" .. call_id ..
        ",connect_operator=true" .. 
        ",callee_id=" .. callee_id_number ..
        "}sofia/internal/" .. callee_id_number .. "@192.168.0.103:5060";
    freeswitch.consoleLog("info", fsname .. "execute bridge " .. string_bridge);
    session:execute("bridge", string_bridge);

    local FAILURE_HANGUP_CAUSES = {"USER_BUSY", "USER_NOT_REGISTERED", "NO_USER_RESPONSE", "NO_ANSWER", "CALL_REJECTED"};
    local originate_disposition = session:getVariable("originate_disposition"); -- get code return hangup cause
    local is_bridge_failure = includes(FAILURE_HANGUP_CAUSES, originate_disposition);
    return not is_bridge_failure;
end

function executeBrigde(callee_id_number)
    -- connect mobile
    if (string.match(callee_id_number, "-") == nil) then
        return executeBrigdeMobile(callee_id_number);
    end

    -- connect softphone
    return executeBrigdeSoftphone(callee_id_number);
end

loop_count = 0;
max_repeat = 2;
function process(plan)
    -- check max repeat of current dialplan
    local plan_digit = nil;
    if (loop_count > max_repeat) then
        if (plan["start_end_script"] ~= nil) then
            plan_digit.start = plan["start_end_script"];
            plan_digit.playback = true;
            plan_digit.terminators = "none";
            plan_digit.timeout = 1;

            loop_count = 0;
            process(plan_digit);
            return 1;
        end
        return 1;
    end
    -- process dialplan
    freeswitch.consoleLog("debug", "AUTO_CALL_INBOUND ==> Start process dialplan " ..  uuid .. "\n");
    if (plan["start"]) then
        local index = 0;
        local repeat_number = 0;
        if (plan["repeat"] ~= nil) then
            repeat_number = tonumber(plan["repeat"]);
        end

        while (index < repeat_number + 1) do
            if (not session:ready()) then
                return 1;
            end
            -- Break time between 2 loop
            local deplay_start_time = 100;
            if (plan["delay_start_time"] ~= nil) then
                deplay_start_time = tonumber(plan["delay_start_time"]);
                if (deplay_start_time == 0) then
                    deplay_start_time = 100;
                end
            end
            session:sleep(deplay_start_time);
            freeswitch.consoleLog("info", "[" .. caller_number .. "] REPEAT >>>>>>>>> [" .. index .. "][" .. repeat_number .. "]");
            -- play audio and get digits
            local min_digits = 0; -- minimum number of digits
            if (plan["min_digits"] ~= nil) then
                min_digits = tonumber(plan["min_digits"]);
            end
            local max_digits = 1; -- maximum number of digits
            if (plan["max_digits"] ~= nil) then
                max_digits = tonumber(plan["max_digits"]);
            end
            local tries = 1; -- number of tries for the audio play
            if (plan["tries"] ~= nil) then
                tries = tonumber(plan["tries"]);
            end
            local timeout = 1; -- number of milliseconds to wait for a dial when audio playback end
            if (plan["timeout"] ~= nil) then
                timeout = tonumber(plan["timeout"]);
            end
            local terminators = ""; -- digits used to end input
            if (plan["terminators"] ~= nil) then
                terminators = plan["terminators"];
            end
            local digit_timeout = 1; -- number of millisecond allowed between digits
            if (plan["digit_timeout"] ~= nil) then
                digit_timeout = tonumber(plan["digit_timeout"]);
            end
            local valid_digits = ""; -- Regular expression to math digits
            if (plan["valid_digits"] ~= nil) then
                valid_digits = plan["valid_digits"];
            end        

            -- reset keypress on session
            session:flushDigits();
            session:setVariable("read_terminator_used", nil);
            session:setVariable("playback_terminator_used", nil);
            -- playback and end call
            local playback = nil; -- Sound file to play prompt for digits to dialed by caller
            if (plan["playback"] ~= nil) then
                playback = plan["playback"];
            end
            if (playback == true or plan["is_end"] == true) then
                session:setVariable("playback_terminators", terminators);
                session:execute("playback", plan["start"]);
                return 1;
            end
            -- execute play audio and get digits
            freeswitch.consoleLog("info", ">>>>>>>>>>>> [" .. caller_number .. "] Begin Play File Audio [" .. min_digits .. " - " .. max_digits .. " - " .. tries .. " - " .. timeout .. " - " .. terminators .. " - " .. plan["start"] .. " - ".. digit_timeout .. "] >>>>>>>>>>>>\n");
            local digit = "";
            digit = session:playAndGetDigits(
                min_digits,
                max_digits,
                tries, -- max_tries
                timeout,
                terminators,
                plan["start"], -- audio file
                "", -- invalid file to play when digits don't match regex
                valid_digits, -- var_name: channel variable into which valid digits
                "", -- regexp: regular expression to match digits
                digit_timeout
            );
            freeswitch.consoleLog("info", ">>>>>>>>>>>> [" .. caller_number .. "] >>>>>>>>>>>> digit: " .. digit .. " >>>>>>>>>>>>\n");
            if (digit == nil) then
                digit = "";
            end
            freeswitch.consoleLog("info", ">>>>>>>>>>>> [" .. caller_number .. "] Digit Receive [" .. min_digits .. " - " .. max_digits .. " - " .. tries .. " - " .. timeout .. " - " .. digit_timeout .. "]:::>>>>>>>>>>>> " .. digit .. " >>>>>>>>>>>>\n");

            -- số lần tối đa lỗi xảy ra trên 1 node
            local retry_error = 1
            if (plan["retry_error"] ~= nil) then
                retry_error = plan["retry_error"]
            end
            -- số lần lỗi hiện tại trên 1 node
            local current_retry_error = 0
            if (plan["current_retry_error"] ~= nil) then
                current_retry_error = plan["current_retry_error"]
            end
            -- process ivr after digit
            if (digit ~= nil and digit ~= "") then
                -- callback when digit dtmf
                -- TODO call API
                -- correct digit input
                if (plan[digit] ~= nil) then
                    plan_digit = plan[digit];
                elseif (plan["start_wrong_input"] and plan["start_end_script"]) then -- wrong input
                    current_retry_error = current_retry_error + 1;
                    freeswitch.consoleLog("info", ">>>>>>>>>>>> [" .. caller_number .. "] Digit Wrong Input Script >>>>>>>>>>>>\n");

                    plan_digit = plan;
                    plan_digit.origin_start = plan["start"];
                    plan_digit.start = plan["start_wrong_input"];
                    plan_digit.current_retry_error = current_retry_error;
                    plan_digit.timeout = 1; -- Play audio and not listen dial

                    if (plan["timeout"]) then
                        plan_digit.origin_timeout = plan["timeout"];
                    end
                    if (current_retry_error > retry_error) then
                        freeswitch.consoleLog("info", ">>>>>>>>>>>> [" .. caller_number .. "] End Script >>>>>>>>>>>>\n");

                        plan_digit.origin_start = plan["start_end_script"];
                        plan_digit.start = plan["start_wrong_input"];
                        plan_digit.is_end = true; -- as playback: play audio start and end call
                        plan_digit.playback = true; -- Play playback audio start and end call
                        plan_digit.terminators = "none";
                    end

                    process(plan_digit);
                    return 1;
                end

                -- process dial_digits
                if (type(plan_digit) == "table") then
                    loop_count = 0;
                    process(plan_digit);
                    return 1;
                elseif(plan_digit ~= nil) then
                    local command, numbers = string.match(plan_digit, "(mobile)(.*)");

                    -- connect agent csr
                    if (command ~= nil and numbers ~= nil and number ~= "") then
                        freeswitch.consoleLog("info", "[" .. caller_number .. "] >>>>>>>>>>>> Connect To Csr:" .. numbers .. " >>>>>>>>>>>>\n");
                        for phone_operator in string.gmatch(numbers, "([^,]+)") do
                            local result = executeBrigde(phone_operator);
                            if (result == true) then
                                break;
                            end
                        end

                        freeswitch.consoleLog("info", fsname .. " End Process Connect Csr");
                        return 1;
                    end
                    -- plandigit back 2 level
                    if (plan_digit == "dblback") then
                        loop_count = 1;
                        freeswitch.consoleLog("info", "[" .. caller_number .. "] >>>>>>>>>>>> Process Back x2 >>>>>>>>>>>>");
                        if (plan.back ~= nil and plan.back.back ~= nil) then
                            process(plan.back.back);
                            return 1;
                        end
                    end
                    -- plandigit back 1 level
                    if (plan_digit == "back") then
                        loop_count = 1;
                        freeswitch.consoleLog("info", "[" .. caller_number .. "] >>>>>>>>>>>> Process Back x1 >>>>>>>>>>>>");
                        if (plan.back ~= nil) then
                            process(plan.back);
                            return 1;
                        end
                    end
                    -- plandigit back home
                    if (plan_digit == "home") then
                        loop_count = 1;
                        freeswitch.consoleLog("info", "[" ..caller_number .. "] >>>>>>>>>>>> Process Home >>>>>>>>>>>>");
                        process(dialplan);
                        return 1;
                    end
                    -- plandigit repeat
                    if (plan_digit == "repeat") then
                        loop_count = loop_count + 1;
                        freeswitch.consoleLog("info", "[" .. caller_number .. "] >>>>>>>>>>>> Process Repeat Loop_Count: " .. loop_count .. " >>>>>>>>>>>>\n");
                        process(plan);
                        return 1;
                    end
                    -- plandigit end call
                    if (plan_digit == "exit") then
                        freeswitch.consoleLog("info", "[" .. caller_number .. "] >>>>>>>>>>>> Exit >>>>>>>>>>>>\n");
                        return 1;
                    end
                end
            else
                -- exist origin start
                if (plan["origin_start"]) then
                    freeswitch.consoleLog("info", fsname .. ">>>>>>>>>>>>>>>>>> Transfer Main Script >>>>>>>>>>>>>>>>>");

                    plan_digit = plan;
                    plan_digit.start = plan["origin_start"];
                    plan_digit.origin_start = nil;
                    plan_digit.origin_timeout = nil;
                    if (plan["is_end"] == true) then
                        plan_digit = {};
                        plan_digit.timeout = 1;
                        plan_digit.playback = true;
                        plan_digit.terminators = "none";
                    elseif (plan["origin_timeout"] ~= nil) then
                        plan_digit.timeout = plan["origin_timeout"];
                    end
                    process(plan_digit);
                    return 1;
                end
                -- no user response
                if (digit == "" and plan["start_no_response"] ~= nil and plan["start_end_script"] ~= nil and plan["is_end"] ~= true) then
                    current_retry_error = current_retry_error + 1;
                    freeswitch.consoleLog("info", fsname .. ">>>>>>>>>>>>> Start No Response Script >>>>>>>>>>>>>");
                    plan_digit = plan;
                    plan_digit.start = plan["start_no_response"];
                    plan_digit.current_retry_error = current_retry_error;
                    plan_digit.timeout = 1;
                    plan_digit.origin_start = plan["start"];

                    if (plan["timeout"] ~= nil) then
                        plan_digit.origin_timeout = plan["timeout"];
                    end
                    if (current_retry_error > retry_error) then
                        freeswitch.consoleLog("info", fsname .. ">>>>>>>>>>>>> Start End Script >>>>>>>>>>>>>");
                        plan_digit.origin_start = plan["start_end_script"];
                        plan_digit.start = plan["start_no_response"];
                        plan_digit.is_end = true;
                        plan_digit.playback = true;
                        plan_digit.terminators = "none";
                    end

                    process(plan_digit);
                    return 1;
                end
            end

            freeswitch.consoleLog("info", fsname .. " >>>>>>>>>>>> End Process No Repeat >>>>>>>>>>>>>>");
            index = index + 1;
        end
    end

    return 1;
end

-- get ivr from controller
getIVR(url_request, caller_number, sip_number)
-- check valid
if (variable_string == "") then
    hold_music = session:getVariable("hold_music");
    freeswitch.consoleLog("err", "hold_music: " .. hold_music);

    session:answer()
    session:sleep(500)
    session:execute("playback", hold_music)
    session:hangup()
    return
end

freeswitch.consoleLog(
    "info",
    fsname ..
    " Bat dau SCRIPT: \n" .. 
    "- url_api_vbee_dtmf: " .. url_api_vbee_dtmf .."\n" ..
    "- variable_string: " .. variable_string .. "\n" .. 
    "- uuid: " .. uuid .. "\n" .. 
    "- server_ip:" .. server_ip
);
-- parse ivr and create ivr back
dialplan = JSON:decode(variable_string);
dialplan.back = JSON:decode(variable_string);

-- redis
local url_callback_redis = "url_callback_" .. uuid;
local record_path_redis = "record_path_" .. uuid;

client_redis.set(record_path_redis, record_path);
client_redis.set(url_callback_redis, url_callback);
client_redis.set("pbx_callback_redis", url_api_vbee_dtmf);
-- set hangup callback
session:setHangupHook("myHangupHook");
-- answer call
session:answer();
session:execute("record_session", g_record_dir .. record_path);
-- process dialplan
process(dialplan);
