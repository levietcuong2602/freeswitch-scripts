local utils = {
    _VERSION     = 'redis-lua 2.0.5-dev',
    _DESCRIPTION = 'A Lua client library for the redis key value storage system.',
    _COPYRIGHT   = 'Copyright (C) 2009-2012 Daniele Alessandri',
}
function utils.writelog(level, content)
	freeswitch.consoleLog(level, "CC_VAIS =========>>>> "..content.."\n");
end

-- goi api 
function utils.requestAPI(session, requestFunction, requestParams)
	local jsonData = nil;
--	if(not session:ready()) then
--		return jsonData;
--	end
	
	local requestUrl = requestFunction;
	if(requestParams ~= nil and type(requestParams) == "table") then
		local paramsUrl = "";
		for k,v in pairs(requestParams) do 
			if(paramsUrl == "") then
				paramsUrl = k.."="..v;
			else
				paramsUrl = paramsUrl.."&"..k.."="..v;
			end
		end
		if(paramsUrl ~= "") then
			requestUrl = requestUrl.."?";
		end
		requestUrl = requestUrl..paramsUrl;
	end
	
	writelog("info","Requesting API: "..requestUrl);
	
	--Call API by Curl
	session:setVariable("curl_timeout", "30")
	session:execute("curl", requestUrl);
	local curl_response = session:getVariable("curl_response_data");	

	if(curl_response ~= nil and curl_response ~= "") then
		writelog("debug", "requestAPI >>>>>>>>>>>>>> :"..curl_response);
		jsonData = JSON:decode(curl_response);
		if(jsonData == nil) then
			--Du lieu gap loi, hangup cuoc goi
			playFileWithOutGetDigits("/home/recordings/1080/1080_loi_he_thong.wav");
			processHangUp("Du lieu API tra ve bi loi:"..requestUrl);
		end
	else
		writelog("debug", "requestAPI>>>>>>>>>>>>>>>>>>>>> : No Response");
		--He thong gap loi, hangup cuoc goi
		playFileWithOutGetDigits("/home/recordings/1080/1080_loi_he_thong.wav");
		processHangUp("loi khi goi API:"..requestUrl);
	end
	
	return jsonData;
end


function utils.char_to_hex(c)
  return string.format("%%%02X", string.byte(c))
end

function utils.urlencode(url)
  if url == nil then
    return
  end
  url = url:gsub("\n", "\r\n")
  url = url:gsub("([^%w ])", char_to_hex)
  url = url:gsub(" ", "+")
  return url
end

function utils.hex_to_char (x)
  return string.char(tonumber(x, 16))
end

function utils.urldecode (url)
  if url == nil then
    return
  end
  url = url:gsub("+", " ")
  url = url:gsub("%%(%x%x)", hex_to_char)
  return url
end

-- Used in parse_xml
function utils.parseargs_xml(s)
   local arg = {}
   string.gsub(s, "(%w+)=([\"'])(.-)%2", function (w, _, a)
					    arg[w] = a
					 end)
   return arg
end

