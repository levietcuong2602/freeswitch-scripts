softphone = "sip_Vbe.MB.00000001";
mobile = "mobile_0339374848";

local command, number = string.match(softphone, "sip_");
freeswitch.consoleLog("info", "command: " .. string.format("%s", command) .. " - number: " .. string.format("%s", number));