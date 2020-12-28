api = freeswitch.API();

event_timestamp = math.floor(event:getHeader("Event-Date-Timestamp") / 1000)
freeswitch.consoleLog("info", "CALL ANSWER : [event_timestamp] = " ..event_timestamp .. " => [Event-Date-Local] = " .. event:getHeader("Event-Date-Local") .. "\n");

answer_state = event:getHeader("Answer-State");
call_direction = event:getHeader("Call-Direction");
caller_ani = event:getHeader("Caller-ANI");
caller_caller_id_number = event:getHeader("Caller-Caller-ID-Number");
caller_destination_number = event:getHeader("Caller-Destination-Number");
channel_state = event:getHeader("Channel-State");
channel_state_number = event:getHeader("Channel-State-Number");
channel_name = event:getHeader("Channel-Name");
channel_call_uuid = event:getHeader("Channel-Call-UUID");
variable_call_uuid = event:getHeader("variable_call_uuid");
connect_operator = event:getHeader("variable_connect_operator");
callee_id = event:getHeader("variable_callee_id");
call_uuid = event:getHeader("variable_call_uuid");
event_timestamp = math.floor(event:getHeader("Event-Date-Timestamp") / 1000);

record_path = event:getHeader("variable_record_path");
if (record_path == nil) then
    record_path = "";
end

url_api_vbee_dtmf = event:getHeader("variable_url_api_vbee_dtmf");
freeswitch.consoleLog("info", "variable_url_api_vbee_dtmf= " .. url_api_vbee_dtmf);
if (url_api_vbee_dtmf == nil) then
    url_api_vbee_dtmf = "https://api-dev.vbeecore.com/api/ezcall/event_dtmf post";
    -- url_api_vbee_dtmf = "http://0c32f5896339.ngrok.io/api/v1/event-call post";
end
if string.sub(url_api_vbee_dtmf, -4) ~= "post" then
    url_api_vbee_dtmf = url_api_vbee_dtmf .. " post";
end

call_id = event:getHeader("variable_call_id")
if (call_id == nil) then
  call_id = ""
end
agent_id = event:getHeader("variable_agent_id")
if (agent_id == nil) then
  agent_id = ""
end

freeswitch.consoleLog("info", "Header Info: {" ..
    "\nAnswer-State: " .. string.format("%s", answer_state) .. 
    "\nCall-Direction: " .. string.format("%s", call_direction) ..
    "\nCaller-ANI: " .. string.format("%s", caller_ani) ..
    "\nCaller-Caller-ID-Number: " .. string.format("%s", caller_caller_id_number) ..
    "\nCaller-Destination-Number: " .. string.format("%s", caller_destination_number) ..
    "\nChannel-Call-UUID: " .. string.format("%s", channel_call_uuid) ..
    "\nChannel-State: " .. string.format("%s", channel_state) ..
    "\nChannel-State-Number: " .. string.format("%s", channel_state_number) ..
    "\nChannel-Name: " .. string.format("%s", channel_name) ..
    "\nvariable_call_uuid: " .. string.format("%s", variable_call_uuid) ..
    "\nconnect_operator: " .. string.format("%s", connect_operator) ..
    "\ncallee_id: " .. string.format("%s", callee_id) ..
    "\ncall_uuid: " .. string.format("%s", call_uuid) ..
    "\ncall_id: " .. string.format("%s", call_id) ..
    "\nagent_id: " .. string.format("%s", agent_id) ..
    "\nurl_api_vbee_dtmf: " .. string.format("%s", url_api_vbee_dtmf) ..
"\n}");

disposition = "";
if (answer_state == "hangup") then
    disposition = event:getHeader("Hangup-Cause");
else
    disposition = event:getHeader("Call-Direction");
end
if (disposition ~= "WRONG_CALL_STATE") then
    g_record_dir = "/var/lib/freeswitch/recordings/";
    freeswitch.consoleLog("info", "START RECORD FROM EVENT [" .. g_record_dir .. record_path .. "] :::: [" .. event_timestamp .. " \n");

    local request_url = url_api_vbee_dtmf ..
        " caller_id=" .. caller_destination_number ..
        "&call_id=" .. call_id .. 
        "&uuid=" .. channel_call_uuid .. 
        "&recording_path=" .. record_path .. 
        "&event_timestamp=" .. event_timestamp;

    if (connect_operator == nil) then
        request_url = request_url .. "&key=-&state=answered&disposition=ANSWERED";
    else
        -- TODO Call API Callback Agent
        -- 
        request_url = request_url .. "&key=connected_operator&state=DTMF&disposition=ANSWERED&callee_id=" .. callee_id;
    end

    freeswitch.consoleLog("info", "CALL_ANSWER CALLBACK BEGIN :::: [" .. caller_caller_id_number .. " => " .. caller_destination_number .. "] " .. request_url .. " \n");
    local response = api:execute("curl", request_url);
    freeswitch.consoleLog("info", "CALL_ANSWER CALLBACK RESULT:::: [" .. caller_caller_id_number .. " => " .. caller_destination_number .. "]" .. response .. " \n");
end