-- Turns XML into a lua table.
function utils.parse_xml(s)
   local stack = {};
   local top = {};
   table.insert(stack, top);
   local ni,c,label,xarg, empty;
   local i, j = 1, 1;
   while true do
      ni,j,c,label,xarg, empty = string.find(s, "<(%/?)(%w+)(.-)(%/?)>", i);
      if not ni then
	 break
      end
      local text = string.sub(s, i, ni-1);
      if not string.find(text, "^%s*$") then
	 table.insert(top, text);
      end
      if empty == "/" then
	 table.insert(top, {label=label, xarg=parseargs_xml(xarg), empty=1});
      elseif c == "" then
	 top = {label=label, xarg=parseargs_xml(xarg)};
	 table.insert(stack, top);
      else
	 local toclose = table.remove(stack);
	 top = stack[#stack];
	 if #stack < 1 then
	    error("nothing to close with "..label);
	 end
	 if toclose.label ~= label then
	    error("trying to close "..toclose.label.." with "..label);
	 end
	 table.insert(top, toclose);
      end
      i = j+1;
   end
   local text = string.sub(s, i);
   if not string.find(text, "^%s*$") then
      table.insert(stack[stack.n], text);
   end
   if #stack > 1 then
      error("unclosed "..stack[stack.n].label);
   end
   return stack[1];
end

function utils.dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
	 if type(k) ~= 'number' then k = '"'..k..'"' end
	 s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

-- Used to parse the XML results.
function utils.getResults(s) 
   local xml = parse_xml(s);
   local stack = {}
   local top = {}

   -- freeswitch.consoleLog("crit", "\n" .. dump(xml) .. "\n");
   table.insert(stack, top)
   top = {grammar=xml[2].xarg.grammar, score=xml[2].xarg.confidence, text=xml[2][1][1][1]}
   table.insert(stack, top)
   return top;
end

-- This is the input callback used by dtmf or any other events on this session such as ASR.
function utils.onInput(s, type, obj)
   freeswitch.consoleLog("info", "Callback with type " .. type .. "\n");
end
--Ham xu ly play file khong can nhan phim nhung co the break file
function utils.playFileWithOutGetDigits(file_path, session, time_out)
  if(not session:ready() or file_path == nil) then
    return;
  end 
  local digit = "";
  --session:playAndGetDigits(1, 1, 1, 1, "",soundDir..fileName..fileExt,"","");
  session:sleep(0,1);
  digit = session:playAndGetDigits(1, 1, 1, time_out, "",file_path,"","");
  return digit;
end

function utils.utf8toansi(text)
  text=text:gsub("ú","u")
  text=text:gsub("ù","u")
  text=text:gsub("ủ","u")
  text=text:gsub("ũ","u")
  text=text:gsub("ụ","u")
  text=text:gsub("ư","u")
  text=text:gsub("ứ","u")
  text=text:gsub("ừ","u")
  text=text:gsub("ử","u")
  text=text:gsub("ữ","u")
  text=text:gsub("ự","u")
  text=text:gsub("Ú","u")
  text=text:gsub("Ù","u")
  text=text:gsub("Ủ","u")
  text=text:gsub("Ũ","u")
  text=text:gsub("Ụ","u")
  text=text:gsub("Ư","u")
  text=text:gsub("Ứ","u")
  text=text:gsub("Ừ","u")
  text=text:gsub("Ử","u")
  text=text:gsub("Ữ","u")
  text=text:gsub("Ự","u")
  text=text:gsub("á","a")
  text=text:gsub("à","a")
  text=text:gsub("ả","a")
  text=text:gsub("ã","a")
  text=text:gsub("ạ","a")
  text=text:gsub("ă","a")
  text=text:gsub("ắ","a")
  text=text:gsub("ặ","a")
  text=text:gsub("ằ","a")
  text=text:gsub("ẳ","a")
  text=text:gsub("ẵ","a")
  text=text:gsub("â","a")
  text=text:gsub("ấ","a")
  text=text:gsub("ầ","a")
  text=text:gsub("ẩ","a")
  text=text:gsub("ẫ","a")
  text=text:gsub("ậ","a")
  text=text:gsub("Á","a")
  text=text:gsub("À","a")
  text=text:gsub("Ả","a")
  text=text:gsub("Ã","a")
  text=text:gsub("Ạ","a")
  text=text:gsub("Ă","a")
  text=text:gsub("Ắ","a")
  text=text:gsub("Ặ","a")
  text=text:gsub("Ằ","a")
  text=text:gsub("Ẳ","a")
  text=text:gsub("Ẵ","a")
  text=text:gsub("Â","a")
  text=text:gsub("Ấ","a")
  text=text:gsub("Ầ","a")
  text=text:gsub("Ẩ","a")
  text=text:gsub("Ẫ","a")
  text=text:gsub("Ậ","a")
  text=text:gsub("Đ","d")
  text=text:gsub("đ","d")
  text=text:gsub("é","e")
  text=text:gsub("è","e")
  text=text:gsub("ẻ","e")
  text=text:gsub("ẽ","e")
  text=text:gsub("ẹ","e")
  text=text:gsub("ê","e")
  text=text:gsub("ế","e")
  text=text:gsub("ề","e")
  text=text:gsub("ể","e")
  text=text:gsub("ễ","e")
  text=text:gsub("ệ","e")
  text=text:gsub("É","e")
  text=text:gsub("È","e")
  text=text:gsub("Ẻ","e")
  text=text:gsub("Ẽ","e")
  text=text:gsub("Ẹ","e")
  text=text:gsub("Ê","e")
  text=text:gsub("Ế","e")
  text=text:gsub("Ề","e")
  text=text:gsub("Ể","e")
  text=text:gsub("Ễ","e")
  text=text:gsub("Ệ","e")
  text=text:gsub("í","i")
  text=text:gsub("ì","i")
  text=text:gsub("ỉ","i")
  text=text:gsub("ĩ","i")
  text=text:gsub("ị","i")
  text=text:gsub("Í","i")
  text=text:gsub("Ì","i")
  text=text:gsub("Ỉ","i")
  text=text:gsub("Ĩ","i")
  text=text:gsub("Ị","i")
  text=text:gsub("ó","o")
  text=text:gsub("ò","o")
  text=text:gsub("ỏ","o")
  text=text:gsub("õ","o")
  text=text:gsub("ọ","o")
  text=text:gsub("ô","o")
  text=text:gsub("ố","o")
  text=text:gsub("ồ","o")
  text=text:gsub("ổ","o")
  text=text:gsub("ỗ","o")
  text=text:gsub("ộ","o")
  text=text:gsub("ơ","o")
  text=text:gsub("ớ","o")
  text=text:gsub("ờ","o")
  text=text:gsub("ở","o")
  text=text:gsub("ỡ","o")
  text=text:gsub("ợ","o")
  text=text:gsub("Ó","o")
  text=text:gsub("Ò","o")
  text=text:gsub("Ỏ","o")
  text=text:gsub("Õ","o")
  text=text:gsub("Ọ","o")
  text=text:gsub("Ô","o")
  text=text:gsub("Ố","o")
  text=text:gsub("Ồ","o")
  text=text:gsub("Ổ","o")
  text=text:gsub("Ỗ","o")
  text=text:gsub("Ộ","o")
  text=text:gsub("Ơ","o")
  text=text:gsub("Ớ","o")
  text=text:gsub("Ờ","o")
  text=text:gsub("Ở","o")
  text=text:gsub("Ỡ","o")
  text=text:gsub("Ợ","o")
  text=text:gsub("ý","y")
  text=text:gsub("ỳ","y")
  text=text:gsub("ỷ","y")
  text=text:gsub("ỹ","y")
  text=text:gsub("ỵ","y")
  text=text:gsub("Ý","y")
  text=text:gsub("Ỳ","y")
  text=text:gsub("Ỷ","y")
  text=text:gsub("Ỹ","y")
  text=text:gsub("Ỵ","y")
  return string.lower(text);
end
return utils
