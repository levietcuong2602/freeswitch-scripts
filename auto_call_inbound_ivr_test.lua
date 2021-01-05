JSON = (loadfile "/usr/local/freeswitch/scripts/JSON.lua")();

package.path = "/usr/share/lua/5.2/?.lua;/usr/local/freeswitch/scripts/utils/?.lua;" .. package.path
pcall(require, "luarocks.require");

local redis = require "redis";

api = freeswitch.API();
uuid = session:getVariable("uuid");

client_redis = redis.connect("127.0.0.1", 6379);
local response = client_redis:ping();
freeswitch.consoleLog("info", "check redis ping: " .. string.format("%s", response));
caller_number = session:getVariable("caller_id_number");
sip_number = session:getVariable("destination_number");
-- caller_number = "0395468807";
-- sip_number = "0913647743";
-- init variables
call_id = "";
server_ip = "";
variable_string = "";
file_ext = ".wav";
DTMF = "-";
url_callback = "";
domain_aicc = "https://api-inbound.iristech.club";
-- domain_aicc = " http://e8748740909c.ngrok.io";
url_api_vbee_dtmf = "https://pbx-zone0-api.vbeecore.com/api/v1/calls/callback";
session:setVariable("url_api_vbee_dtmf", url_api_vbee_dtmf);

local time_record = os.date("%H%M%S");
local date_record = os.date("%Y%m%d");
local time_path = os.date("%Y/%m/%d");

g_record_dir = "/var/lib/freeswitch/recordings/";
record_path = time_path .. "/" .. string.sub(caller_number, 2) .. "-" .. uuid .. file_ext;
fsname = "[" .. caller_number .. "] AUTO_CALL_INBOUND >>>> ";

-- define function
function requestAPIAsyn(request_function, request_params, has_call_back)
    local request_url = request_function;
    if string.sub(request_url, -4) ~= "post" then
        request_url = request_url .. " post ";
    end

    if (request_params ~= nil and type(request_params) == "table") then
        local params_url = ""
        for k, v in pairs(request_params) do
            if (params_url == "") then
                params_url = k .. "=" .. v;
            else
                params_url = params_url .. "&" .. k .. "=" .. v;
            end
        end
        request_url = request_url .. params_url;
    end

    request_url = request_url .. "&event_timestamp=" .. (os.time() * 1000);

    freeswitch.consoleLog("info", "Request API URL: " .. request_url);
    local response = api:execute("curl", request_url);
    return response;
end

function getIVR(url_request, caller_id, callee_id)
    local params = {}
    params["caller_id"] = caller_id;
    params["callee_id"] = callee_id;
    local response = requestAPIAsyn(url_request, params);
    freeswitch.consoleLog("info", "AUTO_CALL_INBOUND_IVR_API ==> IVR: " .. response)
    response = JSON:decode(response)
    if (response["status"] == 1) then
        variable_string = JSON:encode(response["result"]["dial_plan"]);;
        url_callback = response["result"]["callback"];
        server_ip = response["result"]["sip_ip"];

        session:setVariable("url_callback", url_callback);
        if (response["result"]["call_id"]) then
            call_id = response["result"]["call_id"];
        end
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

