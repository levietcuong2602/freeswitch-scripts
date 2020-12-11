JSON = (loadfile "/usr/local/freeswitch/scripts/JSON.lua")();

package.path = "/usr/share/lua/5.2/?.lua;/usr/local/freeswitch/scripts/utils/?.lua;" .. package.path
pcall(require, "luarocks.require");

local redis = require "redis";
client = redis.connect("127.0.0.1", 6379);

freeswitch.consoleLog("info", "Catch Event Hangup Call hehe");