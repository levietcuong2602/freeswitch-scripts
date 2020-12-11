event_timestamp = math.floor(event:getHeader("Event-Date-Timestamp") / 1000)
freeswitch.consoleLog("info", "Hook Answer Event At : [event_timestamp] = " ..event_timestamp .. " => [Event-Date-Local] = " .. event:getHeader("Event-Date-Local") .. "\n");

answer_state = event:getHeader("Answer-State");
call_direction = event:getHeader("Call-Direction");

freeswitch.consoleLog("info", "Header Info: {" ..
    "\nAnswer-State: " .. answer_state .. 
    "\nCall-Direction: " .. call_direction ..
"}");