-- TODO
function executeBrigdeMobile(callee_id_number, agent_id)
    freeswitch.consoleLog("info", "Prepare open bridge connect to mobilephone " .. callee_id_number .. "\n");

    session:execute("set", "ignore_early_media=true")
    session:execute("set", "instant_ringback=true")
    session:execute("set","transfer_ringback=" .. session:getVariable("hold_music"))
    session:execute("set", "ringback=" ..session:getVariable("us-ring"))

    session:execute("set", "hangup_after_bridge=true")
    session:execute("set", "inherit_codec=true")
    session:execute("set", "ignore_display_updates=true")
    session:execute("set", "call_direction=outbound")
    session:execute("set", "continue_on_fail=true")
    session:execute("unset", "call_timeout")
    session:execute("set", "Caller-Caller-ID-Name=" .. sip_number)
    session:execute("set", "Caller-Caller-ID-Number=" .. sip_number)
    session:execute("set", "origination_caller_id_number=" .. sip_number)
    session:execute("set", "effective_caller_id_number=" .. sip_number)
    session:execute("set", "Caller-Callee-ID-Name=" .. sip_number)
    session:execute("set", "Caller-Callee-ID-Number=" .. sip_number)
    session:execute("set", "callee_id_number=" .. callee_id_number)
    local string_bridge = "{url_api_vbee_dtmf=" .. url_api_vbee_dtmf ..
        ",record_path=" .. record_path ..
        ",call_id=" .. call_id ..
        ",connect_operator=true,callee_id=" .. callee_id_number ..
        ",agent_id=" .. agent_id ..
        "}sofia/external/" .. callee_id_number .. "@" .. server_ip;
    freeswitch.consoleLog("info", fsname .. "execute bridge " .. string_bridge);
    session:execute("bridge", string_bridge);

    local FAILURE_HANGUP_CAUSES = {"USER_BUSY", "USER_NOT_REGISTERED", "NO_USER_RESPONSE", "NO_ANSWER", "CALL_REJECTED"};
    local originate_disposition = session:getVariable("originate_disposition");
    freeswitch.consoleLog("info", fsname .. "  Bridged originate_disposition :" .. originate_disposition .. "\n");

    if (includes(FAILURE_HANGUP_CAUSES, originate_disposition)) then
        freeswitch.consoleLog("info", fsname .. " call out action  hangup :" .. originate_disposition .. " \n");
    end
    return originate_disposition;
end

function getSipInfo(content, callee_id_number)
    local raws = JSON:decode(content);
    local row_count = raws.row_count;
    if (row_count == 0) then
        return nil;
    end

    local registrations = raws.rows;
    for _, registration in ipairs(registrations) do
        if (callee_id_number == registration.reg_user) then
            return registration.url;
        end
    end

    return nil;
end

function executeBrigdeSoftphone(callee_id_number, agent_id)
    freeswitch.consoleLog("info", "Check Register Account " .. callee_id_number .. "\n");
    local url_sip = getSipInfo(api:executeString("show registrations as json"), callee_id_number);
    freeswitch.consoleLog("info", "SIP Account " .. callee_id_number .. " : " .. string.format("%s", url_sip));
    if (url_sip == nil) then
        return 0;
    end
    freeswitch.consoleLog("info", "Prepare open bridge connect to softphone " .. callee_id_number .. "\n");

    session:execute("set", "ignore_early_media=true");
    session:execute("set", "instant_ringback=true");
    session:execute("set", "transfer_ringback=" .. session:getVariable("hold_music"));
    session:execute("set", "ringback=" .. session:getVariable("us-ring"));
    session:execute("set", "hangup_after_bridge=true");
    session:execute("set", "inherit_codec=true");
    session:execute("set", "ignore_display_updates=true");
    session:execute("set", "call_direction=outbound");
    session:execute("set", "continue_on_fail=true");

    session:execute("set", "bridge_filter_dtmf=true");
    session:setVariable("effective_caller_id_number", 1000);
    session:setVariable("origination_caller_id_number", 1000);
    session:execute("set", "bridge_terminate_key=*") -- set phim bam de nguoi dung back lại khi dang bridge
    session:execute("set", "call_timeout=30") -- set phim bam de nguoi dung back lại khi dang bridge

    local string_bridge = "{url_api_vbee_dtmf=" .. url_api_vbee_dtmf ..
        ",record_path=" .. record_path ..
        ",call_id=" .. call_id ..
        ",connect_operator=true" .. 
        ",callee_id=" .. callee_id_number ..
        ",agent_id=" .. agent_id ..
        ",url_callback=" .. url_callback ..
        "}" .. url_sip;
    freeswitch.consoleLog("info", fsname .. "execute bridge " .. string_bridge);
    session:execute("bridge", string_bridge);

    local FAILURE_HANGUP_CAUSES = {"USER_BUSY", "USER_NOT_REGISTERED", "NO_USER_RESPONSE", "NO_ANSWER", "CALL_REJECTED"};
    local originate_disposition = session:getVariable("originate_disposition"); -- get code return hangup cause
    freeswitch.consoleLog("info", fsname .. " Bridged originate_disposition :" .. originate_disposition .. "\n")
    if (includes(FAILURE_HANGUP_CAUSES, originate_disposition)) then
        -- TODO callback log agent reject call
        
        return 1;
    end

    return 2;
end

