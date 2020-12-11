freeswitch.consoleLog("info", package.path);
freeswitch.consoleLog("info", _VERSION);

JSON = (loadfile "/usr/local/freeswitch/scripts/JSON.lua")();
package.path = "/usr/share/lua/5.2/?.lua;/usr/local/freeswitch/scripts/utils/?.lua;" .. package.path
pcall(require, "luarocks.require");

-- local response = '{"result":{"call_back":"https://cp-dev.aicallcenter.vn/api/campaigns/3961/calls/171cab80-15e3-41ed-85f3-34aa6aad70d1/voiceviet-callback","dial_plan":{"0":{"1":{"actions":[{"action":"LISTEN_AGAIN","id":"5fcf4cc1849edf0974cde3d8"},{"action":"CONNECT_AGENT","connect_queue_id":"5fa3699d375e9f3224e6b6ad","id":"5fcf4cc1849edf0974cde3d9"}],"digit":1,"id":"childT7hp4"},"3":{"1":{"actions":[{"action":"ROLL_BACK","id":"5fcf4cc1849edf0974cde3dd"}],"digit":1,"id":"childkTT7T"},"3":{"actions":[{"action":"ROLL_BACK","id":"5fcf4cc1849edf0974cde3db"}],"digit":3,"id":"childOQ0k5"},"actions":[{"action":"LISTEN_AGAIN","id":"5fcf4cc1849edf0974cde3d5"},{"action":"ROLL_BACK","id":"5fcf4cc1849edf0974cde3d6"}],"digit":3,"id":"childLtLqi"},"actions":[{"action":"LISTEN_AGAIN","id":"5fcf4cc1849edf0974cde3cb"}],"digit":0,"id":"childwGM4P"},"8":{"1":{"actions":[{"action":"ROLL_BACK","id":"5fcf4cc1849edf0974cde3cf"},{"action":"LISTEN_AGAIN","id":"5fcf4cc1849edf0974cde3d0"}],"digit":1,"id":"childndZi3"},"3":{"actions":[{"action":"LISTEN_AGAIN","id":"5fcf4cc1849edf0974cde3d2"},{"action":"ROLL_BACK","id":"5fcf4cc1849edf0974cde3d3"}],"digit":3,"id":"childTHSIx"},"actions":[{"action":"LISTEN_AGAIN","id":"5fcf4cc1849edf0974cde3cd"}],"digit":8,"id":"childnL8bV"},"actions":[],"digit":0,"id":"start"}';

response =  { 
    ["name1"] = "value1",
    ["name2"] = { 1, false, true, 23.54, "a \021 string" },
    name3 = ""
};
freeswitch.consoleLog("info", "response: " .. type(response));

response = JSON:encode(response);
freeswitch.consoleLog("info", "response: " .. JSON:encode(response));