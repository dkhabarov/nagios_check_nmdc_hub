--[[##################################################################################

	NMDC Hubs Pinger 1.00
	© 2011 alex82

####################################################################################

	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <http://www.gnu.org/licenses/>.
	
	P.S. Ударим опенсорсом по нездоровой шняге

####################################################################################

	Системные требования: Lua 5.1, LuaSocket
	
	Использование:
		Ping(sAddress, iPort[, sNick, sPassword, sShare/iShare])
		
		sAddress	Адрес хаба. Обязательный параметр. Правильность адреса не проверяется - Вам необходимо сделать это самостоятельно перед вызовом функции.
		iPort	Порт хаба. Обязательный параметр. Порт должен быть числом. Правильность порта не проверяется.
		sNick	Ник пингера. Если ник не указан или равен nil, используется ник, указанный в настройках.
		sPassword	Пароль. Если пароль не указан и при подключении хаб потребует его, пингер отключится от хаба.
		sShare/iShare	Шара. Если шара не указана, используется шара, указанная в настройках.
		
	Возвращаемые значения:
		Функция возвращает таблицу, которая содержит следующие индексы:
			Online		true если хаб онлайн, или false если пингеру не удалось соединиться с хабом
			State		Состояние пинга:
				-1 - Неизвестная ошибка,
				1 - Не удалось соединиться,
				2 - Хаб не отправил $Lock",
				3 - Пинг запрещен настройками хаба,
				4 - Хаб не поддерживает $BotINFO/$HubINFO (поскольку некоторые хабы поддерживают пинг, но не сообщают об этом в $Supports, код, проверяющий $Supports, закомментирован, и статус 4 никогда не устанавливается),
				5 - Хаб полон,
				6 - Проверка ника не пройдена,
				7 - Хаб не ответил на команду $BotINFO,
				8 - Ошибка в строке $HubINFO,
				9 - Полностью проверен,

		Также в таблице могут содержаться индексы:
			Users		Число юзеров на хабе
			Share		Общая шара хаба, килобайт
			Name		Название хаба
			Descr		Описание хаба
			MaxUsers		Максимум юзеров
			MinShare		Минимальная шара
			MinSlots		Минимум слотов
			MaxHubs		Максимум хабов
			Info.Email		Адрес e-mail владельца хаба
			HubSoft			Софт хаба
			
			LastMsg		Последнее сообщение, отправленное хабом
			LastErr		Сообщение об ошибке

	Пример использования:
		dofile("pinger.lua")
		local info = Ping("dc.myhub.pp.ua",411)
		print("Hub online:",info.Online and "yes" or "no")
		if info.Online then
			print("Hub name:",info.Name or "?")
			print("Hub description:",info.Descr or "?")
			print("Users:",info.Users or "?")
			print("Share:",info.Share and info.Share.." kb" or "?")
			print("Max users:",info.MaxUsers or "?")
			print("Min share:",info.MinShare or "?")
			print("Min slots:",info.MinSlots or "?")
			print("Max hubs:",info.MaxHubs or "?")
			print("Hub soft:",info.HubSoft or "?")
		else
			print("Error:",info.LastErr or "?")
		end


###################################################################################]]

tCfg = {
	Name = "test_pinger",	-- Имя пингера, отправляемое в команде $BotINFO
	Nick = "test_pinger",	-- Ник пингера
	Descr = "",	-- Описание пингера
	Tag = "<++ V:0.75,M:A,H:1/0/0,S:10>",	-- Тег
	Email = "",	-- Адрес e-mail
	Share = 10737418240,	-- Шара пингера в байтах

	Timeout = 5,	-- Таймаут сокета при установке соединения с хабом, секунд.
	TimeoutAfterConn = 10,	-- Таймаут сокета после того, как соединение с хабом установлено, секунд.
	TimeoutAfterBotINFO = 5,	-- Таймаут сокета после отправки пингером команды $BotINFO, секунд.
	MaxTimePerHub = 60,	-- Максимальное время на пинг хаба, секунд. Поскольку сокет работает в блокирующем режиме, фактическое время пинга может быть больше максимального.
}

local _DEBUG
--_DEBUG = true

local socket = require("socket")

local function lock2key(lock)
    local function bitwise(x, y, bw)
        local c, p = 0, 1
        local function bODD(x)
            return x ~= math.floor(x / 2) * 2
        end
        while x > 0 or y > 0 do
            if bw == "xor" then
                if (bODD(x) and not bODD(y)) or (bODD(y) and not bODD(x)) then
                    c = c + p
                end
            elseif bw == "and" then
                if bODD(x) and bODD(y) then
                    c = c + p
                end
            elseif bw == "or" then
                if bODD(x) or bODD(y) then
                    c = c + p
                end
            end
            x = math.floor(x / 2)
            y = math.floor(y / 2)
            p = p * 2
        end
        return c
    end
    
	local key = {}
    table.insert(key,bitwise(bitwise(bitwise(string.byte(lock,1),string.byte(lock,-1),"xor"),string.byte(lock,-2),"xor"),5,"xor"))
    for i=2,string.len(lock),1 do
		table.insert(key,bitwise(string.byte(lock,i),string.byte(lock,i - 1),"xor"))
    end
    
	local function nibbleswap(bits)
        return bitwise(bitwise(bits*(2^4),240,"and"),bitwise(math.floor(bits/(2^4)),15,"and"),"or")
    end
    
	local g = {["5"]=1,["0"]=1,["36"]=1,["96"]=1,["124"]=1,["126"]=1}
    for i=1,#key do
		local b = nibbleswap(rawget(key,i))
		rawset(key,i,(g[tostring(b)] and string.format("/%%DCN%03d%%/",b) or string.char(b)))
    end
    
	return table.concat(key)
end

function Ping(address,port,nick,pass,share)
	if not nick then
		nick = tCfg.Nick
	end
	local hub, client, Send, UsersShare, NMDC
	
	Send = function(msg)
		if hub.Log then
			hub.Log:write(os.date("[%H:%M:%S]: <== "),msg,"\n")
		end
		client:send(msg.."|")
	end
	UsersShare = function()
		local users,share = 0,0
		for i,v in pairs(hub.Userlist) do
			users = users+1
			share = share+v
		end
		hub.Info.Users,hub.Info.Share = users,math.floor(share/1024)
		hub.BotINFO = true
		client:settimeout(tCfg.TimeoutAfterBotINFO)
		hub.Info.State = 7
		Send("$BotINFO "..tCfg.Name)
	end
	NMDC = {
		Lock = function(data)
			local lock,soft = data:match("(%S+)%sPk=(.*)$")
			if lock then
				Send("$Supports NoGetINFO NoHello BotINFO |$Key "..lock2key(lock).."|$ValidateNick "..nick)
				hub.Info.Online = true
				hub.Info.State = 3
				hub.Info.HubSoft = soft
				if soft:find("^Eximius") then
					hub.Eximius = true
				end
			else
				hub.Info.State = 2
				return true
			end
		end,
	--[[	Supports = function(data)
			if not data:find("BotINFO") then
				hub.Info.State = 4
				return true
			end
		end,]]
		GetPass = function()
			if pass then
				Send("$MyPass "..pass)
			else
				hub.Info.State = 6
				hub.Info.LastErr = "Password required"
				return true
			end
		end,
		BadPass = function()
			hub.Info.State = 6
			hub.Info.LastErr = "BadPass"
			return true
		end,
		Hello = function()
			Send("$Version 1,0091|$GetNickList|$MyINFO $ALL "..nick.." "..tCfg.Descr..
			tCfg.Tag.."$ $100\1$"..tCfg.Email.."$"..(share or tCfg.Share).."$")
			hub.Info.State = -1
		end,
		HubName = function(data)
			if data then
				hub.Info.Name = data:gsub(" %- .-$","")
			end
		end,
		MyINFO = function(data)
			if data then
				hub.MyINFO = true
				local nick,share = data:match("^%$ALL%s+(%S+)%s+.+%$(%d+)%$$")
				if nick and share then
					if hub.Eximius and nick == nick then
						UsersShare()
					else
						hub.Userlist[nick] = tonumber(share)
					end
				end
			end
		end,
		Quit = function(data)
			if data then
				hub.Userlist[data] = nil
			end
		end,
		HubINFO = function(data)
			if data then
				hub.Info.Name,hub.Info.Descr,hub.Info.MaxUsers,hub.Info.MinShare,
					hub.Info.MinSlots,hub.Info.MaxHubs,hub.Info.HubSoft,hub.Info.Email = 
					data:match("^(.-)%$.-%$(.-)%$(%d+)%$(%d+)%$(%d+)%$(%d+)%$(.-)%$(.-)$")
				if hub.Info.Name then
					if hub.Info.Descr:find("%.px%.$") then
						hub.Info.Descr = hub.Info.Descr:gsub("%.px%.$","")
						hub.Info.HubSoft = "PtokaX"
					end
					hub.Info.State = 9
					client:settimeout(1)
				else
					hub.Info.State = 8
				end
			end
			return true
		end,
		ValidateDenide = function()
			hub.Info.State = 6
			hub.Info.LastErr = "ValidateDenide"
			return true
		end,
		HubIsFull = function()
			hub.Info.State = 5
			hub.Info.LastErr = "HubIsFull"
			return true
		end,
		OpList = function()
			if hub.MyINFO and not hub.BotINFO and not hub.Eximius then
				UsersShare()
			else
				hub.Info.State = 7
			end
		end,
		UserCommand = function()
			if hub.MyINFO and not hub.BotINFO then
				UsersShare()
			end
		end,
	}

	NMDC.Search,NMDC.SR = NMDC.UserCommand,NMDC.UserCommand

	hub = {Info = {State = 1,Online = false,Begin = os.time()},
		Userlist = {},
		BotINFO = false,
		MyINFO = false,
		PingTime = 0,
	}
	
	if _DEBUG then
		hub.Log = io.open("logs/"..address.."_"..port..".log","w")
	end
	
	client = socket.tcp()
	client:settimeout(tCfg.Timeout)
	starttime = os.time()
	local res,err = client:connect(address,port)
	if not res then
		hub.Info.LastErr = err
	else
		local l,e = client:receive(1)
		local tbuf = {}
		while not e do
			if l == "|" then
				local buf = table.concat(tbuf)
				if hub.Log then
					hub.Log:write(os.date("[%H:%M:%S]: ==> "),buf,"\n")
				end
				local cmd = buf:match("^%$(%S+)")
				if cmd then
					if NMDC[cmd] then
						if NMDC[cmd](buf:match("^%$%S+%s(.+)$")) then
							break
						end
					end
				else
					hub.Info.LastMsg = buf
				end
				if hub.Info.Begin+tCfg.MaxTimePerHub < os.time() then break end
				tbuf = {}
			else
				table.insert(tbuf,l)
			end
			l,e = client:receive(1)
		end
		if hub.MyINFO and not hub.BotINFO then
			UsersShare()
			l,e = client:receive(1)
			tbuf = {}
			while not e do
				if l == "|" then
					local buf = table.concat(tbuf)
					if hub.Log then
						hub.Log:write(os.date("[%H:%M:%S]: ==> "),buf,"\n")
					end
					local cmd = buf:match("^%$(%S+)")
					if cmd then
						if cmd == "HubINFO" then
							NMDC.HubINFO(buf:match("^%$%S+%s(.+)$"))
							break
						end
					else
						hub.Info.LastMsg = buf
					end
					if hub.Info.Begin+tCfg.MaxTimePerHub < os.time() then break end
					tbuf = {}
				else
					table.insert(tbuf,l)
				end
				l,e = client:receive(1)
			end
		end
		if not hub.Info.LastErr then hub.Info.LastErr = e end
	end
	client:shutdown()
	hub.Info.PingTime = (os.time()-starttime)
	if hub.Log then
		if hub.Info.LastErr then
			hub.Log:write(os.date("[%H:%M:%S]: Error: "),hub.Info.LastErr)
		end
		hub.Log:close()
		hub.Log = nil
	end
	
	return hub.Info
end
