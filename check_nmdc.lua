#!/usr/bin/env lua5.1
-- ***************************************************************************
-- check_nmdc.lua - Plugin for nagios to check NeoModus Direct Connect (NMDC) hubs.

-- Copyright © 2013 Denis Khabarov aka 'Saymon21'
-- E-Mail: saymon at hub21 dot ru (saymon@hub21.ru)

-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License version 3
-- as published by the Free Software Foundation.

-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.

-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
-- ***************************************************************************
-- Depends: NMDC Hubs Pinger by alex82: http://mydc.ru/topic4787.html
_MYVERSION="0.2"
local tArgs = {}
local NAG_STATES= { --http://nagios.sourceforge.net/docs/3_0/pluginapi.html
		["OK"] = 0,
		["WARNING"] = 1,
		["CRITICAL"] = 2,
		["UNKNOWN"] = 3,	
	}

local PINGER_STATES={
	[-1] = "Unknown error",
	[1] = "Unable to connect",
	[2] = "Hub is not send Lock command",
	[3] = "Ping is denied in hub settings",
	[5] = "Hub is full",
	[6] = "Validate bot nick error",
	[7] = "Hub is not answered on command BotINFO",
	[8] = "HubINFO syntax error",
	[9] = "ok",
}
require"md5"
if not package.loaded['md5'] then
	print('Lua md5 module not found. For fix it usage: \'apt-get install liblua5.1-md5-0\' (If you\'re using Debian or Ubuntu)')
	os.exit(NAG_STATES['UNKNOWN'])
end
local res,err=pcall(dofile,"/usr/share/lua/5.1/nmdc_pinger.lua")
if not res then
	print('Pinger module not found. Please download from \'http://mydc.ru/topic4787.html\'')
	os.exit(NAG_STATES['UNKNOWN'])
end
function convert_normal_size_to_bytes (value)
	if value and value ~= "" then
		value = value:lower()
		local t = { ["b"] = 1, ["kb"] = 1024, ["mb"] = 1024^2, ["gb"] = 1024^3, ["tb"] =1024^4, ["pb"] =1024^5}
		local _,_,num = value:find("^(%d+%.*%d*)")
		local _,_,tail = value:find("^%d+%.*%d*%s*(%a+)$")
		if not num then 
			return false 
		end
		num = tonumber(num)
		if not tail then 
			return num 
		end

		local multiplier = 1
		if num and tail and t[tail] then
			multiplier = t[tail]
		elseif not num or (tail and not t[tail]) then
			return false
		end
		return (tonumber(num) * multiplier)
	else
		return false
	end
end

function convert_bytes_to_normal_size (share)
    local i,unit = 1, {"KB","MB","GB","TB","PB","EB"}
    while share > 1024 do 
    	share = share / 1024 i = i + 1 
    end
    return string.format("%.3f",share).." "..(unit[i] or "??")
end


