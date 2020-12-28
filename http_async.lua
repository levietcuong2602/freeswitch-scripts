requestUrl = argv[1];

method = argv[2];

params = argv[3];

api = freeswitch.API();

local result = api:execute("curl", requestUrl.." "..method.." "..params);
freeswitch.consoleLog("info", "HTTP_ASYNC CALL URL: "..requestUrl.." "..method.." "..params);