function sendRequestWakeup(callee_id_number)
    local params = {};
    params["domain"] = session:getVariable("domain_name") .. ":" .. session:getVariable("internal_sip_port");
    params["username"]= callee_id_number;
    params["display_name"] = callee_id_number;
    
    local url_request = "https://notification-inbound.iristech.club/api/v1/ios_voip_notifications";
    local response = requestAPIAsyn(url_request, params);
    freeswitch.consoleLog("info", "[" ..caller_number .. " >>>>>>>>>>>> " .. callee_id_number .. "] Response Request Wakeup: " .. response);
end

function wakeupAndBridgeSoftPhone(callee_id_number, agent_id)
    local is_request_wakeup = false;
    local idxCheck = 0;
    maxCountCheck = 10;

    while (idxCheck < maxCountCheck) do
        freeswitch.consoleLog("info", "[" ..caller_number .. " >>>>>>>>>>>> " .. callee_id_number .. "] Ping Account And Bridge Time: " .. (idxCheck+1) .. "\n");
        local result = executeBrigdeSoftphone(callee_id_number, agent_id);

        if (result == 1 or result == 2) then
            return result;
        elseif (result == 0) then
            freeswitch.consoleLog("info", "[" ..caller_number .. " >>>>>>>>>>>> " .. callee_id_number .. "] Sleep 3000ms\n");
            if (is_request_wakeup == false) then
                sendRequestWakeup(callee_id_number);
                is_request_wakeup = true;
            end
            session:execute("sleep", 3000);
        end

        idxCheck = idxCheck + 1;
    end

    return false;
end

function executeBrigde(callee_id_number, agent_id)
    freeswitch.consoleLog("info", "execute brigde params: { callee_id_number=" .. callee_id_number .. ", agent_id=" .. agent_id .. " }");
    -- -- connect mobile
    if (string.match(callee_id_number, "mobile_") ~= nil) then
        local command, number = string.match(callee_id_number, "(mobile_)(.*)");
        if (number) then
            return executeBrigdeMobile(number, agent_id);
        end
    end
    -- connect softphone
    if (string.match(callee_id_number, "sip_") ~= nil) then
        local command, number = string.match(callee_id_number, "(sip_)(.*)");
        freeswitch.consoleLog("info", "{ callee_id_number=" ..callee_id_number .. ", command=" .. string.format("%s", command) .. ", number=" .. string.format("%s", number) .. " }");
        if (number) then
            local result = wakeupAndBridgeSoftPhone(number, agent_id);
            return result == 2;
        end
    end

    return false;
end

function getAgentInfo(connect_queue_id, call_id)
    local url_request = domain_aicc .. "/api/v1/queues/" .. connect_queue_id .. "/agent?call_id=" .. call_id

    freeswitch.consoleLog("info", "Request API URL: " .. url_request);
    local response = api:execute("curl", url_request);
    freeswitch.consoleLog("info", fsname .. " Get Agent By Queue Id: " .. response)
    response = JSON:decode(response)
    if (response["status"] == 1) then
        return response["result"];
    end
    return false;
end