function show_usage()
	local _usage=[[usage: ]]..arg[0]:gsub('./','')..[[ --addr=dc.mycompany.ltd [ --port=4111 ] [ --nick='MyNagios' ] [ --password='mysuperpassowrd' ] [ --sharesize=1G ] [ --perfdata ] [ --usersmaxwarn=95 ] [ --usersmaxcritical=100 ] [ --expecthubname='My Company DC's Hub' ] [ --randomnick ] [ --version ] ]]
	print(_usage)
end

function show_help ()
	print(('check_nmdc.lua - Plugin for nagios to check NeoModus Direct Connect (NMDC) hubs.\
Version: %s\
Copyright © 2013 by Denis Khabarov aka \'Saymon21\'\
E-Mail: saymon at hub21 dot ru (saymon@hub21.ru)\
Homepage: http://opensource.hub21.ru/nagios_check_nmdc_hub/\
Licence: GNU General Public License version 3\
You can download full text of the license on http://www.gnu.org/licenses/gpl-3.0.txt\n'):format(_MYVERSION))

	show_usage()

print[[

Options:
	--version                 - Show version
	--help                    - Show this help
	--addr=VALUE              - Host name or IP Address hub
	--port=VALUE              - TCP Port. (Optional. Default: 411)
	--nick=VALUE              - Bot nick
	--password=VALUE          - Password for botnick
	--sharesize=VALUE         - Share size for bot
	--perfdata                - Enable perfdata
	--usersmaxwarn=VALUE      - Warning if userscount >= VALUE
	--usersmaxcritical=VALUE  - Critical if userscount >= VALUE
	--expecthubname           - Expect Hubname (Check md5 sum)
	--randomnick              - Add random number in nick end
	
	]]
end

function cliarg_handler ()
	if arg then
		local available_args = {
			["addr"] = true, ["port"] = true, ["nick"] = true, ["password"] = true, ["sharesize"] = true, ["help"]= true,
			['perfdata']=true,['usersmaxwarn']=true, ['usersmaxcritical']=true,["expecthubname"]=true,
			['randomnick'] = true, ['version'] = true,
		}
		for _, val in ipairs(arg) do
			if val:find("=", 1, true) then
				local name, value = val:match("%-%-(.-)=(.+)")
				if name and value and available_args[name:lower()] then
					tArgs[name:lower()] = value
				else
					print("Unknown commandline argument used: "..val)
					show_usage()
					os.exit(NAG_STATES["UNKNOWN"])
				end
			else
				name = val:match("%-%-(.+)")
				if name and  available_args[name:lower()] then
					tArgs[name:lower()] = true
				else
					print("Unknown commandline argument used: "..val)
					show_usage()
					os.exit(NAG_STATES["UNKNOWN"])
				end
			end
		end
	end
	if tArgs["help"] then
		show_help() -- Show help
		os.exit(NAG_STATES["OK"])
	end
	if tArgs['version'] then
		print(arg[0]:gsub('./','')..' version: '.._MYVERSION)
		os.exit(NAG_STATES['OK'])
	end
	if not tArgs['addr'] or type(tArgs['addr']) ~= 'string' then
		print('Argument \'addr\' is nil or not string')
		show_usage()
		os.exit(NAG_STATES['UNKNOWN'])
	end
	if not tArgs["port"] or type(tArgs["port"]) ~= 'string' then
		tArgs['port'] = 411
	end
	if type(tArgs['port'])=='string' and tArgs['port']:find("^%d+$") then
		tArgs['port']=tonumber(tArgs['port'])
	end
	if not tArgs['nick'] then
		tArgs['nick'] = 'nmdcnagios'
	end	
	if tArgs['sharesize'] then
		tArgs['sharesize'] = convert_normal_size_to_bytes(tArgs['sharesize'])	
	end
	if tArgs['usersmaxwarn'] and type(tArgs['usersmaxwarn']) ~= 'string' then
		print('Argument \'usersmaxwarn\' is nil or not string')
		os.exit(NAG_STATES['UNKNOWN'])
	end
	if tArgs['usersmaxcritical'] and type(tArgs['usersmaxcritical']) ~= 'string' then
		print('Argument \'usersmaxcritical\' is nil or not string')
		os.exit(NAG_STATES['UNKNOWN'])
	end
	if tArgs['expecthubname'] and type(tArgs['expecthubname']) ~= 'string' then
		print('Argument \'expecthubname\' is nil or not string')
		os.exit(NAG_STATES['UNKNOWN'])
	end
end



local function main ()
	cliarg_handler() -- Parse command line arguments
	local nagstate,result = NAG_STATES['UNKNOWN'],'Unable to check '..tArgs['addr']..': Unknown error'
	if tArgs['randomnick'] then
		math.randomseed(os.time())
		tArgs['nick'] = tArgs['nick']..tostring(math.random(1,33))
	end
	local hub = Ping(tArgs['addr'],(tArgs['port'] or 411),tArgs['nick'],tArgs['password'],convert_normal_size_to_bytes(tArgs['sharesize']))
	if hub.Online then
--		print('ONLINE')
		if hub.State == 9 then
			if tArgs['usersmaxcritical'] and (hub.Users or 0) >= tonumber(tArgs["usersmaxcritical"]) then
				result = "CRITICAL: "..(hub.Name and hub.Name or 'Hub').." Online users count: "..(hub.Users or 0)
				nagstate = NAG_STATES['CRITICAL']
			elseif tArgs['usersmaxwarn'] and (hub.Users or 0) >= tonumber(tArgs['usersmaxwarn']) then
				result="WARNING: "..(hub.Name and hub.Name or 'Hub').." Online users count: "..(hub.Users or 0)
				nagstate = NAG_STATES['WARNING']
			elseif tArgs['expecthubname'] and hub.Name and md5.sumhexa(hub.Name) ~=	md5.sumhexa(tArgs['expecthubname']) then
				result = "WARNING: Hubname="..hub.Name.." but expected "..tArgs['expecthubname']
				nagstate = NAG_STATES['WARNING']
			else
				result = ("OK: "..(hub.Name and hub.Name or 'Hub')..(hub.HubSoft and ' is powered by '..hub.HubSoft..'.' or ' is running. ')..(hub.Users and " Users: "..hub.Users or 0)..(hub.Share and ", Sharesize: "..convert_bytes_to_normal_size(hub.Share) or 0))
				nagstate = NAG_STATES['OK']
			end
		elseif hub.State <= 8 and hub.State >= 2 then
			result = 'WARNING Error: '..PINGER_STATES[hub.State]
			nagstate = NAG_STATES['WARNING']
		end
		
		if tArgs['perfdata'] then
			result = ("%s|users=%d;share=%s"):format(result,(hub.Users or 0),(hub.Share or 0))
		end
	else
		if hub.LastErr == "closed" then
			hub.LastErr = "Connection has been closed"
		elseif hub.LastErr == "timeout" then
			hub.LastErr = "Connection timed out after "..tCfg.Timeout.." seconds"
		end
		result = "Error: "..hub.LastErr
		nagstate = NAG_STATES["CRITICAL"]
	end
	print(result)
	os.exit(nagstate)
end

if type(arg) == "table" then
	main()
end
