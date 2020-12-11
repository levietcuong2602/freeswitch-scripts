freeswitch.consoleLog("info", package.path);
freeswitch.consoleLog("info", _VERSION);

package.path = "/usr/share/lua/5.2/?.lua;/usr/local/freeswitch/scripts/utils/?.lua;" .. package.path
pcall(require, "luarocks.require");

local redis = require "redis";
client_redis = redis.connect("127.0.0.1", 6379);

client_redis:set('usr:nrk', 'cuongnv')
local value_redis = client_redis:get('usr:nrk')
freeswitch.consoleLog("info", value_redis)