loop_count = 0;
max_repeat = 2;
function process(plan)
    -- check max repeat of current dialplan
    local plan_digit = nil;
    if (loop_count > max_repeat) then
        if (plan["start_end_script"] ~= nil) then
            plan_digit = plan["start_end_script"];
            plan_digit.timeout = 1;
            plan_digit.is_end = true;
            loop_count = 0;
            process(plan_digit);
            return 1;
        end
        return 1;
    end
    -- process dialplan
    freeswitch.consoleLog("debug", "AUTO_CALL_INBOUND ==> Start process dialplan " ..  uuid .. "\n");
    if (plan["actions"]) then
        local actions = plan["actions"];
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
            -- reset keypress on session
            session:flushDigits();
            session:setVariable("read_terminator_used", nil);
            session:setVariable("playback_terminator_used", nil);

            freeswitch.consoleLog("info", "[" .. caller_number .. "] REPEAT >>>>>>>>>>>> [" .. index .. "][" .. repeat_number .. "]");
            freeswitch.consoleLog("info", "[" .. caller_number .. "] >>>>>>>>>>>> Process actions :" .. JSON:encode(actions) .. " >>>>>>>>>>>>\n");
            for _, action in ipairs(actions) do
                if (type(action) == "table") then
                    if (action["action"] == "END_CALL") then
                        freeswitch.consoleLog("info", "[" .. caller_number .. "] >>>>>>>>>>>> Exit >>>>>>>>>>>>\n");
                        return 1;
                    elseif (action["action"] == "LISTEN_AGAIN") then
                        loop_count = 1;
                        freeswitch.consoleLog("info", "[" .. caller_number .. "] >>>>>>>>>>>> Process Back x1 >>>>>>>>>>>>");
                        if (plan.back ~= nil) then
                            process(plan.back);
                            return 1;
                        end
                    elseif (action["action"] == "ROLL_BACK") then
                        loop_count = 1;
                        freeswitch.consoleLog("info", "[" .. caller_number .. "] >>>>>>>>>>>> Process Back x2 >>>>>>>>>>>>");
                        if (plan.back ~= nil and plan.back.back ~= nil) then
                            process(plan.back.back);
                            return 1;
                        end
                    elseif (action["action"] == "CONNECT_AGENT" and action["connect_queue_id"]) then
                        local connect_queue_id = action["connect_queue_id"];
                        -- call api get agent
                        while (true) do
                            freeswitch.consoleLog("info", "[" .. caller_number .. "] >>>>>>>>>>>> Connect To CSRs with queue id:" .. action["connect_queue_id"] .. " >>>>>>>>>>>> index: " .. (repeat_operator_idx + 1) .. "\n");
                            local agent_info = getAgentInfo(connect_queue_id, call_id);
                            if (agent_info) then
                                local phone_operator = agent_info["operator"];
                                local agent_id = agent_info["agent_id"];
                                if (phone_operator == nil) then
                                    break;
                                end
                                freeswitch.consoleLog("info", "phone_operator=" .. phone_operator .. ", agent_id=" .. agent_id);
                                local result = executeBrigde(phone_operator, agent_id);
                                freeswitch.consoleLog("info", "connect operator: " .. string.format("%s", result));
                                if (result == true) then
                                    break;
                                end
                            else
                                break;
                            end
                        end
                        freeswitch.consoleLog("info", fsname .. " End Process Connect CSRs");
                        -- return 1;
                    elseif (includes({"UPLOAD_RECORD", "TYPE_TEXT"}, action["action"]) and action['audio_path']) then
                        -- play audio and get digits
                        local min_digits = 0; -- minimum number of digits
                        if (action["min_digits"] ~= nil) then
                            min_digits = tonumber(action["min_digits"]);
                        end
                        local max_digits = 1; -- maximum number of digits
                        if (action["max_digits"] ~= nil) then
                            max_digits = tonumber(action["max_digits"]);
                        end
                        local tries = 1; -- number of tries for the audio play
                        if (action["tries"] ~= nil) then
                            tries = tonumber(action["tries"]);
                        end
                        local timeout = 1; -- number of milliseconds to wait for a dial when audio playback end
                        if (action["timeout"] ~= nil) then
                            timeout = tonumber(action["timeout"]);
                        end
                        local terminators = ""; -- digits used to end input
                        if (action["terminators"] ~= nil) then
                            terminators = action["terminators"];
                        end
                        local digit_timeout = 1; -- number of millisecond allowed between digits
                        if (action["digit_timeout"] ~= nil) then
                            digit_timeout = tonumber(action["digit_timeout"]);
                        end
                        local valid_digits = ""; -- Regular expression to math digits
                        if (action["valid_digits"] ~= nil) then
                            valid_digits = action["valid_digits"];
                        end

                        -- execute play audio and get digits
                        freeswitch.consoleLog("info", ">>>>>>>>>>>> [" .. caller_number .. "] Begin Play File Audio [" .. min_digits .. " - " .. max_digits .. " - " .. tries .. " - " .. timeout .. " - " .. terminators .. " - " .. action["audio_path"] .. " - ".. digit_timeout .. "] >>>>>>>>>>>>\n");
                        local digit = "";
                        digit = session:playAndGetDigits(
                            min_digits,
                            max_digits,
                            tries, -- max_tries
                            timeout,
                            terminators,
                            action["audio_path"], -- audio file
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
                        if (digit ~= "") then
                            local url_request = url_api_vbee_dtmf .. " POST " ..
                                "caller_id=" .. caller_number ..
                                "&call_id=" .. uuid ..
                                "&key=" .. digit ..
                                "&state=DTMF" ..
                                "&disposition=ANSWERED" .. 
                                "&uuid=" .. uuid ..
                                "&event_timestamp=" .. api:getTime() ..
                                "&recording_path=" .. record_path;
                            
                            if (url_callback) then
                                url_request = url_request .. "&url_callback=" .. url_callback;
                            end
                            freeswitch.consoleLog("info", fsname .. ">>>>>>>>>>>> DTMF Log: " .. url_request);
                            api:executeString("luarun http_async.lua " .. url_request);
                            DTMF = DTMF .. digit .. "-";
                            -- correct digit input
                            if (type(plan[digit]) == "table") then
                                -- set back x1 for plan_digit
                                plan_digit = plan[digit];
                                plan_digit.back = plan;
                                -- set back x2 for plan digit
                                if (plan.back) then
                                    plan_digit.back.back = plan.back;
                                end
                                
                                loop_count = 0;
                                process(plan_digit);
                                return 1;
                            end
                            -- User Wrong Input
                            if (plan[digit] ~= nil and plan["start_wrong_input"] and plan["start_end_script"]) then
                                freeswitch.consoleLog("info", ">>>>>>>>>>>> [" .. caller_number .. "] Start User Wrong Input >>>>>>>>>>>>\n");
                                current_retry_error = current_retry_error + 1;
                                plan_digit = plan["start_wrong_input"];
                                plan_digit.origin = plan;

                                if (current_retry_error > retry_error) then
                                    freeswitch.consoleLog("info", ">>>>>>>>>>>> [" .. caller_number .. "] Start End Script >>>>>>>>>>>>\n");
                                    plan_digit = plan["start_wrong_input"];
                                    plan_digit.origin = plan["start_end_script"];
                                    plan_digit.is_end = true; -- end ivr
                                end
                                plan_digit.timeout = 1; -- no listen input key
                                process(plan_digit);
                                return 1;
                            end
                        else
                            if (plan["origin"]) then
                                plan_digit = plan["origin"];
                                if (plan["is_end"] == true) then
                                    plan_digit.is_end = true;
                                end
                                process(plan_digit);
                                return 1;
                            end
                            if (plan["is_end"] == true) then
                                return 1;
                            end
                            -- user no response
                            if (plan["start_no_response"] ~= nil and plan["start_end_script"] ~= nil) then
                                freeswitch.consoleLog("info", ">>>>>>>>>>>> [" .. caller_number .. "] Start No User Response >>>>>>>>>>>>\n");
                                current_retry_error = current_retry_error + 1;
                                plan_digit = plan["start_no_response"];
                                plan_digit.origin = plan;

                                if (current_retry_error > retry_error) then
                                    freeswitch.consoleLog("info", ">>>>>>>>>>>> [" .. caller_number .. "] Start End Script >>>>>>>>>>>>\n");
                                    plan_digit = plan["start_no_response"];
                                    plan_digit.origin = plan["start_end_script"];
                                    plan_digit.is_end = true; -- end ivr
                                end
                                plan_digit.timeout = 1; -- no listen input key
                                process(plan_digit);
                                return 1;
                            end
                        end
                    else
                        freeswitch.consoleLog("info", "[" .. caller_number .. "] >>>>>>>>>>>> Process action : " .. action["action"] .. " >>>>>>>>>>>> Invalid Action >>>>>>>>>>>>\n");
                    end
                end

                -- timeout with actions
                session:sleep(100);
            end

            freeswitch.consoleLog("info", fsname .. " >>>>>>>>>>>> End Process No Repeat >>>>>>>>>>>>>>");
            index = index + 1;
        end
    end

    return 1;
end

-- get ivr from controller
getIVR(domain_aicc .. "/api/v1/calls/init-call", caller_number, sip_number)
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
-- redis
local url_callback_redis = "url_callback_" .. uuid;
local record_path_redis = "record_path_" .. uuid;

client_redis:set(record_path_redis, record_path);
client_redis:set(url_callback_redis, url_callback);
client_redis:set("pbx_callback_redis", url_api_vbee_dtmf);
-- parse ivr and create ivr back
dialplan = JSON:decode(variable_string);
dialplan.back = JSON:decode(variable_string);

-- set hangup callback
session:setHangupHook("myHangupHook");
-- answer call
session:answer();
session:execute("record_session", g_record_dir .. record_path);
-- process dialplan
process(dialplan);
