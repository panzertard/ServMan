------------------------------------------------------------------
-- SERVMAN SERVER MANAGEMENT MOD
-- FILE: server.lua
-- VERSION: 3.0.1
-- AUTHORS: Eagle Dynamics, Panzertard
------------------------------------------------------------------
-- Note, the scripts can now be reloaded dynamicly ingame
-- A few of the variables needs to support this, so we dont overwrite
-- the current environment such as the player-tables, tk info etc.

-- Server hooks
module('server', package.seeall)
package.path  = package.path..";.\\LuaSocket\\?.lua;.\\Scripts\\Addons\\Servman3\\LuaSocket\\?.lua;.\\Scripts\\Addons\\Servman3\\LuaSerializer\\?.lua"
local lfs = require("lfs")
local Factory = require('Factory')
local Serialize = require('Serializer')

net.log("SERVMAN:SERVER Script loading")

sm_flavor = "DCS:World 1.2.14"
sm_versionmajor = 3
sm_versionminor = 1
sm_build = 1
smversionstring = string.format("SERVMAN v.%d.%d.%d for %s", sm_versionmajor, sm_versionminor, sm_build,sm_flavor)
sm_short=string.format("SERVMAN %d.%d.%d:", sm_versionmajor, sm_versionminor, sm_build)
smdebug = false

-- Note to self, WIP, we need to support loading "Saved Games\DCS nnnnn\ServMan"
sm_rootpath = 'Scripts/Addons/ServMan3'
sm_custompath = lfs.writedir()..'ServMan3'
sm_logpath = lfs.writedir()..'Logs'
local file_banlist = "bantables.lua"

--misc. vars
--variables holding coroutines vor voting
local co_missionpoll
local co_missionvote
local co_votekick
--server commands tables
local srvact
local subact_v
local _
local _f
local load_config
local initerrmsg
local initerr = false
local compileerr = false
local compileerrmsg = ""
local last_MOTD=os.time()
local last_MANN=os.time()

local MANN_timers
local last_MANN_interval

local counter=0
local MOTD_playerconnect=false
sm_currconfig = sm_currconfig or ''
sm_prevconfig = sm_prevconfig or ''
missionfolder = 'D:\\Users\\aj\\Saved Games\\DCS.openbeta\\missions\\squad\\'

-- init the first time compile
if not servman_initcompleted then
	net.log("SERVMAN:SERVER Initializing")

	servman_initcompleted=true 	-- signal to load config
	lfs.mkdir(sm_custompath)
	
	if not current_mission then current_mission="" end		--name of current mission (string)
	mutex = false
	mission_starttime=0		--starttime of current mission (number)
	locked=false			--if true server is locked (boolean)

	local timestamp = os.date("%Y%m%d") .. "-" .. os.date("%H%M")
	sm_servlog = sm_logpath.."/ServMan-Serverlog-" .. timestamp .. ".log"
	sm_chatlog = sm_logpath.."/ServMan-Chatlog-" .. timestamp .. ".log"	
	
	-- global logging
	smlogger, logerr = io.open(sm_servlog, "w")
	if not smlogger then
		net.log("ERROR: Could not create ServMan log. Error: ".. logerr)
	else
		net.log("SERVMAN logging enabled: "..sm_servlog)
	end
	
	bantables = {}

	--table for banned IPs, key is IP as string, value is true
	banned_hosts={}

	--table with banned IP ranges from serverconfig.lua file, contains subtables with string fields "from" and "to"
	banned_IP_ranges = {}

	--table with banned names
	banned_names = {}

	--table of subadmins from serverconfig.lua file, key is name (string), value is password (string)
	subadmins = {}

	--table of missions in Missions/Multiplayer folder, index is mission number, value is filename (string)
	mp_missions = {}

	--table of players kicked during server session, index is IP (string),
	--value is subtable with fields "last_time" and (number) and "kicks" (number)
	kicked_players = {}
	
	-- added by grimes 
	kick_phrase = {}
	--table with server configuration variables from serverconfig.lua file
	conf = {}
	
	--table of players, index is player ID, value is table with fields "name" (string), "addr" (string), "is_subadmin" (boolean), 
	--"teamkills" (number), "AI_teamkills" (number) , "friendly_fire" (number), "collisions" (number), "login_tries" (number) , 
	--"will_be_kicked" (bool), "ping_warnings" (number)
	-- Change for FC2, players must be local
	if not tblPlayersSrv then tblPlayersSrv = {} end
	names = {}

	-- command interface
	funcprefix = 'servercmd_' -- all servercommands will be prefixed with this

	-- just set a minimum default
	dynamicsettings = {
			kicks 			= { on = 'server.conf.bankick_enabled=true',			off = 'server.conf.bankick_enabled=false' }
		}

	permlevel = {
		anon = 0, -- anyone connecting for the first time.
		friend = 1, -- It's not in use yet. Implemented for later use.
		squad = 2, -- squad login puts you at this level
		admin = 3, -- another admin login puts you here. If you disable squad logins, you log directly in to this level.
		superadm = 4 -- intended to be the local server only, not fully implmented as that quite yet.
		}

	-- set a minimum of defaults, if server crashes, these commands should work.
	cmdprf = '/' -- prefix for servercommands in the chat. Can be changed to another character.
	maincmd = {
		log		= { cmd = "login",		perm = permlevel.anon,		cat = "player,admin" },
		logo 	= { cmd = "logout",		perm = permlevel.anon,		cat = "player" },
		rec		= { cmd = "recompile",	perm = permlevel.admin,		cat = "server" },
		rest	= { cmd = "restart",	perm = permlevel.squad,		cat = "mission" },
		h		= { cmd = "help",		perm = permlevel.anon,		cat = "info" },
		set		= { cmd = "set",		perm = permlevel.admin,		cat = "test" }
	}

	--if server.dump_table~=nil then maincmd["db"] = { cmd = "db", 		perm = permlevel.admin,		cat = "debug" } end

	-- just a very minimum of help, the rest should come from the external conf.
	mainhelp = {
		l 		= { options = "{ <mission-id> }",
						short = "Loads a mission, use '"..cmdprf.."missions to view mission-id's.",
						more = "To see which mission that is active, use the '"..cmdprf.."mission command, and look for the --><-- around the mission number."
					},
		m 		= { options = "",
						short = "List missions available",
						more = "Notice the active mission got -><- around the number"
					},
		lock 	= { options = "",
						short = "Locks the server, preventing new players from joining.",
						more = "When the server is locked, new players cannot join. Use '"..cmdprf.."unlock' to open it again." }
	}
	
else
	-- This section takes care of what happens when we recompile while server is running.
	net.log("SERVMAN:SERVER Online compile")
end



_ = function(msg) return msg end	


------------------------------------------------------------------
-- Standard DCS functions
------------------------------------------------------------------

function log_write(str)
	if nil==str then return end
	if not conf.loglevel then return end
	if conf.loglevel == 0 then return end
	if conf.loglevel == 1 and string.find(str,"::") then return end
	if conf.loglevel == 2 and string.find(str,":::") then return end
	net.log(str)
	if smlogger then
		smlogger:write(os.date("%c") .. " : " .. str,"\r\n")
		smlogger:flush()
	end
end

local function unit_type(unit) return net.get_unit_property(unit, 4) or "" end

local function side_name(side)
	if side == 0 then return "Spectators"
	elseif side == 1 then return "Red"
	else return "Blue" end
end

function on_net_start()
	net.log("SERVMAN:SERVER::on_net_start()")	
	if conf.loglevel == nil then
		conf.loglevel = 2
	end
	
	log_write("SERVER::on_net_start(server)")
	log_write("----------------------------------------")
	log_write(string.format(smversionstring))
	log_write("----------------------------------------")
	
	--load server config, this is the earliest possible moment to do so on a normal startup (non recompile situation)
	if not servman_initcompleted then load_config() end

	-- The standard DCS nametable, might use this instead of our own.
	names = {}
	names[net.get_name(1)] = 1
end

function on_mission(filename)
	net.log("SERVMAN:SERVER::on_mission(filename)")	
	log_write("----------------------------------------")
	local mem = gcinfo()
	log_write("SERVER::LUA Memory consumption: "..tostring(mem).." KB")
	log_write(string.format("SERVER::on_mission(%s)",tostring(filename)))
	log_write(_f("Loaded mission %q", tostring(filename)))
	
	paused_on_miz(true) --missions start paused

	current_mission = filename
	mission_starttime = os.time()
	log_write("SERVER::Mission started at: "..tostring(mission_starttime))
	
	--reload config (to update it at server runtime)
	load_config()
	--reset teamkill stats to zero if enabled
	if conf.reset_TK_stats_on_miz then
		for id, p in pairs(tblPlayersSrv) do
			p.teamkills = 0
			p.AI_teamkills = 0
			p.friendly_fire = 0
			p.collisions = 0
			p.ping_warnings = 0
			log_write(_f("SERVER::on_mission, Reset TK/FF stats for [%d] %q (%q)", tostring(id), tostring(p.name), tostring(p.addr)))			
		end
		log_write(_("Teamkill stats have been reset to zero!"))
	end
	
end

function on_net_stop()
	--clean up
	net.log("SERVMAN:SERVER::on_net_stop()")	
	log_write("SERVER::on_net_stop()")
	current_mission = nil
	mission_starttime = nil
	locked = nil
	mutex = nil
	last_MOTD = nil
	last_MANN = nil
	co_missionpoll = nil
	co_missionvote = nil
	co_votekick = nil
	banned_hosts = nil
	banned_IP_ranges = nil
	banned_names = nil
	kick_phrase = nil
	subadmins = nil
	conf = {}
	tblPlayersSrv = {}
	missions = nil
	kicked_players = nil
	counter = 0
	if smlogger then
		smlogger:close()
		smlogger = nil
	end
	if chatlogger then
		chatlogger:close()
		chatlogger = nil
	end	
	names = {}
end

function on_process()
	--check if events need to be fired every conf.timer_interval frames
	if conf.timer_interval ~= nil and counter ~= nil then
		if counter >= conf.timer_interval then
			counter = 0
			check_timeouts()
		else
			counter = counter + 1
		end
	end
end

function on_connect(id, addr, port, name, ucid)
-- --[[ banning example
	-- if banned_hosts and banned_hosts[addr] then
		-- -- extend the ban
		-- --banned_hosts[addr] = os.time()
		-- return "Banned by IP", false
	-- end
	-- if banned_names and banned_names[name] then
		-- -- extend the ban
		-- --banned_names[name] = os.time()
		-- return "Banned by name", false
	-- end
	-- if banned_serials and banned_serials[ucid] then
		-- -- extend the ban
		-- --banned_names[name] = os.time()
		-- return "Banned by UniqueClientID", false
	-- end
-- ]]

	-- -- write to log
	-- log_write(string.format("Connected client: id = [%d], addr = %s:%d, name = %q, ucid = %q",
		-- id, addr, port, name, ucid))
	-- net.recv_chat(string.format("Connected client: id = [%d], addr = %s:%d, name = %q, ucid = %q", id, addr, port, name, ucid))

	-- if names[name] then
		-- return _("Please, provide a unique nickname."), false
	-- end

	-- names[name] = id

	-- return true
	
	log_write(string.format("SERVER:on_connect(%d, %s, %d, %q, %q)",id, addr, port, name, ucid))

	ucid = trim(ucid)
	addr = trim(tostring(addr))
	name = trim(tostring(name))	

	players_changed(id, addr, port, name, ucid)
	return true	
end

function on_disconnect(id, err)
	-- local n = net.get_name(id)
	-- if names[n] then
		-- names[n] = nil
	-- end
	-- log_write(string.format("Disconnected client [%d] %q", id, n or ""))

	log_write(string.format("SERVER::on_disconnects, %s)",id,err))
	players_changed(id)	
end

--
function on_set_name(id, new_name)
	-- -- check against ban list
	-- --if banned_names[new_name] then
	-- --	kick(id, "banned name")
	-- --end
	-- old_name = net.get_name(id)
	-- if names[new_name] then
		-- log_write(string.format("Client [%d] %q tried to changed name to %q", id, old_name, new_name))
		-- return old_name
	-- end
	-- names[old_name] = nil
	-- names[new_name] = id
	-- log_write(string.format("Client [%d] %q changed name to %q", id, old_name, new_name))
	-- return name

	old_name = net.get_name(id)
	
	--check against list of banned names
	if banned_names[trim(new_name)] then
		local msg = "Name is banned, change name and retry."
		local bkevent = "name_banned"
		BanKickManager(id,bkevent,msg)
		return old_name
	end
	
	--log new name
	tblPlayersSrv[id].name = new_name
	log_write(_f("Client id = [%d], addr = %s, oldname = %q changed name to %q", 
			id, tblPlayersSrv[id].addr, old_name, new_name))
	return new_name
	
end

function on_set_unit(id, side, unit)
	-- name = net.get_name(id)
	-- if unit ~= "" then
		-- msg = string.format("Client [%d] %q joined %s in %q(%s)", id, name, side_name(side), unit_type(unit), unit)
	-- else
		-- msg = string.format("Client [%d] %q joined %s", id, name, side_name(side))
	-- end
	-- log_write(msg)
	-- return true
	name = net.get_name(id)
	if unit ~= "" then
		msg = _f("Client [%d] %q joined %s in %q(%s)", id, name, 
				side_name(side), unit_type(unit), unit)
	else
		msg = _f("Client [%d] %q joined %s", id, name, side_name(side))
	end
	log_write(msg)
	return true	
	
end

function on_chat(id, msg, all)
	-- if msg=="/mybad" then
		-- return string.format("I (%d, %q) have made a screenshot at %f", id, net.get_name(id), net.get_model_time())
	-- elseif string.sub(msg, 1, 1) == '/' then
		-- net.recv_chat("got command: "..msg, 0)
		-- return
	-- end
	-- return msg
	
	log_write(_f("SERVER:::on_chat(id=%q) (toall=%q) msg=%q",tostring(id), tostring(all), tostring(msg)))

	if not tblPlayersSrv[id] then
		return "Problem: player id=%d doesnt exist"
	end
	
	--Screenshot message
	if msg=="/mybad" then
		msg = _f("[%s] %q made a screenshot", tostring(id), tostring(tblPlayersSrv[id].name))
	end
	
	-- new commandparser
	if string.sub(msg, 1, 1) == cmdprf then
		local msg2 = string.format("Received command: %q from %q", msg, tostring(tblPlayersSrv[id].name))
		serv_msg(msg2, 1)
		return servercommand(id, msg)
	end
	
	if conf.kick_on_phrase then
		local newMsg = deepCopy(msg) -- this code modifies all messages, so make a true copy of it
		local exclude = {'%-', '%(', '%)', '%_', '%[', '%]', '%.', '%#', '% ', '%{', '%}', '%$', '%%', '%?', '%+', '%^'} -- from mist, removes listed char cause lua cant search em
		for i , str in pairs(exclude) do
			newMsg = string.gsub(newMsg, str, '')
		end
		newMsg = string.lower(newMsg)
		for i, phrase in pairs(kick_phrase) do
			for x, str in pairs(exclude) do
				phrase = string.gsub(phrase, str, '')
			end
			phrase = string.lower(phrase)
			if string.find(newMsg, phrase) then
				log_write('Kicking user for saying the following: ' .. phrase)
				-- could bypass this? if I really wanted to I guess. 
				-- But need an admin ID for message to not state "autmoatically kicked"
				-- suggest server owner, cause why not?
				
				BanKickManager(id, 'admin', '---------Write Reason Here-----------')
				--kick the fool
				return nil  -- chat message will show up in logs but it won't be displayed on the server for everyone.
				
				
			end
		end
	end

	-- prefix for Teammessage in chatlog
	if not all then
		msg = "#TEAMMSG : " .. msg
	end
	
	--log chat in chatlog, all messages.
	if conf.log_chat then chatlog_write(id, msg) end
	return msg	
	
end



------------------------------------------------------------------
-- Command Interface
------------------------------------------------------------------
	
-- Main commands v.2
-- order of shortcut matters, first is preffered until a better match is found.
-- best practise would be to put non-volatile commands first / shortest.

-- helper, parses commands
local function cmdparser(srvstr)
	srvstr = string.lower(srvstr)
	local firstcmd = srvstr:match(cmdprf.."%a+") -- first word in command
	if not firstcmd then return end -- wasnt a command anyway
	local therest = trim(srvstr:sub(firstcmd:len()+2))
	local count = 0
	
	for key, val in pairs(maincmd) do
		local findpattern = '('..cmdprf..key..'%a*)' -- findpattern for shortest variant of the command
		local cmdmatch, count = string.gsub(firstcmd, findpattern, function(x) return ''..cmdprf..val.cmd..'' end) -- expands the shortcmd into a full cmd
		if count and count>0 and cmdmatch:find(firstcmd) then
			return key, cmdmatch, tonumber(val.perm), therest
		end
	end
end

-- helper, dynamic call to the server command requested.
local function callfunction(id, module, command, parameters)
	if smdebug then
		for k,v in ipairs(parameters) do
			serv_msg(string.format("callfunction args:%d = %q",k,tostring(v)))
		end
	end	
	if not id then return nil, "No userid provided" end -- require ID, most of our commands will need it.
    if module then
        command = module[command]
		if command then
			local result, err = command(id,parameters)
			return result, err
		else
			return nil, "No such function"
		end
    else
		return nil, "Invalid module"
    end 
end 



-- Helper, server command parser
-- This one is responsible for translatig the Player-input into something useful, and return
-- output to the player where needed.
function servercommand(id, msg)
	net.log("SERVMAN:SERVER:servercommand("..id..","..msg..")")
	local cmdkey, cmdfull, cpermlevel, cmdparams = cmdparser(msg) -- parses, splits and validates a command
	if cmdfull and cmdfull~="" then
		-- first of all, check permissions for the command
		if tblPlayersSrv[id].permlevel<cpermlevel then 
			serv_msg(_f("Permission denied"),id)
			return
		end
		cmdfull = cmdfull:sub(2)
		local cmdfunc = funcprefix..cmdfull
		-- asked for help or perform command?
		if cmdparams and cmdparams~="" then
			if cmdparams:find("?") then
				-- help requested
				local cmdhelper, err = servercmd_helphelper(id,cmdkey)
				if cmdhelper then
					for k,v in ipairs(cmdhelper) do
						serv_msg(string.format("%s",v),id)
					end
				else
					if err then
						serv_msg(_f("%s",err),id)
					else
						serv_msg(_f("Sorry, no help available for %q",tostring(cmdfull)),id)
					end
				end
				return
			else
				local paramfields
				if cmdfull=='ban' then
					-- some commands may require comments, shouldnt use the split for this later.
					-- exception, okai maybe we need to rethink this part later.					
					paramfields = split(cmdparams," ",32)
				else
					paramfields = split(cmdparams," ",4) -- max number of supported parameters
				end
				cmdparams = paramfields
			end
		end
		
		-- Call the command
		local succ, err = callfunction(id,server,cmdfunc,cmdparams)
		if err then
			local result = string.format("Command failed: %q, %s",msg,tostring(err))
			serv_msg(result,id)
			log_write(result)
		else
			if succ then -- only when there is something meaningfull to say
				local succmsg
				-- differ between global return msg and msg directed at player
				if succ.id and succ.msg then
					succmsg = string.format("%s",tostring(succ.msg))
					serv_msg(succmsg,succ.id)
				else
					succmsg = string.format("%s",tostring(succ))
					serv_msg(succmsg)
				end
				log_write(succmsg)
			end
		end
	else
		serv_msg(string.format("No such Command: %s",msg),id)
	end
end



-- Helper, command syntax
function helper_cmdsyntax(cmdkey)
	-- merges the short form and full form of a command into a required+optional view
	-- ex pl and players becomes pl[ayers]
	local key, len, merged, ssub
	key = tostring(cmdkey)
	cmdfull = maincmd[cmdkey].cmd
	len = string.len(key)
	
	if len==string.len(cmdfull) then
		merged = string.format("%s",key)
	else
		ssub = string.sub(cmdfull,len+1)
		merged = string.format("%s[%s]",key,ssub)
	end
	return merged
end

function servercmd_helphelper(id,cmdkey)
	-- compiles full help for a specific command.
	local function helpcompiler(chelp, helpsect, sectintro )
		if helpsect and type(helpsect)=='table' then
			table.insert(chelp,sectintro)
			for i,v in ipairs(helpsect) do table.insert(chelp,"   "..v) end
		elseif helpsect and type(helpsect)=='string' then
			table.insert(chelp,sectintro..helpsect)
		else
			table.insert(chelp,"*** ERR: <helpsection missing>")
		end
	end
	
	local helpcomp
	helpcomp = {}
	
	if mainhelp[cmdkey] then
		helpcompiler(helpcomp, mainhelp[cmdkey].short,	"Description:  ")
		helpcompiler(helpcomp, mainhelp[cmdkey].options,	"Syntax:         "..cmdprf..helper_cmdsyntax(cmdkey).." ")
		helpcompiler(helpcomp, mainhelp[cmdkey].more,	"More info:     ")
	else
		table.insert(helpcomp,"*** ERR: <helpsection missing>")
	end
	return helpcomp

end



------------------------------------------------------------------
-- ServMan Commands
------------------------------------------------------------------

--displays information about enabled server functionality
function servercmd_info(id,...)
	local args = ...
	local onoff = function(x) if x then return "On" else return "Off" end end
	-- global disable_events, WIP
	-- if server.config.disable_events then
		-- serv_msg(_("MESSAGEFILTER(1)=On. Servman filters Messages sent to the MP Clients."), id)
	-- end
	-- if server.disable_events then
		-- serv_msg(_("MESSAGEFILTER(2)=On. Servman filters Messages sent to the MP Clients."), id)
	-- end	
	if not conf.bankick_enabled then
		serv_msg(_("ALL automated Kicks/Bans are DISABLED"), id)
	else
		if conf.bankick_vote then
			serv_msg(_f("Votekicking: Enabled: Minimum %d percent.",conf.min_votes_in_percent), id)
		else
			serv_msg(_("Votekicking: Disabled"), id)
		end
		if conf.kick_after_teamkills > 0 then
			infmsg1 = _f("%d Teamkill, ",conf.kick_after_teamkills)
		else
			infmsg1 = _f("Teamkills=OFF, ")
		end
		if conf.kick_after_AI_teamkills > 0 then
			infmsg2 = _f("%d AI-teamkill, ",conf.kick_after_AI_teamkills)
		else
			infmsg2 = _f("AI-teamkills=OFF, ")
		end
		if conf.kick_after_friendly_fire > 0 then
			infmsg3 = _f("%d Friendly Fire incidents.",conf.kick_after_friendly_fire)
		else
			infmsg3 = _f("Friendly Fire=OFF.")
		end
		serv_msg(_f("Automatic kick: %s%s%s",infmsg1,infmsg2,infmsg3),id)
		if conf.kick_below_score < 0 then 
			serv_msg(_f("Automatic kick: Score below %d", conf.kick_below_score), id)
		end
		if conf.wait_after_kick > 0 then
			serv_msg(_f("Penalty time: %d minutes", conf.wait_after_kick), id)
		end
		if conf.autoban_after_kicks > 0 then
			serv_msg(_f("Automatic ban: After %d kicks", conf.autoban_after_kicks), id)
		end

		serv_msg(_f("Ban/Kick reacts on: Name=%s, IP=%s, UCID=%s",onoff(conf.bankick_byname),onoff(conf.bankick_byip),onoff(conf.bankick_byucid)), id)
		
		if conf.kick_after_max_ping_events > 0 then
			serv_msg(_f("Max. average ping: %d ms - Autokick on: %d ping-warnings.", conf.max_average_ping, conf.kick_after_max_ping_events), id)
		end
	end
	if conf.missionvotes then
		serv_msg(_f("Missionvotes/-polls: Enabled. Minimum %d percent.",conf.min_votes_in_percent), id)
	else
		serv_msg(_("Missionvotes/-polls: Disabled"), id)
	end	

	if conf.rotate_miz_after > 0 then
		serv_msg(_f("Mission Rotation: %d minutes", conf.rotate_miz_after), id)
	elseif conf.restart_miz_after > 0 then
		serv_msg(_f("Mission Restart: %d minutes", conf.restart_miz_after), id)
	else
		serv_msg(_("Automatic mission Restarting/Rotation: Disabled"), id)
	end

	if conf.reset_TK_stats_on_miz then
		serv_msg(_("Teamkill stats will be reset to zero after each mission"), id)
	end

	if conf.masterbanlist_URL ~= "" then
		serv_msg(_("The server uses a masterbanlist"), id)
	end
	if sm_currconfig~='' then
		serv_msg(_f("SERVER CONFIG in effect: %s",string.upper(sm_currconfig)), id)
	else
		serv_msg(_f("SERVER CONFIG in effect: %s","System Default"), id)
	end
end

function servercmd_version(id,...)
	local args = ...
	return serv_msg(smversionstring)
end

--displays a list of server commands available to regular players
function servercmd_help(id,...)
	local args = ...
	local listcat

	local rows = 0
	local maxrows = 8	
	if args[1] and tostring(args[1]) then
		listcat = string.lower(tostring(args[1]))
		if listcat == "logdump" then
			maxrows = 2000
			serv_msg(_f("--->  Dumping commands to ServMan-ServerLog <---"),id)
		end
	end
	
	local mrg, chelp, chelpfull
	local cmdkey, cmdval
	local chelp, chelpshort

	serv_msg(_f("--->  For more info, try the '"..cmdprf.."command ?' per command. <---"),id)
	if not listcat then 
		serv_msg(_f("--->  Help category, type full word or parts of it: info, player, vote, mission, admin, server"),id)
		rows = rows + 1
	end
		
	for cmdkey, cmdval in pairs(maincmd) do
		if listcat == "logdump" then
			-- prints all the commands, can be gathered in the Servman Serverlog
			log_write(_f("---------------------------------------------------------"))
			chelpfull = servercmd_helphelper(id,cmdkey)
			for i,v in pairs(chelpfull) do
				log_write(_f("%s",v))
			end
			if rows>maxrows then
				log_write(_f("... more commands available, but not enough rows. Use categories to filter the list."))
				return
			end			
		elseif cmdval.perm<=tblPlayersSrv[id].permlevel then
			mrg = helper_cmdsyntax(cmdkey)
			if mainhelp[cmdkey] and mainhelp[cmdkey].short then
				chelpshort = mainhelp[cmdkey].short
			end
			chelp = string.format("  %s%s",cmdprf,mrg) .. " - " .. chelpshort
			if not string.find(cmdval.cat,"hide") then
				if string.find(string.lower(chelp),string.lower(listcat)) then
					serv_msg(chelp,id)
					rows = rows + 1
				end
			end
			if rows>maxrows then
				serv_msg(_f("... more commands available, but not enough rows. Use categories to filter the list."),id)
				return
			end
		end
	end
end


-- writes a report message (send via the /report:str command) to the chatlog
function servercmd_report(id, str)
	if conf.log_chat then
		msg = _f("%s : REPORT: %q (ID=%d) wrote: %q\n", os.date("%c"), net.get_name(id), id,  string.sub(str, 9, -1))
		chatlog_write(id, msg)
		serv_msg(_("Your message has been reported"), id)
	else
		serv_msg(_("Reporting is disabled!"), id)
	end
end

function servercmd_yes(id,...)
	local args = ...
	local msg = cmdprf.."yes"
	if co_votekick then
		votekick("vote",id,msg) return end
	if co_missionvote then 
		missionvote("vote",id,msg) return end
	return nil, "No active votes running, you can't vote now"
end

function servercmd_no(id,...)
	local args = ...
	local msg = cmdprf.."no"	
	if co_votekick then 
		votekick("vote",id,msg) return end
	if co_missionvote then
		missionvote("vote",id,msg) return end
	return nil, "No active votes running, you can't vote now"
end

function servercmd_whoami(id,...)
	local args = ...
	if args and tcount(args)>0 then
		dumpplayer_info(id, args)
	else
		dumpplayer_info(id)
	end
	return
end


--displays a list of players
function servercmd_players(pid,...)
	local args = ...

	local pllist
	if args and tcount(args)>0 then
		pllist = get_playerbyargs(pid, args)
	else
		pllist = tblPlayersSrv
	end

	local index = 1
	local len, msg, leftEntry
	serv_msg(_("PLAYERLIST: Player ID - Playername - Human-/AI-Teamkills/Friendly Fire/Collisions"), pid)
	local srvpl, plid
	for id, player in pairs(pllist) do
	
		plid = tonumber(player.id)
		if plid==nil then plid = tonumber(id) end
		srvpl = tblPlayersSrv[plid]
		
		--entry in left column			
		if index == 1 then
			len = string.len(srvpl.name)
			if len > 40 then
				leftEntry = string.format("%d - %q - %s/%s/%s/%s", plid, string.sub(srvpl.name, 1 , 40), 
						tostring(srvpl.teamkills), tostring(srvpl.AI_teamkills), tostring(srvpl.friendly_fire), tostring(srvpl.collisions))
			else
				leftEntry = string.format("%d - %q - %s/%s/%s/%s", plid, srvpl.name, 
						tostring(srvpl.teamkills), tostring(srvpl.AI_teamkills), tostring(srvpl.friendly_fire), tostring(srvpl.collisions))
			end
			index = 2
		--entry in right column
		else
			msg = string.format("%s   |   %d - %q - %s/%s/%s/%s", leftEntry, plid, srvpl.name, 
					tostring(srvpl.teamkills), tostring(srvpl.AI_teamkills), tostring(srvpl.friendly_fire), tostring(srvpl.collisions))
			serv_msg(msg, pid)
			index = 1
		end


	end
	
	if index == 2 then --last entry in left column
		serv_msg(leftEntry, pid)
	end
end


--processes login of server subadmin, kicks player after 3 failed login attempts
--note that invalid login tries will also be registered even if no subadmins are appointed
function servercmd_login(id,...)
	local args = ...
	
	if not args[1] then local succ, err = servercmd_logout(id) return succ,err end
	
	-- if squad_login is disabled, we should only expect 1 argument.
	-- if squad login is enabled and we get 2 arguments, we then know it is a squad login.
	-- if squad login is enabled, we only get 1 argument
	-- 		it will REQUIRE him to be authenticated at squadlevel first.
	
	local attemptfailed = true
	local name = net.get_name(id)
	local numtokens, tokensreq 
	numtokens = 0
	tokensreq = 0
	
	if conf.squad_login_enable and tblPlayersSrv[id].permlevel<permlevel.squad then
		-- new SQUAD method.
		-- but only for squad levels, when already logged in for the squad levels, continue to subadmin.
		
		local check_passed
		local qualify
		local plname = string.lower(tblPlayersSrv[id].name)
		local err
		local sq_uname
		local sq_passw
		
		
		-- get the numbers of tokens required
		if conf.squad_prefix ~= "" then tokensreq = tokensreq +1 end
		if conf.squad_suffix ~= "" then tokensreq = tokensreq +1 end
		if conf.squad_username ~= "" then tokensreq = tokensreq +1 end
		if conf.squad_password ~= "" then tokensreq = tokensreq +1 end
		
		--serv_msg(_f("DEBUG tok-req: %d",tokensreq))
		--- Squad prefix / suffix method
		if conf.squad_prefix ~= "" then
			qualify = string.lower(conf.squad_prefix)
			check_passed = nil
			check_passed = string.find(string.sub(plname,1,string.len(qualify)),qualify)
			if check_passed then
				numtokens = numtokens +1
				--serv_msg(_f("DEBUG passed squad_prefix: qualify[%d] = %q, plname[%d] = %q",string.len(qualify), qualify, string.len(plname), plname), id)
			end
			sq_uname = ""
			sq_passw = ""
			qualify	= ""
		end
		
		if conf.squad_suffix ~= "" then
			qualify = string.lower(conf.squad_suffix)
			check_passed = nil
			check_passed = string.find(plname,qualify,-string.len(qualify))
			if check_passed then
				numtokens = numtokens +1
				--serv_msg(_f("DEBUG passed squad_suffix: qualify[%d] = %q, plname[%d] = %q",string.len(qualify), qualify, string.len(plname), plname), id)
			end
			sq_uname = ""
			sq_passw = ""
			qualify	= ""
		end

		-- username+password
		if conf.squad_username~="" and conf.squad_password ~= "" then
			-- assume two args, both.
			if tcount(args)>=2 then
				sq_uname = string.lower(args[1])
				sq_passw = args[2]
				if sq_uname==string.lower(conf.squad_username) and sq_passw==conf.squad_password then
					--serv_msg(_f("DEBUG Success SQ USER+PASS: UN %q -> arg1 %q, PW %q -> arg2 %q",string.lower(conf.squad_username), sq_uname, conf.squad_password, sq_passw), id)	
					numtokens = numtokens +2
				end
				sq_uname = ""
				sq_passw = ""
			else
				err = "Not enough parameters"
			end
		end			
		
		-- password only
		if conf.squad_password ~= "" and conf.squad_username=="" then
			-- assume one arg. password only.
			if tcount(args)>=1 then
				sq_passw = args[2]
				if sq_passw==conf.squad_password then
					numtokens = numtokens +1
				end
				sq_uname = ""
				sq_passw = ""
			else
				err = "Not enough parameters"
			end
		end	
		
		-- username only
		if conf.squad_username~="" and conf.squad_password == "" then
			if tcount(args)>=1 then
				sq_uname = string.lower(args[1])
				if sq_uname==string.lower(conf.squad_username) then
					numtokens = numtokens +1
				end
				sq_uname = ""
				sq_passw = ""
			else
				err = "Not enough parameters"
			end
		end
		-- END of new SQUAD method.
	end
	
	if err then
		-- human error?
		tblPlayersSrv[id].login_tries = tblPlayersSrv[id].login_tries + 1
		log_write(_f("%d. invalid Squad login attempt from %q", tblPlayersSrv[id].login_tries, name))
		serv_msg(_(err), id)
		if tblPlayersSrv[id].login_tries>=3 then
			serv_msg(_("Mr Holmes, Dr.Watson here. You're not doing this right. Ask for help from your CO."), id)
			if tblPlayersSrv[id].login_tries >= 6 and id ~= 1 then
				return BanKickManager(id,"login","6 failed squad-login attempts")
			end
		else
			return
		end
		return
	end

	if numtokens~=tokensreq and not err then
		-- bad things happen to those who ....
		tblPlayersSrv[id].login_tries = tblPlayersSrv[id].login_tries + 1
		log_write(_f("%d. invalid squad login attempt from %q", tblPlayersSrv[id].login_tries, name))
		serv_msg(_f("%d. invalid squad login attempt from %q", tblPlayersSrv[id].login_tries, name))
		--serv_msg(_("Failed squad login attempt!"), id)
		if tblPlayersSrv[id].login_tries >= 3 and id ~= 1 then
			return BanKickManager(id,"login","3 failed squad-login attempts")
		end
		return
	end

	local password = args[1]
	local message

	--[[ DEBUG/ - Ajax
	local ajaxmsg = ""
	for i,v in pairs(subadmins) do
		ajaxmsg = ajaxmsg.." ;  "..i
	end
	serv_msg(ajaxmsg)
	
	message = "Squad login enabled = "..tostring(conf.squad_login_enable)
	log_write(message)
	serv_msg(message)
	
	message = "Squad admins count = "..tostring(#subadmins)
	log_write(message)
	serv_msg(message)
	
	message = string.format("Current name = %q",name)
	log_write(message)
	serv_msg(message)
	--]]
	
	if conf.squad_login_enable and tblPlayersSrv[id].permlevel>=permlevel.squad and	tblPlayersSrv[id].permlevel<permlevel.admin then
		-- already logged in with squad, can proceed to admin.
		password = args[1]
		if subadmins and subadmins[name] == password then -- login successful
			tblPlayersSrv[id].is_subadmin = true
			tblPlayersSrv[id].permlevel = permlevel.admin
			tblPlayersSrv[id].login_tries = 0
			message = _f("Subadmin %q logged in", name)
			log_write(message)
			serv_msg(message)
		elseif subadmins and subadmins[name]~=password then
			tblPlayersSrv[id].login_tries = tblPlayersSrv[id].login_tries + 1
			log_write(_f("%d. invalid subadmin login attempt from %q", tblPlayersSrv[id].login_tries, name))
			if tcount(args)>1 then serv_msg(_f("NOTE: Subadmin requires only password, not a username. You used %d parameters for your login.",tcount(args)), id) end
			serv_msg(_("Failed subadmin login attempt!"), id)
			if tblPlayersSrv[id].login_tries >= 3 and id ~= 1 then
				return BanKickManager(id,"login","3 failed subadmin-login attempts")				
			end		
		else
			serv_msg(_("Already logged in at max available level for you!"), id)
		end
	elseif conf.squad_login_enable and tblPlayersSrv[id].permlevel==permlevel.anon then
		-- up to Squad level first, if Squad is enabled.
		tblPlayersSrv[id].permlevel=permlevel.squad
		tblPlayersSrv[id].login_tries = 0
		message = _f("Squad member %q logged in", name)
		log_write(message)
		serv_msg(message)
	elseif conf.squad_login_enable==false and tblPlayersSrv[id].permlevel==permlevel.anon then
		if subadmins and subadmins[name] == password then -- login successful
			tblPlayersSrv[id].is_subadmin = true
			tblPlayersSrv[id].permlevel = permlevel.admin
			tblPlayersSrv[id].login_tries = 0
			message = _f("Subadmin %q logged in", name)
			log_write(message)
			serv_msg(message)
		else
			tblPlayersSrv[id].login_tries = tblPlayersSrv[id].login_tries + 1
			log_write(_f("%d. invalid subadmin login attempt from %q", tblPlayersSrv[id].login_tries, name))
			if tcount(args)>1 then serv_msg(_f("NOTE: Subadmin requires only password, not a username. You used %d parameters for your login.",tcount(args)), id) end
			serv_msg(_("Failed subadmin login attempt!"), id)
			if tblPlayersSrv[id].login_tries >= 3 and id ~= 1 then
				return BanKickManager(id,"login","3 failed subadmin-login attempts")				
			end		
		end
	else
		serv_msg(_("Already logged in!"), id)
	end
end

--logs out a subadmin. The server cannot log out
function servercmd_logout(id)
	if id ~= 1 and tblPlayersSrv[id].permlevel>permlevel.squad then
		tblPlayersSrv[id].is_subadmin = false
		if conf.squad_login_enable then
			tblPlayersSrv[id].permlevel = permlevel.squad
		else
			tblPlayersSrv[id].permlevel = permlevel.anon
		end
		msg = _f("Subadmin %q logged out", tblPlayersSrv[id].name)
		return msg
	elseif id ~= 1 and tblPlayersSrv[id].permlevel>permlevel.anon then
		tblPlayersSrv[id].is_subadmin = false
		tblPlayersSrv[id].permlevel = permlevel.anon
		msg = _f("Squadmember %q logged out", tblPlayersSrv[id].name)
		return msg
	elseif id == 1 then
		return nil, "You cant do that with the server."
	else
		return nil, "Already fully logged out."
	end
end


--displays a list of available missions
function servercmd_missions(pid)
	serv_msg(_("MISSIONLIST: Mission ID - Missionname"), pid)
	local currentmisId = get_currentmissionid(current_mission)
	list_highlight_number(pid,mp_missions,currentmisId)
end


--lets a subadmin load a given mission
function servercmd_load(id, ...)
	local args = ...
	-- extract mission id from command
	--local mission = tonumber(msg)
	local arg = tonumber(args[1]) or tostring(args[1])

	if arg and type(arg)=='string' then
		-- not a number, perhaps its a config?
		if args[1] and string.len(args[1])>1 then
			arg = string.lower(args[1])
		else
			return nil, "Load what? Mission-ID?"
		end
		-- if arg and string.lower(arg)=='conf' then
			-- -- load config
			-- if args[2] and type(args[2])=='string' then
				-- sm_prevconfig = sm_currconfig
				-- sm_currconfig = args[2]
			-- else
				-- return nil, "Which CONF did you want to load? Please specify CONF name"
			-- end
			-- if load_config(sm_currconfig) then
				-- return (_f("Server-configuration Loaded: %s",string.upper(sm_currconfig)))
			-- else
				-- sm_currconfig = sm_prevconfig
				-- return nil,(_("An error occured while loading the Server-configuration"))
			-- end			
		-- else
			-- return nil, "No such file to load."
		-- end
	elseif arg and type(arg)=='number' then
		-- load mission
		if arg == nil or mp_missions[arg] == nil then
			return nil, (_("Invalid mission ID"))
		else
			local miz_name = mp_missions[arg]
			--stop possible missionvotes/-polls
			missionpoll("stop")
			missionvote("stop")
			msg = (_f("Member %q loads mission %q", tblPlayersSrv[id].name, miz_name))
			--net.load_mission("./Missions/Multiplayer/" .. miz_name)
			net.load_mission(missionfolder .. miz_name)
			return msg
		end	
	end
end

--lets a subadmin manage configs
function servercmd_config(id, ...)
	local args = ...
	update_configlist()
	-- list
	if #args==0 then
		config_list()
		return
	end
	
	-- using number
	local arg = tonumber(args[1]) or tostring(args[1])
	if type(arg)=='number' then
		return config_load(arg)
	end
	
	-- using keywords
	local action = string.lower(tostring(args[1]))
	local conf = tonumber(args[2]) or tostring(args[2])
	
	if action and type(action)=='string' then	
		-- list
		if action=='list' then
			config_list()
			return
		elseif action=='load' then
			-- load by number
			if type(conf)=='number' then
				return config_load(conf)
			end
			-- load by name
			local conf_id = get_configidfromname(conf)
			return config_load(conf_id)
		elseif action=='save' then
			-- save by name
			if type(conf)~='string' then
				return (_f("Need a NAME for the %s-action",action))
			end
			return config_save(conf)
		else
			return (_f("Unknown keyword: %q. Please use LOAD or SAVE.",action))
		end
	end
end


--lets a subadmin restart the current mission
function servercmd_restart(id,...)
	--stop possible missionvotes/-polls
	missionpoll("stop")
	missionvote("stop")
	msg = _f("Member %q restarts current mission", tblPlayersSrv[id].name)
	log_write("SERVER::servercmd_restart(id,...)"..msg)
	net.load_mission(current_mission)
	return msg
end



function servercmd_vote(id,...)

	local args = ...
	if args then 
		if tcount(args)>0 then
			-- voting for an existing poll
			if co_missionpoll and string.find(args[1],"^[+-]?%d+$") then missionpoll("vote", id, args[1]) return end
			if co_missionpoll and args[1]=="m" and args[2] and string.find(args[2],"^[+-]?%d+$") then missionpoll("vote", id, args[2]) return end
			-- starting a missionpoll/vote
			if not co_missionpoll and args[1]=="m" and not args[2] then missionpoll("start",id) return end
			if args[1]=="m" and args[2] and string.find(args[2],"^[+-]?%d+$") then missionvote("start",id,args[2]) return end
			-- starts a votekick
			if args[1]=="k" and (not conf.bankick_vote or not conf.bankick_enabled) then
				msg = (string.format("Kicks or Votekicks are disabled"))
				return msg
			end
			if args[1]=="k" and args[2] then
				if string.find(args[2],"^[+-]?%d+$") then
					votekick("start",id,args[2]) 
					return
				elseif string.find(args[2],"^[+-]?%a+$") then
					local plname_list = {}
					plname_list = get_playeridsbyname(args[2])
					if plname_list and #plname_list>1 then
						msg = (string.format("Not a unique playername, please try with a more specific name"))
						return msg
					elseif plname_list and #plname_list==0 then
						msg = (string.format("Not a playername, please try with a less specific name"))
						return msg
					elseif plname_list and #plname_list==1 then
						votekick("start",id,plname_list[1].id)
						return
					else
						msg = (string.format("Couldn't decide which user you wanted to vote for."))
						return msg
					end
				else
					msg = (string.format("Couldn't decide which user you wanted to vote for."))
					return msg
				end
				msg = (string.format("Couldn't decide which user you wanted to vote for."))
				return msg
			end
			-- not recognized as a vote
			if not co_missionpoll then
				msg = (string.format("No missionpoll-polls or votes running - no need to vote."))
				return msg
			else
				msg = (string.format("Not a valid vote"))
				return nil, msg
			end
		elseif args~="" then
			--serv_msg(string.format("DEBUG Checking args : %q",tostring(args)),id)
		elseif args=="" then
			msg = (string.format("No arguments provided, need more data"))
			return nil, msg
		else
			msg = (string.format("Not a valid vote : %q",tostring(args)))
			return nil, msg
		end
	else
		msg = (string.format("Args is nil, not supposed to happen - blame Panzer"))
		return nil, msg
	end
	
	msg = (string.format("Couldn't decipher the command. Not supposed to happen! Blame Panzer!"))
	return nil, msg	
end


--lets a subadmin stop all active votes/polls
function servercmd_stopvotes(id,...)
	votekick("stop")
	missionpoll("stop")
	missionvote("stop")
	msg = (_f("All active votes have been stopped by admin %q", tblPlayersSrv[id].name))
	return msg
end

--lets a player resume the mission
function servercmd_resume(id)
	local msg = _f("Mission resumed by player %q", tblPlayersSrv[id].name)
	net.resume()
	return msg
end

--lets a subadmin pause the mission
function servercmd_pause(id)
	local msg = _f("Mission paused by player %q", tblPlayersSrv[id].name)	
	net.pause()
	return msg
end

--lets a subadmin lock the server
function servercmd_lock(id)
	if not locked then
		locked = true
		msg = (_f("Server locked by admin %q", tblPlayersSrv[id].name))
		return msg
	else
		return nil, (_("Server already locked"))
	end
end

--lets a subadmin unlock the server
function servercmd_unlock(id)
	if locked then
		locked = false
		serv_msg(_("Admin unlocked server"))
		msg = (_f("Server unlocked by admin %q", tblPlayersSrv[id].name))
		return msg
	else
		return nil, (_("Server already unlocked"))
	end
end

--displays time until current mission ends (if enabled)
function servercmd_timeleft(id)
	serv_msg(show_timeleft(), id)
end

function servercmd_timeset(id,...)
	local args=...
	local newtime, msg
	if args[1] then 
		newtime=tonumber(args[1]) or 30
	else
		newtime=30
	end
	local remaining, hrs, mins, secs
	serv_msg(show_timeleft(), id)
	if conf.rotate_miz_after > 0 then
		conf.rotate_miz_after = conf.rotate_miz_after + newtime		
		remaining = conf.rotate_miz_after * 60 - math.floor(net.get_model_time())
		miz_annc_init(remaining)
		secs = remaining % 60
		remaining = (remaining - secs) / 60
		mins = remaining % 60
		hrs = (remaining - mins) / 60
		msg = _f("MISSION TIMER changed to: %dh %dm %ds remaining before loading next mission", hrs, mins, secs)
		return msg
	elseif conf.restart_miz_after > 0 then
		conf.restart_miz_after = conf.restart_miz_after + newtime
		remaining = conf.restart_miz_after * 60 - math.floor(net.get_model_time())
		miz_annc_init(remaining)
		secs = remaining % 60
		remaining = (remaining - secs) / 60
		mins = remaining % 60
		hrs = (remaining - mins) / 60
		--serv_msg(_f("%dh %dm %ds remaining before mission restart", hrs, mins, secs), id)
		msg = _f("MISSION TIMER changed to: %dh %dm %ds remaining before mission restart", hrs, mins, secs)
		return msg
	else
		msg = "Automatic mission restarting/rotating is disabled"
		return nil, msg
	end
end


--displays server rules
function servercmd_rules(id)
	if conf.server_rules ~= "" then
		local line_break = string.find(conf.server_rules, "*")
		local last_break = 0
		serv_msg(_("***** SERVER RULES *****"), id)
		if line_break ~= nil then
			repeat
				serv_msg(string.sub(conf.server_rules, last_break + 1, line_break - 1), id)
				last_break = line_break
				line_break = string.find(conf.server_rules, "*", last_break + 1)
			until line_break == nil
		end
		serv_msg(string.sub(conf.server_rules, last_break + 1, -1), id)
	end
end

--lets a subadmin reload the server configuration
function servercmd_reinit(id,...)
	log_write(_f("Server Configuration reloaded by member %q", tblPlayersSrv[id].name))
	if load_config() then
		return (_("Server Configuration has been successfully reloaded"))
	else
		return nil,(_("An error occured while reloading the Server configuration"))
	end
end

-- Online recompile Servman
function servercmd_recompile(id,...)
	local server_env = getfenv(0) -- get the local env of this session
	local chunkref, err = loadaddon("ServMan3/servman_server.lua",server_env)
	log_write("----------------------------------------")
	if err and err~="" then 
		serv_msg(err, id)
		log_write("RECOMPILE ERROR: "..err)
		compileerr = true
		compileerrmsg = err
	else
		servman_initcompleted=true -- setting true will prevent variables in memory from being overwritten.
		miz_annc_init()
		msg = _f("%q Recompiled and Changed: %s",net.get_name(id),smversionstring)
		return msg
	end
	return
end

--lets a subadmin kick players
function servercmd_kick(id,...)
	local args = ...
	if not args[1] then return nil, "No ID/name(s) provided" end

	if tblPlayersSrv[id].permlevel>=tonumber(maincmd.k.perm) then
		local pllist
		pllist = get_playerbyargs(id, args)	

		local kickplayers = 0
		local plid
		for plkey, pl in pairs(pllist) do
			plid = tonumber(pl.id)
			if not tblPlayersSrv[plid] then
				serv_msg(string.format("Cannot kick [%d] - Invalid player ID",plid),id)
			elseif tblPlayersSrv[plid].permlevel>conf.kickbanlevel then
				plname = tblPlayersSrv[plid].name
				serv_msg(string.format("Cannot kick the player [%d] %q - protected",plid,plname),id)
			else
				plname = tblPlayersSrv[plid].name
				votekick("kick/ban", id, plid) -- stop a possible votekick against this player
				local bkreason = "Kicked by "..tblPlayersSrv[id].name
				local bkevent = "kicked"
				BanKickManager(plid,bkevent,bkreason,id)
				kickplayers = kickplayers +1
				serv_msg(string.format("[%d] %q was kicked",plid,plname))
				--return action
			end
		end
		return (string.format("Kicked %d players",kickplayers))
	else
		return nil, "You lack the permissions to kick!"
	end
end

--lets a subadmin ban players
function servercmd_ban(id, ...)
	local args = ...
	if not args[1] then return nil, "No ID/name(s) provided" end

	if tblPlayersSrv[id].permlevel>=tonumber(maincmd.k.perm) then
		local pllist
		local plname
		local namefilter = args[1]
		local plid = tonumber(namefilter)
		if plid~=nil then
			-- by id
		else
			-- by namefilter
			pllist = get_playerbyargs(id, namefilter)
			if tcount(pllist)<1 then
				return _f("Unable to find player matching %q",namefilter)
			end
			plid = tonumber(pllist[1].id) --pick up the id from pllist
		end
		table.remove(args,1)
		local comments = unpack2str(args," ")
		local kickplayers = 0
		if plid==nil or tblPlayersSrv[plid]==nil then
			serv_msg(string.format("Cannot ban [%d] - Invalid player ID",plid),id)
		elseif tblPlayersSrv[plid].permlevel>conf.kickbanlevel then
			plname = tblPlayersSrv[plid].name
			serv_msg(string.format("Cannot ban the player [%d] %q - protected",plid,plname),id)
		else
			plname = tblPlayersSrv[plid].name
			votekick("kick/ban", id, plid) -- stop a possible votekick against this player
			local bkreason = "Banned by "..tblPlayersSrv[id].name .. ": "..comments
			local bkevent = "admin"		
			BanKickManager(plid,bkevent,bkreason,id)
			kickplayers = kickplayers +1
			serv_msg(string.format("[%d] %q %s",plid,plname,bkreason))
			--return action
		end

		return (string.format("Banned %d players",kickplayers))
	else
		return nil, "You lack the permissions to ban!"
	end	
	
end

--lets a subadmin manage bans
function servercmd_banlist(id, ...)
	-- list bans / remove bans
	local args = ...
	
	function CheckBanned(...)
		if args[1] then
			--
		end
	end
	
	if args and tcount(args)>0 then
		-- list bans using name / id filter
		local bremove = false
		if args and args[1] == "r" then
			args[1] = nil
			bremove = true
		end
		if argtypechecker('number',args) or argtypechecker('string',args) then
			if bremove then
				-- remove ban by ID / name.
				BanManager(id,'remove',args)
				banSave()
			else
				BanManager(id,'listfilter',args)
			end
		else
			serv_msg(string.format("ERR: It wasn't clear if you tried to specify a number or a text filter - please try again"),id)
		end
	else
		-- just list
		BanManager(id,'list')
	end
end

-- interactive load commands
function servercmd_loadbans(id,...)
	banLoad()
end

function servercmd_save(id,...)
	local args = ...
	if type(args[1])=='string' then
		local tbl = args[1]
		local msg, err
		local file
		if string.lower(tbl)=='conf' then
			local custom_name = args[2]
			file = sm_custompath..'/CONF_'..custom_name..'.lua'
			msg, err = filemanager('save',file,server[tbl],tbl)
			if err then return nil, tostring(err) end
			if msg then return tostring(msg) end
		elseif string.lower(tbl)=='bans' then
			-- save Bans, or other testcode - internal test
			return banSave()
		elseif server[tbl] and type(server[tbl])=='table' then
			-- can be saved
			file = sm_custompath..'/'..tbl..'.lua'
			msg, err = filemanager('save',file,server[tbl],args[1])
			if err then return nil, tostring(err) end
			if msg then return tostring(msg) end			
		else
			return nil, "No such thing for save"
		end
	else
		return nil, "Thats just wrong. Wrong kind of input"
	end
end

function servercmd_set(id,...)
	-- the set server-command is quite powerful. Use with care.
	-- check the dynamicsettings-Table for which settings that can be changed.
	local args = ...
	local function checksetting(keyset)
		local strcmd, val
		local settbl = dynamicsettings[keyset[1]]
		local lookupval = tostring(keyset[2])
		if settbl then
			local possiblevalues = {}
			for val,strcmd in pairs(settbl) do
				if string.lower(lookupval) == val then 
					return strcmd
				end
				possiblevalues[val] = val
			end
			local help = unpack2str(possiblevalues,", ")
			return nil, string.format("No such value, possible values are: %s",help)
		else
			return nil, "No such setting"
		end
	end
	
	local k,v
	local k2,v2
	local msg
	if type(args)=='table' then
		for k,v in pairs(args) do
			if string.find(v,"=") then
				-- set values
				local newkey = split(v,"=",2) -- max number of supported parameters
				if newkey and type(newkey)=='table' and tcount(newkey)==2 then
					local strcmd, err = checksetting(newkey)
					if err then 
						msg = "Err: "..tostring(err)
						return msg
					end
					
					if strcmd then 
						local exenow,err = loadstring(strcmd)
						
						if not err then
							msg = "###SET: Compile Success: "..tostring(strcmd)
							log_write(msg)
						else
							msg = "###SET: Compile Error: "..tostring(err)
							log_write(msg)
							msg = "Syntax Error in command - command discarded. Nothing changed."
							return msg
						end
						local ok,err = pcall(exenow)
						if not err then
							--serv_msg("DEBUG Exe success: "..tostring(strcmd))
							msg = "###SET: Executed: "..tostring(strcmd)
							log_write(msg)
							return msg
						else
							msg = "###SET: Execution Err: "..tostring(err)
							log_write(msg)
							msg = "Syntax Error in command - command discarded. Nothing changed."
							return msg
						end
					end
				else
					msg = "Set command: Syntax error. Did you type correctly?"
					return msg
				end
			else
				-- no setting, list keys + values using args
				return "SET LIST KEY - Function not completed yet. Later."
			end
		end
	else
		-- no args, list keys + values
		return "SET LIST ALL KEYS - Function not completed yet. Later."
	end
end




------------------------------------------------------------------
-- Internal
------------------------------------------------------------------

--(re-)loads the server configuration
function load_config(custom_conf_file)

	--init counter
	counter = 0
	initerr = false

	--init server vars
	local err4
	local disabled = "" -- string that lists all disabled functionalities
	servman_initcompleted = true -- signal that we no longer require to load config.
	
	local function param_valid(parameter, paramtype, paramdefault)
		if conf[parameter] == nil or tostring(type(conf[parameter])) ~= paramtype then
			local paramtypeerr = tostring(type(conf[parameter]))
			log_write(string.format("SERVER::load_config, Parameter not correct: conf.%q, Expected type %q got type %q, Value %q",tostring(parameter), tostring(paramtype), paramtypeerr, tostring(conf[parameter])))
			-- don't cripple servman, use defaults
			conf[parameter] = paramdefault
			--disabled = disabled .. tostring(parameter).."; "
			--err4 = true
			return false
		else
			return true
		end
	end
	
	if not tblPlayersSrv then
		log_write("SERVER::load_config(): tblPlayersSrv nil, Panzer. Check this.") -- Do we have this situation at all?
		tblPlayersSrv = {}
	end

	log_write("SERVER::load_config():Server created in playertable.")
	tblPlayersSrv[1] = {
		name = net.get_name(1),
		addr = "127.0.0.1", --localhost
		is_subadmin = true,
		permlevel = permlevel.superadm,
		teamkills = 0,
		AI_teamkills = 0,
		friendly_fire = 0,
		collisions = 0,
		login_tries = 0,
		will_be_kicked = false,
		ping_warnings = 0,
		last_mizvote = 0,
		last_votekick = 0,
		last_collision = {}, 
		last_friendly_fire = {}, 
		ping = { count = 0, sum = 0 }	
	}

	if locked == nil then locked = false end
	kicked_players = kicked_players or {}
	last_MOTD = last_MOTD or os.time()
	last_MANN = last_MANN or os.time()

	banned_hosts = {}
	mp_missions = {}
	sm_configs = { 'SystemDefault' }
	mutex = false
	
	local function valid_table(tbl, str)
		if not tbl or type(tbl)~="table" then
		message = string.format("Invalid table: %q",str)
		log_write(message)
		serv_msg(message)
			tbl = {}
			disabled = disabled .. str.."; "
			err4 = true
			-- do we want to return empty table if the original table does have data? No.
			-- ensure that the original table survives
			if server[str]~=nil and tcount(server[str])>0 then return server[str] end
		end
		-- return the verified table
		return tbl
	end
	
	--get server configuration from serverconfig.lua file
	local ok = false
	--tmp holders, until the loaded table can be verified
	local cmdprf, tmp_permlevel, tmp_maincmd, tmp_mainhelp, tmp_dynamicsettings
	local tmp_conf, tmp_defaultconf, tmp_subadmins, tmp_banned_IP_ranges, tmp_banned_names, tmp_kick_phrase
	

	--load commands
	ok, cmdprf, tmp_permlevel, tmp_maincmd, tmp_mainhelp = get_conftable("commands.lua")
	ok, tmp_dynamicsettings = get_conftable("dynsettings.lua")
	
	--if customconf==true then
	ok, tmp_defaultconf, tmp_subadmins, tmp_banned_IP_ranges, tmp_banned_names, tmp_kick_phrase = get_conftable("serverconfig.lua")
	
	-- a new configuration may have been specified?
	if sm_currconfig~='' then
		custom_conf_file=sm_currconfig
	end
	
	if custom_conf_file and type(custom_conf_file)=='string' then
		local confname = 'CONF_'..sm_currconfig..'.lua'
		log_write("SERVER::load_config(), Server getting a CUSTOM config "..confname)
		ok, tmp_conf = get_conftable(confname)
		if ok then
			log_write("SERVER::load_config(), Server will use the CUSTOM config")
		else
			-- revert to default
			log_write("SERVER::load_config(), FAILED to load config - revert to DEFAULT")
			tmp_conf = tmp_defaultconf
			serv_msg('Server couldn\'t load config:' ..custom_conf_file)
			return false
		end
	else
		--- defaults only
		tmp_conf = tmp_defaultconf
	end

	--check file inputs for errors
	permlevel			= valid_table(tmp_permlevel			, "permlevel")
	maincmd				= valid_table(tmp_maincmd			, "maincmd")
	mainhelp			= valid_table(tmp_mainhelp			, "mainhelp")
	dynamicsettings		= valid_table(tmp_dynamicsettings	, "dynamicsettings")
	
	conf				= valid_table(tmp_conf				, "conf")
	subadmins			= valid_table(tmp_subadmins			, "subadmins")
	banned_IP_ranges	= valid_table(tmp_banned_IP_ranges	, "banned_IP_ranges")
	banned_names		= valid_table(tmp_banned_names		, "banned_names")
	
	kick_phrase			= valid_table(tmp_kick_phrase		, "kick_phrase")
	-- check all parameters for errors, set default if error
	param_valid("language", "string", "en")
	param_valid("missionvotes", "boolean", false)	

	param_valid("vote_timeout", "number", 60)
	param_valid("min_votes_in_percent", "number", 0)
	param_valid("time_between_votes", "number", 5)
	param_valid("restart_miz_after", "number", 0)
	param_valid("rotate_miz_after", "number", 0)
	param_valid("miz_rotate_announcement", "table", {0})
	param_valid("pause_if_server_empty", "boolean", false)
	param_valid("resume_if_server_not_empty", "boolean", false)
	param_valid("restart_if_server_empty", "boolean", false)
	param_valid("kick_after_teamkills", "number", 0)
	param_valid("kick_after_AI_teamkills", "number", 0)
	param_valid("kick_after_friendly_fire", "number", 0)
	param_valid("friendly_fire_interval", "number", 3)
	param_valid("collision_interval", "number", 3)
	param_valid("reset_TK_stats_on_miz", "boolean", false)
	param_valid("kick_below_score", "number", 0)
	param_valid("kick_after_max_ping_events", "number", false)
	param_valid("max_average_ping", "number", 500)
	param_valid("wait_after_kick", "number", 0)
	param_valid("autoban_after_kicks", "number", 0)
	param_valid("masterbanlist_URL", "string", "")
	param_valid("MOTD", "string", "")
	param_valid("MOTD_interval", "number", 5)
	param_valid("server_rules", "string", "")
	param_valid("timer_interval", "number", 10)
	param_valid("log_chat", "boolean", false)
	param_valid("loglevel", "number", 1)
	param_valid("reinit_by_admin", "boolean", false)

	-- squad login
	-- If all squad parameters are okai, enable login - otherwise disable
	if not param_valid("squad_prefix", "string", "") or
		not param_valid("squad_suffix", "string", "") or
		not param_valid("squad_username", "string", "") or
		not param_valid("squad_password", "string", "") or
		not param_valid("squad_login_enable", "boolean", false) then
		-- one ore more errors, disable squad login
			conf.squad_login_enable = false
	end
	param_valid("kickbanlevel", "number", 1)
	param_valid("bankick_byname", "boolean", false)
	param_valid("bankick_byip", "boolean", true)
	param_valid("bankick_byucid", "boolean", false)
	param_valid("bankick_vote", "boolean", false)
	param_valid("bankick_enabled", "boolean", true)
	
	-- global disable_events, WIP
	-- param_valid("servermessages", "boolean", true)
	-- if servermessages==false then global.disable_events = true end
	
	if err4 then
		initerrmsg = "### SERVMAN ERROR: Incorrect initialisation of variable(s) in serverconfig.lua file, "
				.. "the following function(s) have been disabled: " .. disabled
		log_write(initerrmsg)
		initerr = true
	else
		--enable chatlog
		if conf.log_chat then
			log_write("SERVER::load_config:enable-chat")
			-- If chatlog already defined for this session, keep it
			if not chatlogger then
				log_write("SERVER::load_config:enable-chat:create-logger")
				chatlogger, err = io.open(sm_chatlog, "w")
			end
			
			if not chatlogger then
				log_write("### SERVMAN ERROR: Could not create chatlog. Error: "..err)
			else
				log_write("Chatlog has been enabled")
			end
		end
	end

	--load localized messages from translations.lua
	if conf.language ~= "en" then
		local terr = false
		local tok = false
		--load and compile file
		local transl_file, terr = loadfile(sm_rootpath.."/translations.lua")
		if terr then 
			log_write("ERROR: Could not load/compile translations.lua file. "
					.. "Using default 'en'. Error: " .. terr)
			conf.language = "en"
			initerr = true
		else
			--run file in protected mode
			local all_translations
			tok, all_translations = pcall(transl_file)
			if not tok then
				log_write("ERROR: Could not execute translations.lua file. "
						.. "Using default 'en'. Error: " .. all_translations)
				conf.language = "en"
				initerr = true
			elseif type(all_translations) ~= "table" or all_translations[conf.language] == nil then
				log_write("ERROR: translations.lua file does not contain language '" 
						.. conf.language .. "'. Using default 'en'.")
				conf.language = "en"
				initerr = true
			else
				translations = all_translations[conf.language]
				log_write(_f("Localization file for language '%s' has been loaded successful", tostring(conf.language)))
			end
		end
	end
	
	if conf.missionfolder ~= nil then
		missionfolder = conf.missionfolder
	else
		missionfolder = './missions/multiplayer/'
	end
	

	--mission rotating has priority over restarting
	if conf.restart_miz_after > 0 and conf.rotate_miz_after > 0 then
		conf.restart_miz_after = 0
		log_write(_f("Mission Rotate takes priority over Mission Restart. restart_miz_after now set to 0"))
	end
	
	--delete leading/trailing spaces/line breaks and multiple inner line breaks from MOTD
	while string.sub(conf.MOTD, 1, 1) == "*" or string.sub(conf.MOTD, 1, 1) == " " do
		conf.MOTD = string.sub(conf.MOTD, 2, -1)
	end
	while string.sub(conf.MOTD, -1, -1) == "*" or string.sub(conf.MOTD, -1, -1) == " " do
		conf.MOTD = string.sub(conf.MOTD, 1, -2)
	end
	conf.MOTD = string.gsub(conf.MOTD, "%*+", "*")
	
	
	--delete leading/trailing spaces/line breaks and multiple inner line breaks from server rules
	while string.sub(conf.server_rules, 1, 1) == "*" 
			or string.sub(conf.server_rules, 1, 1) == " " do
		conf.server_rules = string.sub(conf.server_rules, 2, -1)
	end
	while string.sub(conf.server_rules, -1, -1) == "*" 
			or string.sub(conf.server_rules, -1, -1) == " " do
		conf.server_rules = string.sub(conf.server_rules, 1, -2)
	end
	conf.server_rules = string.gsub(conf.server_rules, "%*+", "*")
	
	--regex pattern for matching banned IPs
	local IP_pattern = "%d%d?%d?%.%d%d?%d?%.%d%d?%d?%.%d%d?%d?"
	local IP_count = 0

	local tmp_bantables
	ok, tmp_bantables = get_conftable(file_banlist)
	bantables			= valid_table(tmp_bantables			, "bantables")
	log_write(_f("Loaded %s records for the banlist", tostring(tcount(bantables))))

	--download masterbanlist from webserver, if enabled
	if conf.masterbanlist_URL ~= "" then
		-- sends a http request to the server and receives the response (see LuaSocket documentation)
		local str, code = http.request(conf.masterbanlist_URL)
		IP_count = 0
		local IP
		if str and code == 200 then
			for IP in string.gmatch(str, IP_pattern) do
				IP_count = IP_count + 1
				banned_hosts[IP] = true
			end
			log_write(_f("Loaded %s IPs from remote masterbanlist", tostring(IP_count)))
		else
			log_write(_f("ERROR: Could not download remote masterbanlist! Error: %q", tostring(code)))
		end
	end

	--load list of available MP missions in Missions/Multiplayer folder (see LuaFileSystem documentation)

	update_configlist()
	
	--load list of available MP missions in Missions/Multiplayer folder (see LuaFileSystem documentation)
	--for mission in lfs.dir("./Missions/Multiplayer/") do
	for mission in lfs.dir(missionfolder) do
		if string.sub(mission, -4) == ".miz" then
			mp_missions[#mp_missions + 1] = mission
			log_write(_f("SERVER:::load_config.addmission: [%s] %s", tostring(#mp_missions), tostring(mission)))
		end
	end
	
	--check if at least one mission is in missionlist
	if #mp_missions == 0 then
		--log_write(_("ERROR: No missions found in Missions/Multiplayer folder, "
		log_write(_(string.format("ERROR: No missions found in %q folder, ",missionfolder)
				.. "script will not run correctly!"))
		initerr = true
	else
		log_write(_f("Loaded %s missions into missionlist", tostring(#mp_missions)))
	end
	
	-- send all the settings to the log
	if conf.loglevel > 2 then
		for key, val in pairs(conf) do
			log_write(_f("SERVER:::load_config CONF %s=%s", tostring(key), tostring(val)))
		end
	end

	if conf.miz_rotate_announcement then 
		MANN_timers = conf.miz_rotate_announcement
	else
		MANN_timers = { 0 }
	end
	last_MANN_interval = #MANN_timers
	miz_annc_init()
	
	--log whether initialization ok/failed
	if initerr then
		-- set a few defaults to get the server running and warn the admins onscreen.
		counter = 0
		conf.timer_interval = 450 -- frequent reminder about the problem
		conf.log_chat = true
		log_write(_("INIT WARNING: Server configuration was not initialised correctly!"))
		return false
	else
		log_write(_("INIT OK: Server configuration has been initialised correctly"))
		return true
	end
end


function dumpplayer_info(id, ...)

	local args = ...
	local adm
	local msg
	if nil==tblPlayersSrv[id] then
		--	nothing returned
		msg = string.format("Problem - No data on User with ID(%s)",tostring(id))
		return serv_msg(msg)
	end
	if args and tcount(args)>0 and (tblPlayersSrv[id].is_subadmin or tblPlayersSrv[id].permlevel>=permlevel.squad) then
		-- allow lookup for others
		local pllist
	
		pllist = get_playerbyargs(id, args)
		--
		if pllist and #pllist>0 then
			for key,val in pairs(pllist) do
				plid = tonumber(val.id)
				plname = tblPlayersSrv[plid].name
				if tblPlayersSrv[plid].is_subadmin then
					adm = "admin access"
				elseif tblPlayersSrv[plid].permlevel>=tonumber(permlevel.squad) then
					adm = "squad access"
				else
					adm = "no special access"
				end
				msg = string.format("Player [%d] %q (%s), have %s.",plid, plname, tostring(tblPlayersSrv[plid].addr), adm)
				serv_msg(msg, id)
				if tblPlayersSrv[plid].login_tries>0 then
					msg = string.format("%q have tried and failed to login %d times",plname,tblPlayersSrv[plid].login_tries)
					serv_msg(msg, id)
				end
				msg = string.format("%q have %d ping warnings.",plname, tblPlayersSrv[plid].ping_warnings)
				serv_msg(msg, id)
			end
		else
			--	nothing returned
			msg = string.format("Problem - No data returned")
			serv_msg(msg, id)
		end
			
	else
		if tblPlayersSrv[id].is_subadmin then
			adm = "admin access"
		elseif tblPlayersSrv[id].permlevel>=tonumber(permlevel.squad) then
			adm = "squad access"
		else
			adm = "no special access"
		end
		msg = string.format("You [%d] %q (%s), have %s.",id, tostring(tblPlayersSrv[id].name), tostring(tblPlayersSrv[id].addr), adm)
		serv_msg(msg, id)
		if tblPlayersSrv[id].login_tries>0 then
			msg = string.format("You have tried and failed to login %d times",tblPlayersSrv[id].login_tries)
			serv_msg(msg, id)
		end
		msg = string.format("Your have %d ping warnings.",tblPlayersSrv[id].ping_warnings)
		serv_msg(msg, id)
	end
end

--checks and triggers scheduled events if timer expired
function check_timeouts()
	local miz_runtime = net.get_model_time()
	--check if mission should be rotated, rotating has priority over restarting if both are enabled
	if initerr then serv_msg("INIT error : "..tostring(initerrmsg)) end
	if compileerr then serv_msg("COMPILE error : "..tostring(compileerrmsg)) end

	local miz_remain
	miz_remain = miz_remaining()
	mission_announce(miz_remain)
	
	-- Miz_rotate will win over Miz_restart
	if conf.rotate_miz_after > 0 and miz_runtime > conf.rotate_miz_after * 60 then
		return rotate_miz()
	--check if mission should be restarted
	elseif conf.restart_miz_after > 0 and miz_runtime > conf.restart_miz_after * 60 then
		return restart_miz()
	end
	
	local curr_time = os.time()
	
	--check message of the day interval
	if paused_on_miz()==false and conf.MOTD_interval > 0 then
		--log_write(_f("SERVER:MOTDcheck: MOTD_playerconnect=%s, curr_time=%s, last_MOTD=%s, diff=%s",tostring(MOTD_playerconnect),tostring(curr_time),tostring(last_MOTD),tostring(os.difftime(curr_time, last_MOTD))))
		if MOTD_playerconnect==true and os.difftime(curr_time, last_MOTD) > 120 then
			-- Player connect, show MOTD after 2 mins
			MOTD_playerconnect=false
			show_MOTD()			
		elseif os.difftime(curr_time, last_MOTD) > conf.MOTD_interval * 60 then
			-- regular scheduled MOTD
			show_MOTD()
		end
	end

	--check if active vote/poll should be closed
	votekick("check")
	missionpoll("check")
	missionvote("check")
end

function resume_or_pause()
	-- on startup
	miz_annc_init()
	if conf.resume_if_server_not_empty and tcount(tblPlayersSrv) > 1 then
		log_write(_f("SERVER:resume_or_pause():RESUME"))
		net.resume()
		return
	elseif conf.resume_if_server_not_empty and tcount(tblPlayersSrv) < 2 then
		log_write(_f("SERVER:resume_or_pause():PAUSE"))
		net.pause()
	end
end

paused_on_miz = function(pause)
	if pause then
		net.pause()
		log_write(_f("SERVER:paused_on_miz():PAUSE"))
		return true
	end
	if pause==false then
		net.resume()
		log_write(_f("SERVER:paused_on_miz():RESUME"))
		return false
	end
	if pause==nil then
		if net.is_paused() then
			return true
		else
			return false
		end
	end
end

function mission_announce(miz_remain)
	local curr_timer
	if nil == miz_remain then return end
	if last_MANN_interval~=nil and last_MANN_interval>0 then
		curr_timer = MANN_timers[last_MANN_interval] * 60
		if not (curr_timer==0) and miz_remain<=curr_timer then
			if MOTD_playerconnect==false then
				-- if there's a playerconnect in progress, no need to run the announcement - MOTD will do it for us.
				serv_msg(show_timeleft(curr_timer))
			end
			log_write(show_timeleft(curr_timer))
			last_MANN_interval = last_MANN_interval-1
		end
	end
end

function miz_annc_init(miz_remain)
	if MANN_timers==nil then return end
	last_MANN_interval = #MANN_timers
	if last_MANN_interval==0 then return end
	local curr_timer
	local function next_timer()
		local curr_timer = MANN_timers[last_MANN_interval] * 60
		if miz_remain <= curr_timer then 
			last_MANN_interval = last_MANN_interval-1
			next_timer()
		end
	end
	
	if miz_remain==nil then
		miz_remain=miz_remaining()
		if nil == miz_remain then return end
	end
	curr_timer = MANN_timers[last_MANN_interval] * 60
	if miz_remain <= curr_timer then 
		last_MANN_interval = last_MANN_interval-1
		next_timer()
	end
end

function miz_remaining()
	-- Miz_rotate will win over Miz_restart
	local miz_remain
	if conf.rotate_miz_after > 0 then
		miz_remain = (conf.rotate_miz_after * 60) - math.floor(net.get_model_time())
	elseif conf.restart_miz_after > 0 then
		miz_remain = (conf.restart_miz_after * 60) - math.floor(net.get_model_time())
	else
		-- timers not in use
		return
	end
	return miz_remain
end

function config_list()
	serv_msg(_("CONFIGLIST: Config ID - Configname"), id)
	local currentconfId = get_currentconfigid(sm_currconfig)
	list_highlight_number(id,sm_configs,currentconfId)
end

function config_load(conf_numb)
	update_configlist()
	if conf_numb==1 then
		sm_prevconfig = sm_currconfig
		sm_currconfig=''
		load_config()
		return (_f("Server-configuration Loaded: %s",'SystemDefault'))
	elseif not conf_numb or conf_numb>#sm_configs then
		return nil, "No such configuration to load."
	end
	sm_prevconfig=sm_currconfig
	sm_currconfig=sm_configs[conf_numb]
	if load_config(sm_currconfig) then
		return (_f("Server-configuration Loaded: %s",string.upper(sm_currconfig)))
	else
		sm_currconfig = sm_prevconfig
		return nil,(_("An error occured while loading the Server-configuration"))
	end
end

function config_save(conf_name)
	local tbl = 'conf' -- servman global config in memory
	local file = sm_custompath..'/CONF_'..conf_name..'.lua'
	local msg, err = filemanager('save',file,server[tbl],tbl)
	if err then return nil, tostring(err) end
	update_configlist()
	sm_prevconfig=sm_currconfig
	sm_currconfig=conf_name
	if msg then return tostring(msg) end
end


--checks if IP is within a banned IP range. addr is a string representation of the address
function in_banned_IP_range(addr)
	--init
	local capture = "(%d%d?%d?)%.(%d%d?%d?)%.(%d%d?%d?)%.(%d%d?%d?)"
	local IP = {}
	local from = {}
	local to = {}
	local is_banned = false
	
	--interpret IP fields as 4-digit number to base 256
	IP[1], IP[2], IP[3], IP[4] = string.match(addr, capture)
	for i = 1, 4 do IP[i] = tonumber(IP[i]) end
	IP[0] = IP[1]*256^3 + IP[2]*256^2 + IP[3]*256 + IP[4]
	
	--check if IP is within a banned range
	for dummy, range in pairs(banned_IP_ranges) do
		from[1], from[2], from[3], from[4] = string.match(range.from, capture)
		to[1], to[2], to[3], to[4] = string.match(range.to, capture)
		for i = 1, 4 do
			from[i] = tonumber(from[i])
			to[i] = tonumber(to[i])
		end
		from[0] = from[1]*256^3 + from[2]*256^2 + from[3]*256 + from[4]
		to[0] = to[1]*256^3 + to[2]*256^2 + to[3]*256 + to[4]
		if from[0] <= IP[0] and IP[0] <= to[0] then
			is_banned = true 
			break
		end
	end
	
	return is_banned
end

--displays message of the day and/or remaining mission time
function show_MOTD()
	if conf.MOTD ~= "" then
		last_MOTD = os.time()
		local line_break = string.find(conf.MOTD, "*")
		local last_break = 0
		--serv_msg(_("***** MESSAGE OF THE DAY *****"))
		if conf.rotate_miz_after > 0 or conf.restart_miz_after > 0 then
			servercmd_timeleft()
		end
		if line_break ~= nil then
			repeat
				serv_msg(string.sub(conf.MOTD, last_break + 1, line_break - 1))
				last_break = line_break
				line_break = string.find(conf.MOTD, "*", last_break + 1)
			until line_break == nil
		end
		serv_msg(string.sub(conf.MOTD, last_break + 1, -1))
	else
		if conf.rotate_miz_after > 0 or conf.restart_miz_after > 0 then
			servercmd_timeleft()
		end
	end
end

function banAdd(bid,bevent,breason,admid)
	if not conf.bankick_enabled then return end
	local addr = tostring(tblPlayersSrv[bid].addr)
	local name = trim(tostring(tblPlayersSrv[bid].name))
	local ucid = tostring(tblPlayersSrv[bid].ucid)
	
	if breason and breason~="" then
		breason = string.format("%s Date: %s", breason,tostring(os.date("%c")))
	else
		if admid then
			breason = string.format("Event:%s By:%s Date: %s", tostring(bevent),tostring(tblPlayersSrv[admid].name),tostring(os.date("%c")))
		else
			breason = string.format("Event:%s Date: %s", tostring(bevent),tostring(os.date("%c")))
		end
	end
	
	local newban = { names = name, ucid=ucid, ipaddrs=addr,comment=breason,active = true }
	table.insert(bantables,newban)
	-- update file
	local msg,err = banSave()
	if err then
		serv_msg(tostring(err))
	end
end

function banRemove()

end

function banSave()
	local file = sm_custompath..'\\'..file_banlist
	local msg, err = filemanager('save',file,bantables,"bantables")
	if err then
		msg = _f("SERVER:banSave() Error: %s",tostring(err))
		log_write(msg)
		return nil,msg
	end
	if msg then 
		log_write(_f("SERVER::banSave() %s",tostring(msg)))
		return msg
	end	
end

function banLoad()
	local file = sm_custompath..'\\'..file_banlist
	local tblref = bantables
	local tblstr = "bantables"
	local tblresult, err = filemanager('load',file)
	if err then
		serv_msg(tostring(err))
		tblref["loadfail"] = true
	end
	if tblresult then
		serv_msg(_f("Loaded %q",tblstr))
		server[tblstr] = tblresult
	end
end

function BanExist(id,name,addr,ucid)
	if conf.bankick_enabled==false then return end
	if name then name=trim(tostring(name)) else return nil,"BanExist: problem with name" end
	if addr then addr=trim(tostring(addr)) else return nil,"BanExist: problem with addr" end
	if ucid then ucid=trim(tostring(ucid)) else return nil,"BanExist: problem with ucid" end
	if conf.bankick_byucid and BanManager(id,'getid',{'ucid',ucid}) then
		return "Banned account"
	end
	if conf.bankick_byip and BanManager(id,'getid',{'addr',addr}) then
		return "Banned IP"
	end
	if conf.bankick_byname and BanManager(id,'getid',{'name',name}) then
		return "Banned name"
	end
	return
end

--loads the next mission (missions in /Missions/Multiplayer are being rotated in lexical order)
function rotate_miz()
	log_write("SERVER::rotate_miz()")
	if not current_mission and #mp_missions>0 then
		-- servma	n was rehashed, using first available mission
		current_mission = mp_missions[1]
	end
	if #mp_missions > 0 then
		--init
		log_write(_f("SERVER:::rotate_miz.missioncount %d",#mp_missions))
		log_write(_f("SERVER:::rotate_miz.current_mission %q",current_mission))
		local next_miz
		local currID = get_currentmissionid(current_mission)
		local curr = get_filename(current_mission)
		log_write(_f("SERVER::rotate_miz.currentmissionID %d",currID))

		--determine next mission
		if mp_missions[currID + 1] then
			next_miz = mp_missions[currID + 1]
		else
			next_miz = mp_missions[1]
		end

		--load next mission
		log_write(_f("Automatic mission rotation: loading mission %q", next_miz))
		--return net.load_mission("./Missions/Multiplayer/" .. next_miz)
		return net.load_mission(missionfolder .. next_miz)
	else
		log_write(_f("Just one mission available - restarting mission"))
		return restart_miz()
	end
end

--restarts the current mission
function restart_miz()
	log_write(string.format("SERVER::restart_miz():Loading mission: %s",tostring(current_mission)))
	log_write(_("Automatic restart of current mission"))
	if not current_mission and #mp_missions>0 then
		-- servman was rehashed, using first available mission
		current_mission = mp_missions[1]
		log_write(_("SERVER::ServMan had no current mission, automaticly selected: " .. current_mission))
	end
	return net.load_mission(current_mission)
end

-- writes a chat message str sent by the player id to the chatlog
function chatlog_write(id, str)
	local msgfm = ""
	if id==nil or id==0 then
		-- PM format
		msgfm = _f("%s : %s\r\n", os.date("%c"), str)
	else
		-- Normal Chatlog format
		msgfm = _f("%s : [%d] %q : %s\r\n", os.date("%c"), id, net.get_name(id),  str)
	end
	if conf.log_chat then
		-- we're in a transition when server-code is recompiled, need to ensure the chat log is available before writing to it.
		chatlogger:write(msgfm)
		chatlogger:flush()
	end
end


--sends a server message. If recipient_id is nil then it is send to all player, otherwise only to the player
--whose id is recipient_id
function serv_msg(msg, recipient_id)
	local message = "#" .. msg
	--server.chatlog_write(1, string.format(msg))
	if recipient_id then
		if recipient_id == 1 then --send to server only
			net.recv_chat(message)
			server.chatlog_write(1, string.format(message))
		elseif recipient_id > 1 then --send to specified player only
			net.send_chat(message, recipient_id)
			message = string.format("PM to [%d] %q : %s", recipient_id, net.get_name(recipient_id), message)
			server.chatlog_write(0, message)
		end
	else --send to all
		net.send_chat(message, true)
		net.recv_chat(message)
	end
end


-- lookup Mission ID from filename
function get_currentmissionid(missionfilename)
	local currmissfile = get_filename(missionfilename)
	local currID = 0
	log_write(_f("SERVER:::get_currentmissionid.currmissfile %q",currmissfile))
	--determine current missionID
	local i,miz
	for i, miz in ipairs(mp_missions) do
		if currmissfile == miz then
			currID = i
			break
		end
	end
	log_write(_f("SERVER:::get_currentmissionid.currID %d",currID))
	return currID
end

-- lookupConfig ID from filename
function get_configidfromname(conf_name)
	local currID = 0
	log_write(string.format("SERVER::get_configidfromname.conf_fname %q",tostring(conf_name)))
	--determine current missionID
	local i,thisconf
	for i, thisconf in ipairs(sm_configs) do
		if conf_name == thisconf then
			currID = i
			break
		end
	end
	
	if currID==0 then
	-- lets try the filter
		local cId,cName
		-- by namefilter
		cId,cName = get_IdByFilter(sm_configs,conf_name)
		--serv_msg(string.format("DEBUG: cId=%s cName=%s",tostring(cId),tostring(cName)))
		currID = cId
	end
	log_write(string.format("SERVER::get_configidfromname.currID %s",tostring(currID)))
	if currID==nil then
		currID=1
		log_write(string.format("SERVER:get_configidfromname() - Warning, could not find the confignumber %s. Reverting to SystemDefault. ",tostring(currID)))
		update_configlist()
		sm_prevconfig=sm_currconfig
		sm_currconfig=''
	end
	return currID
end

function get_IdByFilter(tbl,filter)
	local function lookup(tbl,filter)
		local lofilt = string.lower(filter)
		for k, val in pairs(tbl) do
			local loval = string.lower(val)
			if loval:find(lofilt) then
				return k,val
			end
		end
	end
	return lookup(tbl,filter)
end

-- lookupConfig ID from filename
function get_currentconfigid(conf_file)
	local conf_fname = get_filename(conf_file)
	local conf_name = convert_ConfFile_ToName(conf_fname)
	log_write(_f("SERVER::get_currentconfigid.conf_fname %q",conf_fname))
	log_write(_f("SERVER::get_currentconfigid.conf_name %q",conf_name))
	local currID = 1
	currID = get_configidfromname(conf_name) or 1
	log_write(_f("SERVER::get_currentconfigid.currID %d",currID))
	if currID==nil then
		currID=1
		log_write(string.format("SERVER:get_currentconfigid() - Warning, could not find the confignumber %s. Reverting to SystemDefault. ",tostring(currID)))
		update_configlist()
		sm_prevconfig=sm_currconfig
		sm_currconfig=''		
	end
	return currID
end


function convert_ConfFile_ToName(conf_file)
	if string.lower(string.sub(conf_file, -4))== ".lua" and string.lower(string.sub(conf_file,1,4)) == "conf" then
		conf_file = string.sub(conf_file,6)
		conf_file = string.sub(conf_file,1,-5)
	end
	return conf_file
end

function update_configlist()
	local sm_conf
	sm_configs = { 'SystemDefault' }
	for sm_conf in lfs.dir(sm_custompath) do
		if string.lower(string.sub(sm_conf, -4))== ".lua" and string.lower(string.sub(sm_conf,1,4)) == "conf" then
			sm_configs[#sm_configs + 1] = convert_ConfFile_ToName(sm_conf)
			log_write(_f("SERVER::load_config.addconfig: [%s] %s", tostring(#sm_configs), tostring(sm_conf)))
		end
	end	
end

function list_highlight_number(playerid,list,highliteId)
	local index = 1
	local len, msg, leftEntry, midEntry
	local idformat = "%2d"
	local widthmultipl = 1.7 -- defines the "general width factor" of "any" character vs whitespaces within the current fontset.
	
	for id, entry in pairs(list) do
		--entry in left column
		if id == highliteId then idformat = "->%2d<- " else idformat = "  %2d - " end
		if index == 1 then
			len = string.len(entry)
			if len > 33 then 
				leftEntry = string.format(idformat.."%-33s", id, string.sub(entry, 1 , 33))
			else
				leftEntry = string.format(idformat.."%-33s", id, entry)
			end
			index = 2
			-- padding the width for easier readability before index2
			len = string.len(leftEntry)
			--leftEntry = leftEntry .. string.rep(" ",80-(len))
			--leftEntry = leftEntry .. string.rep(" ",80-(len*widthmultipl))
		--entry in right column
		elseif index == 2 then
			len = string.len(entry)
			if len > 33 then 
				leftEntry = leftEntry..string.format(idformat.."%-33s", id, string.sub(entry, 1 , 33))
			else
				leftEntry = leftEntry..string.format(idformat.."%-33s", id, entry)
			end
			--msg = string.format("%s | "..idformat.."%-33s", leftEntry, id, entry)
			--serv_msg(msg, playerid)
			index = 3	
		elseif index == 3 then
			len = string.len(entry)
			if len > 33 then 
				leftEntry = leftEntry..string.format(idformat.."%-33s", id, string.sub(entry, 1 , 33))
			else
				leftEntry = leftEntry..string.format(idformat.."%-33s", id, entry)
			end
			--msg = string.format("%s | "..idformat.."%-33s", leftEntry, id, entry)
			--serv_msg(msg, playerid)
			index = 4	
		else
			len = string.len(entry)
			if len > 33 then 
				leftEntry = leftEntry..string.format(idformat.."%-33s", id, string.sub(entry, 1 , 33))
			else
				leftEntry = leftEntry..string.format(idformat.."%-33s", id, entry)
			end
			--msg = string.format("%s | "..idformat.."%-33s", leftEntry, id, entry)
			--serv_msg(msg, playerid)
			serv_msg(leftEntry, playerid)
			index = 1	
		end
	end
	if index == 2 or index == 3 or index == 4 then --last entry not yet printed
		serv_msg(leftEntry, playerid)
	end
end

-- Helper, get_playernamebyid
function get_playernamebyid(...)
	local args = ...
	local plname_list = nil
	
	local function pllookup(val)
		for plk, plval in pairs(tblPlayersSrv) do
			if tonumber(val) and plk == tonumber(val) then
				table.insert(plname_list,{ name = plval.name, id = val })
			end
		end
	end
	
	if args and tcount(args)>0 then
		plname_list = {}
		if type(args)=="number" then
			pllookup(args)
		elseif type(args)=="table" then
			for argk, argv in pairs(args) do
				pllookup(argv)
			end		
		end
	end
	return plname_list
end

-- Helper, get_playeridsbyname
function get_playeridsbyname(...)

	local args = ...
	local plname_list = nil
	
	local function pllookup(val)
		local loval = string.lower(val)
		for plk, plval in pairs(tblPlayersSrv) do
			local loname = string.lower(plval.name)
			if loname:find(loval) then
				table.insert(plname_list,{ name = loname, id = plk })
			end
		end
	end

	if args and tcount(args)>0 then
		plname_list = {}
		if type(args)=="string" then
			pllookup(args)
		elseif type(args)=="table" then
			for argk, argv in pairs(args) do
				pllookup(argv)
			end		
		end
	end
	return plname_list
end

function get_playerbyargs(id,...)

	local args = ...
	local argc = tcount(args)
	if args and argc>0 then

		local argtype
		if argtypechecker('number',args) then
			-- number
			argtype = 'number'
		elseif argtypechecker('string',args) then
			argtype = 'string'
		else
			argtype = nil
		end
		local pllist
		if argtype and argtype=='number' then
			pllist = get_playernamebyid(args)
			return pllist			
		elseif argtype and argtype=='string' then
			pllist = get_playeridsbyname(args)
			return pllist
		else
			return nil, "Cannot get data by using a mixed list of names and numbers"
		end
	else
		return nil
	end

end

-- helper to ensure the thread is dead and buried. 
-- Had some problems earlier with the threads not being released.
function helper_CoroutineEnd(corout, coevent)
	local co_status
	if type(corout) == "thread" then
		co_status = coroutine.status(corout)
	else
		co_status = "dead"
	end
	if co_status == "suspended" then
		assert(coroutine.resume(corout, coevent))
	end
	if type(corout) == "thread" then
		co_status = coroutine.status(corout)
	else
		co_status = "dead"
	end	
	if co_status ~= "dead" then
		serv_msg(_("COROUTINE: Servman-problem: voting thread wont die."), id)
	else
		--serv_msg(_("DEBUG: Voting thread should be dead by now."), id)
		corout = nil
	end
	return corout
end


-- starts votekicks and handles related events
function votekick(event, id, msg)
	--coroutine that keeps track of the votekick's state
	local function votekick_coroutine(starterID, playerID)
		--init
		local starttime = os.time()
		local votes = {}
		local stop = false
		local stop_reason
		local vote_event, id, msg
		local player_name = tblPlayersSrv[playerID].name
		local player_addr = tblPlayersSrv[playerID].addr
		local starter_name = tblPlayersSrv[starterID].name
		
		--send start message
		serv_msg(_f("%q started a VOTEKICK against %q. Shall the player be kicked?", 
				tblPlayersSrv[starterID].name, player_name))
		serv_msg(_("Please use /yes or /no to vote (just enter it into chat)!"))
		log_write(_f("Player id = [%d], addr = %s, name = %q started a votekick against player %q",
				starterID, tblPlayersSrv[starterID].addr, starter_name, player_name))
		votes[starterID] = "yes"
		if starter_name==player_name then
			serv_msg(_f("%q aims for his nuts and spins the barrel! Russian roulette!", player_name))
		else
			serv_msg(_f("%q voted yes for kicking %q", starter_name, player_name))
		end
		
		--wait for vote events
		while not stop do
			vote_event, id, msg = coroutine.yield(-1)
			--check if vote time is over
			if vote_event == "check" then
				if os.difftime(os.time(), starttime) > conf.vote_timeout then
					stop_reason = "close"
					stop = true
				end
			--process vote
			elseif vote_event == "vote" then
				if not votes[id] then
					if msg == cmdprf.."yes" then
						votes[id] = "yes"
						if tblPlayersSrv[id].name==player_name then
							serv_msg(_f("%q wants out!? Votes yes for himself. Nutcase!", tblPlayersSrv[id].name, player_name))
						else
							serv_msg(_f("%q voted yes for kicking %q", tblPlayersSrv[id].name, player_name))
						end
					elseif msg == cmdprf.."no" then
						votes[id] = "no"
						serv_msg(_f("%q voted no for kicking %q", tblPlayersSrv[id].name, player_name))
					else
						serv_msg(_f("%q didn't vote correctly", tblPlayersSrv[id].name))
					end
				else
					serv_msg(_("Already voted!"), id)
				end
			--delete or stop vote if player left server (this also stops the vote if all players left)
			elseif vote_event == "delete" then
				votes[id] = nil
				--stop vote if player to be kicked left
				--leaving while a votekick against oneself is in progress counts as a successful votekick
				if id == playerID then
					local bkevent = "left_before_votekick"
					BanKickManager(playerID, bkevent)
					stop_reason = "left"
					stop = true
				end
			--stop votekick if player is meanwhile being kicked/banned by admin
			elseif vote_event == "kick/ban" then
				if msg == playerID then
					stop_reason = "kick/ban"
					stop = true
				end
			--stop votekick by admin
			elseif vote_event == "stop" then
				stop_reason = "stop"
				stop = true
			end
		end
		
		--stop or evaluate vote
		local result, message
		if stop_reason == "left" then
			result = 0
			message = _f("Votekick against %q has been stopped! Player left server. "
					.. "This counts as a kick!", player_name)
		elseif stop_reason == "kick/ban" then
			result = 0
			message = _f("Votekick against %q has been stopped! Player has been "
					.. "kicked/banned by admin", player_name)
		elseif stop_reason == "stop" then
			result = 0
			message = _f("Votekick against %q has been stopped by admin!", player_name)
		else
			--count votes
			local yes = 0
			local no = 0
			for dummy, vote in pairs(votes) do
				if vote == "yes" then yes = yes + 1
				elseif vote == "no" then no = no + 1
				end
			end
			
			--check if enough votes
			local player_count = 0
			local vote_percentage = 0
			for i, j in pairs(tblPlayersSrv) do
				player_count = player_count + 1
			end
			if player_count > 0 then
				vote_percentage = ((yes + no) / player_count) * 100 
			end
			if vote_percentage >= conf.min_votes_in_percent then
				--enough votes, evaluate votekick
				if yes > no then
					result = 1
					message = _f("Votekick against %q successful! Player will be kicked. "
							.. "Result: yes=%d vs. %d=no", player_name, yes, no)
				else
					result = 0
					message = _f("Votekick against %q failed! Player can stay. "
							.. "Result: yes=%d vs. %d=no", player_name, yes, no)
				end
			else
				--not enough votes
				result = 0
				message = _f("Votekick against %q failed! Not enough votes "
						.. "(%d, needed %d)! Player can stay.", player_name, 
						yes + no, math.ceil(player_count * (conf.min_votes_in_percent / 100)))
			end
		end
		
		--log result
		serv_msg(message)
		log_write(message)
		
		return result, playerID
	end --missionvote_coroutine
	
	--dispatch events to coroutine
	--init
	local dummy, playerID, result, co_status
	local start_time = os.time()
	if type(co_votekick) == "thread" then
		co_status = coroutine.status(co_votekick)
	else
		co_status = "dead"
	end

	--check if time for votekick is over and kick player if successful
	if event == "check" then
		if co_status == "suspended" then
			dummy, result, playerID = assert(coroutine.resume(co_votekick, "check"))
			if result == 1 then
				co_votekick = nil
				--return kick_ban(playerID, "Successful votekick")
				local bkevent = "votekick"
				local bkreason = "Successful votekick"
				return BanKickManager(playerID, bkevent,bkreason)
			elseif result == 0 then
				co_votekick = nil
			end
		end
	--start new votekick
	elseif event == "start" then
		if not conf.bankick_vote or not conf.bankick_enabled then
			serv_msg(_("Votekicks are not enabled!"), id)
		elseif co_status ~= "dead" then
			serv_msg(_("Another votekick already in progress..."), id)
		elseif tblPlayersSrv[id].permlevel<permlevel.admin and (tblPlayersSrv[id].last_votekick ~= 0) 
				and (os.difftime(start_time - tblPlayersSrv[id].last_votekick) 
				<= (conf.time_between_votes * 60)) then
			serv_msg(_f("Wait %d seconds before starting another vote!", math.floor(
					conf.time_between_votes * 60 - (start_time - tblPlayersSrv[id].last_votekick))), id)
		else
			--extract player ID from msg, check if valid and start vote
			playerID = tonumber(msg)
			if playerID == nil or not tblPlayersSrv[playerID] then
				serv_msg(_("Invalid player ID"), id)
			elseif tblPlayersSrv[playerID].permlevel>conf.kickbanlevel then
				serv_msg(_("Not enough permission to kick this player"), id)
			else
				tblPlayersSrv[id].last_votekick = start_time
				co_votekick = coroutine.create(votekick_coroutine)
				assert(coroutine.resume(co_votekick, id, playerID))
			end
		end
	--process vote for votekick
	-- co_votekick co_votekicks
	elseif event == "vote" then
		if co_status == "suspended" then
			assert(coroutine.resume(co_votekick, "vote", id, msg))
		else
			serv_msg(_("No active votekick"), id)
		end
	--delete vote if player left server
	elseif event == "delete" then
		if co_status == "suspended" then
			assert(coroutine.resume(co_votekick, "delete", id))
		end
	--stop vote if player has been kicked/banned
	elseif event == "kick/ban" then
		if co_status == "suspended" then
			assert(coroutine.resume(co_votekick, "kick/ban", id, msg))
		end
	--stop vote by admin
	elseif event == "stop" then
		if co_status == "suspended" then
			co_votekick = helper_CoroutineEnd(co_votekick, "stop")
		end
	end
end


--starts missionvotes and handles related events
function missionvote(event, id, msg)
	--coroutine that keeps track of the missionvote's state 
	local function missionvote_coroutine(starterID, mizname)
		--init
		local starttime = os.time()
		local votes = {}
		local stop = false
		local stop_reason
		local vote_event, id, msg
		local starter_name = tblPlayersSrv[starterID].name
		
		--send start message
		serv_msg(_f("%q started a MISSIONVOTE for %q. Shall this mission be loaded?",
				tblPlayersSrv[starterID].name, mizname))
		serv_msg(_("Please use /yes or /no to vote (just enter it into chat)!"))
		log_write(_f("Player id = [%d], addr = %s, name = %q started a missionvote for %q",
				starterID, tblPlayersSrv[starterID].addr, starter_name, mizname))
		votes[starterID] = "yes"
		serv_msg(_f("%q voted yes for loading new mission", starter_name))
		
		--wait for vote events
		while not stop do
			vote_event, id, msg = coroutine.yield(-1)
			--check if vote time is over
			if vote_event == "check" then
				if os.difftime(os.time(), starttime) > conf.vote_timeout then
					stop = true
					stop_reason = "close"
				end
			--process vote
			elseif vote_event == "vote" then
				if not votes[id] then
					if msg == cmdprf.."yes" then
						votes[id] = "yes"
						serv_msg(_f("%q voted yes for loading new mission", tblPlayersSrv[id].name))
					elseif msg == cmdprf.."no" then
						votes[id] = "no"
						serv_msg(_f("%q voted no for loading new mission", tblPlayersSrv[id].name))
					else
						serv_msg(_f("%q didnt vote correctly", tblPlayersSrv[id].name))
					end
				else
					serv_msg(_("Already voted!"), id)
				end
			--delete vote if player left and stop vote if server empty
			elseif vote_event == "delete" then
				votes[id] = nil
				if table.maxn(tblPlayersSrv) == 1 then
					stop_reason = "empty"
					stop = true
				end
			--stop vote by admin
			elseif vote_event == "stop" then
				stop_reason = "stop"
				stop = true
			end
		end
		
		--stop vote if server empty, otherwise evaluate votes
		local result, message
		if stop_reason == "empty" then
			result = 0
			message = _f("Missionvote for %q has been stopped! All players left server", mizname)
		elseif stop_reason == "stop" then
			result = 0
			message = _f("Missionvote for %q has been stopped by admin!", mizname)
		else
			--count votes
			local yes = 0
			local no = 0
			for dummy, vote in pairs(votes) do
				if vote == "yes" then yes = yes + 1
				elseif vote == "no" then no = no + 1
				end
			end
			
			--check if enough votes
			local player_count = 0
			local vote_percentage = 0
			for i, j in pairs(tblPlayersSrv) do
				player_count = player_count + 1
			end
			if player_count > 0 then
				vote_percentage = ((yes + no) / player_count) * 100 
			end
			if vote_percentage >= conf.min_votes_in_percent then
				--evaluate missionvote
				if yes > no then
					result = 1
					message = _f("Missionvote for %q successful! Result yes=%d vs. %d=no", 
							mizname, yes, no)
				else
					result = 0
					message = _f("Missionvote for %q failed! Result yes=%d vs. %d=no", 
							mizname, yes, no)
				end
			else
				--not enough votes
				result = 0
				message = _f("Missionvote for %q failed! Not enough votes (%d, needed %d)! "
						.. "Current mission continues.", mizname, yes + no, 
						math.ceil(player_count * (conf.min_votes_in_percent / 100)))
			end
		end
		
		--log result
		serv_msg(message)
		log_write(message)
		
		return result, mizname
	end --missionvote_coroutine
	
	--dispatch events to coroutine
	--init
	local dummy, missionID, mission_name, result, co_status
	local start_time = os.time()
	if type(co_missionvote) == "thread" then
		co_status = coroutine.status(co_missionvote)
	else
		co_status = "dead"
	end

	--check if time for missionvote is over and load mission if successful
	if event == "check" then
		if co_status == "suspended" then
			dummy, result, mission_name = assert(coroutine.resume(co_missionvote, "check"))
			if result == 1 then
				co_missionvote = nil
				--return net.load_mission("./Missions/Multiplayer/" .. mission_name)
				return net.load_mission(missionfolder .. mission_name)
			elseif result == 0 then
				co_missionvote = nil
			end
		end
	--start new missionvote
	elseif event == "start" then
		if not conf.missionvotes then
			serv_msg(_("Missionvotes are not enabled!"), id)
		elseif co_status ~= "dead" or (type(co_missionpoll) == "thread" 
				and coroutine.status(co_missionpoll) ~= "dead") then
			serv_msg(_("Another missionvote/-poll already in progress..."), id)
		elseif tblPlayersSrv[id].permlevel<permlevel.admin and (tblPlayersSrv[id].last_mizvote ~= 0) 
				and (os.difftime(start_time - tblPlayersSrv[id].last_mizvote) 
				<= (conf.time_between_votes * 60)) then
			serv_msg(_f("Wait %d seconds before starting another vote!", math.floor(
					conf.time_between_votes * 60 - (start_time - tblPlayersSrv[id].last_mizvote))), id)
		else
			--extract mission ID from msg, check if valid and start vote
			missionID = tonumber(msg)
			if missionID == nil or not mp_missions[missionID] then
				serv_msg(_("Invalid mission ID: %s",tostring(msg)), id)
			else
				tblPlayersSrv[id].last_mizvote = start_time
				co_missionvote = coroutine.create(missionvote_coroutine)
				assert(coroutine.resume(co_missionvote, id, mp_missions[missionID]))
			end
		end
	--process vote for missionvote
	elseif event == "vote" then
		if co_status == "suspended" then
			assert(coroutine.resume(co_missionvote, "vote", id, msg))
		else
			serv_msg(_("No active missionvote"), id)
		end
	--delete vote if player left server
	elseif event == "delete" then
		if co_status == "suspended" then
			assert(coroutine.resume(co_missionvote, "delete", id))
		end
	--stop vote by admin
	elseif event == "stop" then
		if co_status == "suspended" then
			-- assert(coroutine.resume(co_missionvote, "stop"))
			co_votekick = helper_CoroutineEnd(co_missionvote, "stop")
		end
	end
end

--starts missionpolls and handles related events
function missionpoll(event, id, msg)	
	--coroutine that keeps track of the missionpoll's state
	local function missionpoll_coroutine(starterID)
		--init
		local starttime = os.time()
		local votes = {}
		local stop = false
		local stop_reason
		local poll_event, id, msg, vote
		
		--send start message
		serv_msg(_f("%q started a MISSIONPOLL. Please vote which mission should be loaded next!", 
				tblPlayersSrv[starterID].name))
		servercmd_missions()
		serv_msg(_("Use '/v ID' to vote for the mission with number ID (Ex.: /v 4)! "
				.. "Use '/v 0' to continue current mission"))
		log_write(_f("Player id=[%d], addr = %s, name = %q started a missionpoll",
			starterID, tblPlayersSrv[starterID].addr, tblPlayersSrv[starterID].name))
		
		--wait for poll events
		while not stop do
			poll_event, id, msg = coroutine.yield(-1)
			--check if poll time is over
			if poll_event == "check" then
				if os.difftime(os.time(), starttime) > conf.vote_timeout then
					stop = true
					stop_reason = "close"
				end
			--process vote
			elseif poll_event == "vote" then
				if not votes[id] then
					vote = tonumber(msg)
					if vote and (mp_missions[vote]) then
						votes[id] = vote
						serv_msg(_f("%q voted for mission %q", tblPlayersSrv[id].name, mp_missions[vote]))
					elseif vote and vote == 0 then
						votes[id] = vote
						serv_msg(_f("%q voted to continue current mission", tblPlayersSrv[id].name))
					else
						serv_msg(_("Invalid mission ID"), id)
					end
				else
					serv_msg(_("Already voted!"), id)
				end
			--delete vote if player left and stop poll if server empty
			elseif poll_event == "delete" then
				votes[id] = nil
				if table.maxn(tblPlayersSrv) == 1 then
					stop_reason = "empty"
					stop = true
				end
			--stop vote by admin
			elseif poll_event == "stop" then
				stop_reason = "stop"
				stop = true
			end
		end
		
		--stop poll if server empty, otherwise evaluate votes
		local winner, message
		if stop_reason == "empty" then
			winner = 0
			message = _("Missionpoll stopped! All players left server")
		elseif stop_reason == "stop" then
			winner = 0
			message = _("Missionpoll has been stopped by admin!")
		else
			--count votes
			local result = {}
			local vote_count = 0
			for miz = 0, #mp_missions do
				result[miz] = 0
			end
			for dummy, miz in pairs(votes) do
				result[miz] = result[miz] + 1
				vote_count = vote_count + 1
			end
			
			--check if enough votes
			local player_count = 0
			local vote_percentage = 0
			for i, j in pairs(tblPlayersSrv) do
				player_count = player_count + 1
			end
			if player_count > 0 then
				vote_percentage = (vote_count / player_count) * 100 
			end
			if vote_percentage >= conf.min_votes_in_percent then
				--evaluate missionpoll
				local winners = {}
				local maximum = 0
				local win_no
				local stats = _("Missionpoll stats (mission ID : votes): ")
				
				--determine maximum and log stats
				for miz, number in pairs(result) do
					stats = stats .. miz .. ":" .. number .. "|"
					if number > maximum then
						maximum = number
					end
				end
				serv_msg(stats)
				log_write(stats)
				
				--determine winner(s)
				if maximum > result[0] then
					win_no = 0
					for miz, number in ipairs(result) do
						if number == maximum then
							win_no = win_no + 1
							winners[win_no] = miz
						end
					end
					winner = winners[math.random(win_no)]
					message = _f("Missionpoll result: players decided to load mission %q", 
							mp_missions[winner])
				else
					winner = 0
					message = _("Missionpoll result: players decided to continue current mission")
				end
			else
				--not enough votes
				winner = 0
				message = _f("Missionpoll failed! Not enough votes (%d, needed %d)! "
						.. "Current mission continues.", vote_count, 
						math.ceil(player_count * (conf.min_votes_in_percent / 100)))
			end
		end
		
		--log result
		serv_msg(message)
		log_write(message)
		
		return winner
	end -- missionpoll_coroutine
	
	--dispatch events to coroutine
	--init
	local dummy, result, co_status
	local start_time = os.time()
	if type(co_missionpoll) == "thread" then
		co_status = coroutine.status(co_missionpoll)
	else
		co_status = "dead"
	end
	
	--check if time for missionpoll is over and load winning mission
	if event == "check" then
		if co_status == "suspended" then
			dummy, result = assert(coroutine.resume(co_missionpoll, "check"))
			if result > 0 then
				co_missionpoll = nil
				--return net.load_mission("./Missions/Multiplayer/" .. mp_missions[result])
				return net.load_mission(missionfolder .. mp_missions[result])
			elseif result == 0 then
				co_missionpoll = nil
			end
		end
	--start new missionpoll
	elseif event == "start" then
		if not conf.missionvotes then
			serv_msg(_("Missionpolls are not enabled!"), id)
		elseif co_status ~= "dead" or (type(co_missionvote) == "thread" 
				and coroutine.status(co_missionvote) ~= "dead") then
			serv_msg(_("Another missionvote/-poll already in progress..."), id)
		elseif tblPlayersSrv[id].permlevel<permlevel.admin and (tblPlayersSrv[id].last_mizvote ~= 0) 
				and (os.difftime(start_time - tblPlayersSrv[id].last_mizvote) 
				<= (conf.time_between_votes * 60)) then
			serv_msg(_f("Wait %d seconds before starting another vote!", math.floor(
					conf.time_between_votes * 60 - (start_time - tblPlayersSrv[id].last_mizvote))), id)
		else
			tblPlayersSrv[id].last_mizvote = start_time
			co_missionpoll = coroutine.create(missionpoll_coroutine)
			assert(coroutine.resume(co_missionpoll, id))
		end
	--process vote for missionpoll
	elseif event == "vote" then
		if co_status == "suspended" then
			assert(coroutine.resume(co_missionpoll, "vote", id, msg))
		else
			serv_msg(_("No active missionpoll"), id)
		end	
	--delete poll if player left server
	elseif event == "delete" then
		if co_status == "suspended" then
			assert(coroutine.resume(co_missionpoll, "delete", id))
		end
	--stop poll by admin
	elseif event == "stop" then
		if co_status == "suspended" then
			assert(coroutine.resume(co_missionpoll, "stop"))
			co_missionpoll = helper_CoroutineEnd(co_missionpoll, "stop")
		end
	end
end

function show_timeleft(custom_time)
	local msg, miz_event
	local remaining, hrs, mins, secs
	if conf.rotate_miz_after > 0 then
		remaining = custom_time or conf.rotate_miz_after * 60 - math.floor(net.get_model_time())
		miz_event = _("MISSION ROTATE")
	elseif conf.restart_miz_after > 0 then
		remaining = custom_time or conf.restart_miz_after * 60 - math.floor(net.get_model_time())
		miz_event = _("MISSION RESTART")
	else
		msg = ("Automatic mission restarting/rotating is disabled")
	end
	
	secs = remaining % 60
	remaining = (remaining - secs) / 60
	mins = remaining % 60
	hrs = (remaining - mins) / 60
	
	if custom_time and hrs>0 and mins==0 and secs==0 then
		msg = _f("%s in: %d hour(s)", miz_event, hrs)
	elseif custom_time and hrs==0 and mins>0 and secs==0 then
		msg = _f("%s in: %d minute(s)", miz_event, mins)
	elseif hrs>0 then
		msg = _f("%s in: %dh %dm %ds", miz_event, hrs, mins, secs)
	else
		msg = _f("%s in: %dm %ds", miz_event, mins, secs)
	end
	--serv_msg(_f("%dh %dm %ds remaining before loading next mission", hrs, mins, secs), id)
	
	return msg
end

------------------------------------------------------------------
-- Generic Functions
------------------------------------------------------------------

-- formats a string 
function _f(str, ...)
	return string.format(_(str), ...)
end

--removes leading/trailing whitespaces
function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- Helper
-- Compatibility: Lua-5.0, http://lua-users.org/wiki/SplitJoin
function split(str, delim, maxNb)
	-- Eliminate bad cases...
	if string.find(str, delim) == nil then
		return { str }
	end
	if maxNb == nil or maxNb < 1 then
		maxNb = 0    -- No limit
	end
	local result = {}
	local pat = "(.-)" .. delim .. "()"
	local nb = 0
	local lastPos
	for part, pos in string.gfind(str, pat) do
		nb = nb + 1
		result[nb] = part
		lastPos = pos
		if nb == maxNb then break end
	end
	-- Handle the last field
	if nb ~= maxNb then
		result[nb + 1] = string.sub(str, lastPos)
	end
	return result
end

-- Helper
-- Unpacks any table into a delimetered string
function unpack2str(t,delim)
	local str = ""
	delim = delim or ""
	if t and type(t)=='table' then
		for k,v in pairs(t) do
			if v and type(v)=='table' then
				str = myunpack(t,delim)
			elseif v and type(v)~='function' then
				if string.len(str)>0 then
					str = str..delim..tostring(v)
				else
					str = tostring(v)
				end
			end
		end
	elseif t and type(t)~='function' then
		if string.len(str)>0 then
			str = str..delim..tostring(t)
		else
			str = tostring(t)
		end
	end
	return str
end


function argtypechecker(argtype,...)
	local args = ...
	local argc = tcount(args)
	if args and argc>0 then
		-- multiple values
		local argstext = 0
		local argsnum = 0
		local valkind
		argtype = string.lower(argtype)
		if type(args)=='table' then
			for key,val in pairs(args) do
				-- check to see if it's a number
				valkind = nil
				valkind = string.find(val,"^[+-]?%d+$")
				if valkind and valkind>=1 then 
					argsnum = argsnum + 1
				else
					-- since no match for ID/number only, must assume it's a word/name.
					valkind = val:match("%w+")
					if valkind and string.len(valkind)>=1 then
						argstext = argstext + 1
					end
				end
			end
		else
			-- perhaps a single parameter?
			valkind = nil
			args = tostring(args)
			valkind = string.find(args,"^[+-]?%d+$")
			if valkind and valkind>=1 then 
				argsnum = argsnum + 1
			else
				-- since no match for ID/number only, must assume it's a word/name.
				valkind = args:match("%w+")
				if valkind and string.len(valkind)>=1 then
					argstext = argstext + 1
				end
			end			
		end

		if argc == argsnum and argtype=='number' then
			return true, 'number'
		elseif argc == argstext and (argtype=='text' or argtype=='string') then
			return true, 'string'
		end
		return false
	else
		return false
	end
end

-- Helper, tablecount.
-- Sometimes #mytable doesn't return the correct count.
tcount = function(t)
	local i, kk, vv
	i = 0
	if t then
		if type(t)=='table' then
			for kk,vv in pairs(t) do
				i = i +1
			end
		elseif (type(t)=='string' and t~='') or (type(t)=='number') then
			i = 1
		end
	end
	return i
end


-- helper to strip away the path in a FQ-filepath
function get_filename(filepath)
	local fn = string.gsub(filepath, "\\", "/")
	local idx = 0
	while true do
		idx = 0
		idx = string.find(fn, "/", idx + 1)
		if idx == nil then break end		
		fn = string.sub(fn, idx + 1, -1)			
	end
	return fn
end


function conf_merge(src, dest)
	local k,v
	for k,v in pairs(src) do
		local d = dest[k]
		if type(v)=="table" and type(d)=="table" and v[1] == nil then
			conf_merge(d, v)
		else
			dest[k] = v
		end
	end
end

-- Used to grab a custom conf, as well as the defaults
-- merging them into a working configuration.
function get_conftable(conf_file)
	--serv_msg('DEBUG: Trying: '..conf_file)
	local sm_sysconf = { 'bantables.lua', 'commands.lua', 'dynsettings.lua', 'serverconfig.lua' }
	
	local function get_conf(conf_file)
		--load and compile file
		local err, chunk, msg
		local ok, tables
		chunk, err = loadfile(conf_file)
		if err then
			msg = "### SERVMAN ERROR: Could not load/compile '"..conf_file.."' file. Error: " .. err
			return false,msg
		else
			--run file in protected mode to catch possible runtime errors
			ok, tables = pcall(chunk)
			if not ok then
				msg = "### SERVMAN ERROR: Could not execute '"..conf_file.."' file. Error: " .. tables
				return false,msg
			else
				return ok, tables
			end
		end
	end
	
	--load and compile file
	local fname
	local ok1,conf_defaults
	local ok2,conf_custom

	-- try the custom config first, no error if it doesn't exist.
	fname = sm_custompath..'/'..conf_file
	log_write("SERVER::get_conftable(), Trying '"..fname)
	ok2,conf_custom = get_conf(fname)	-- defaults	
	if ok2 then
		log_write("SERVER::get_conftable(), Loaded '"..fname)	
	end
	
	-- try default next, error if it doesn't exist
	fname = sm_rootpath..'/'..conf_file
	log_write("SERVER::get_conftable(), Trying '"..fname)
	ok1,conf_defaults = get_conf(fname)	-- defaults
	if ok1 then
		log_write("SERVER::get_conftable(), Loaded '"..fname)		
		if ok2 then
			conf_merge(conf_custom, conf_defaults) -- merge custom values over defaults.
			log_write("SERVER::get_conftable(), Merged CUSTOM and DEFAULT config")
		else
			log_write("SERVER::get_conftable(), DEFAULT config being returned")		
		end
		return ok1, unpack(conf_defaults)
	elseif ok2 then
		log_write("SERVER::get_conftable(), CUSTOM config being returned")		
		return ok2, unpack(conf_custom)
	else
		log_write("SERVER::get_conftable(), FAILED - no config being returned")		
		return false,conf_defaults -- conf_defaults contains the error msg.
	end
		
end	

-- Creates a true copy of object -- from mist
function deepCopy(object)
	local lookup_table = {}
	local function _copy(object)
		if type(object) ~= "table" then
			return object
		elseif lookup_table[object] then
			return lookup_table[object]
		end
		local new_table = {}
		lookup_table[object] = new_table
		for index, value in pairs(object) do
			new_table[_copy(index)] = _copy(value)
		end
		return setmetatable(new_table, getmetatable(object))
	end
	return _copy(object)
end

------------------------------------------------------------------
--GLOBAL SERVER FUNCTIONS :
--these are also being called from the events.lua script
------------------------------------------------------------------
function BanKickManager(playerid, banevent, banreason,adminid)
	--check if player will already be kicked
	if tblPlayersSrv[playerid].will_be_kicked==true then return end
	
	log_write(string.format("SERVER::BanKickManager id=%d %s",playerid,banevent))
	if not conf.bankick_enabled and banevent~="admin" then
		log_write(string.format("SERVER::BanKickManager disabled - exiting"))
		return
	end
	--init
	tblPlayersSrv[playerid].will_be_kicked = true
	local addr = tblPlayersSrv[playerid].addr
	local name = tblPlayersSrv[playerid].name
	local msg
	
	--log
	msg = _f("KICKED client: id = [%d], addr = %s, name = %q. Reason = %q", playerid, addr, name, banreason)
	log_write(msg)
	
	-- -- possible events
	-- bkevent = "server_locked"
	-- bkevent = "name_banned"
	-- bkevent = "in_banlist"
	-- bkevent = "penalty_time"
	-- bkevent = "left_before_votekick"
	-- bkevent = "votekick"
	-- bkevent = "admin"
	
	--update player's kick stats and possibly ban player, but only if the reason is not penalty time, player already banned or server locked
	if banevent ~= "penalty_time" and banevent ~= "in_banlist" and banevent ~= "server_locked" and banevent ~= "name_banned" then
		-- show public message
		local servermsg
		if not adminid then 
			servermsg = _f("KICK: client %q (ID=%d) has been kicked automatically. Reason: %s", name, playerid, banreason)
		else 
			servermsg = _f("KICK: client %q (ID=%d) has been kicked. Reason: %s", name, playerid, banreason)
		end
		serv_msg(servermsg)
		
		--add to/update table with players kicked during this session
		if not kicked_players[addr] then
			kicked_players[addr] = { last_time = os.time(), kicks = 1 }
		else
			kicked_players[addr].last_time = os.time()
			kicked_players[addr].kicks = kicked_players[addr].kicks + 1
		end
		
		--ban player if banned by admin or autoban enabled and number of necessary kicks reached
		if banevent == "admin" then
			banAdd(playerid,"admin",banreason,adminid)
			kicked_players[addr] = nil
		elseif(conf.autoban_after_kicks > 0) 
				and (kicked_players[addr].kicks >= conf.autoban_after_kicks) then
			banAdd(playerid, "autoban","Too many kicks")
			kicked_players[addr] = nil
		end
	else
		--set mutex so that server will not be unlocked or restarted if client is kicked directly after connecting
		mutex = true
	end
	
	--kick player if he does not leave anyway (i.e. he left during votekick)
	if banevent ~= "left_before_votekick" then
		return net.kick(playerid, "ServMan: " .. _(banreason))
	end
end


-- Ban-manager, list, filters and lifts bans.
function BanManager(id,bevent,...)
	-- *****************************************************************************************
	-- NOTE NOTE, I've discovered something crazy.
	-- string.find and string.match fails to match a string like "knsdfjk2kn3skd-3298hnnd" vs itself. Nil return.
	-- local mytest=string.find("knsdfjk2kn3skd-3298hnnd","knsdfjk2kn3skd-3298hnnd")
	-- returns nil
	-- *****************************************************************************************	
	local args = ...

	local imatches = 0
	local iactive = 0
	local inactive = 0

	local names, addresses, ucids, reason
	local banrecID, banfld
	if bevent=='list' then
		for banrecID,banfld in ipairs(bantables) do
			-- only active bans please
			if banfld["active"]==true then
				names = unpack2str(banfld.names,", ")
				addresses = unpack2str(banfld.ipaddrs,", ")
				ucids = unpack2str(banfld.ucid,", ")
				reason = banfld.comment
				serv_msg(string.format("[%s] - Names: %q - UCIDs: %q - IPs: %q - Reason: %q",banrecID, names,ucids, addresses,reason),id)
				iactive = iactive + 1
			else
				inactive = inactive + 1
			end
		end
		if iactive==inactive+iactive then
			serv_msg(string.format("You have a total of %d active bans.",iactive),id)
		else
			serv_msg(string.format("Listed %d active bans out of %d total bans",iactive,inactive+iactive),id)
		end
	end

	if bevent=='listfilter' or bevent=='remove' or bevent=='getid' then
		local idlist = nil
		if args and tcount(args)>0 then
			local argtype, match, matchtype
			-- prepare arg types for easier and more precise matches
			if argtypechecker('number',args) then
				argtype = 'number'
			else
				argtype = 'string'
			end
			for banrecID,banfld in ipairs(bantables) do
				-- only active bans
				local k,v
				if banfld.active==true then
					names = unpack2str(banfld.names,", ")
					addresses = unpack2str(banfld.ipaddrs,", ")
					ucids = unpack2str(banfld.ucid,", ")
					reason = banfld.comment
					match = nil
					matchtype = ''
					
					-- specific search
					if bevent=='getid' then
						k = tostring(args[1])
						v = tostring(args[2])
						if k=='ucid' and string.lower(ucids)==string.lower(v) then
							match = banrecID
							matchtype = k
						elseif k=='name' and (string.lower(names)==string.lower(v) or string.find(string.lower(names),string.lower(v))) then
							match = banrecID
							matchtype = k
						elseif k=='addr' and (addresses==v or string.find(addresses,v)) then
							match = banrecID
							matchtype = k
						end
					else
						-- regular open search, slower.
						for k,v in pairs(args) do
							v = string.lower(tostring(v))
							local lname = string.lower(names)
							if string.find(lname,v) then
								match = banrecID
								matchtype = 'Name'
							elseif argtype == 'number' and tonumber(v)==tonumber(banrecID) then
								match = banrecID
								matchtype = 'BanID'
							elseif argtype == 'string' and string.find(addresses,v) then
								match = banrecID
								matchtype = 'IP'
							elseif argtype == 'string' and string.find(reason,v) then
								match = banrecID
								matchtype = 'Reason'
							end
						end
					end
					
					if match then
						imatches = imatches + 1
						if bevent=='remove' then
							-- Set the ban to inactive. Bans should not dissapear from the file until an 
							-- admin purges the list, this is to prevent drunk members from messing with the ban tables.
							serv_msg(string.format("Lifting ban [%s]: Names: %q - IPs: %q - Reason: %q",banrecID, names, addresses,reason),id)
							log_write(string.format("Lifting ban [%s]: Names: %q - IPs: %q - Reason: %q",banrecID, names, addresses,reason))
							log_write(string.format("Ban lifted by %q on %s",tostring(tblPlayersSrv[id].name), tostring(os.date("%c"))))
							bantables[banrecID].active = false
							bantables[banrecID].banlifted = string.format("Ban lifted by %q on %s",tostring(tblPlayersSrv[id].name), tostring(os.date("%c")))
						elseif bevent=='listfilter' then
							serv_msg(string.format("Match in %s: BanID[%s] - Names: %q - UCIDs: %q - IPs: %q - Reason: %q",matchtype, banrecID, names, ucids, addresses,reason),id)
						elseif bevent=='getid' then
							if idlist then idlist[match] = matchtype else idlist = {match = matchtype} end
						end
					end
					iactive = iactive + 1
				else
					inactive = inactive + 1				
				end
			end
			
			-- conclude and summarize the results
			if bevent=='remove' then
				if imatches == 0 then
					serv_msg(string.format("No match found. You have %d active bans out of %d total bans",iactive,inactive+iactive),id)
				else
					serv_msg(string.format("Bantable updated. You have %d active bans out of %d total bans",iactive-imatches,inactive+iactive),id)
					log_write(string.format("Bantable updated. You have %d active bans out of %d total bans",iactive-imatches,inactive+iactive))
				end
			elseif bevent=='getid' then
				return idlist
			else
				if id and imatches == 0 then
					serv_msg(string.format("No match found. You have %d active bans out of %d total bans",iactive,inactive+iactive),id)
				else
					serv_msg(string.format("Listed %d matches with %d active bans in store, out of %d total bans",imatches,iactive,inactive+iactive),id)
				end
			end
		end
	end
end



function filemanager(fmevent,fmfile,tbl,strtblname)
	-- load returns table / err msg
	-- save returns bol success / err msg
	if fmevent=='save' then
		local commonenv = {} -- normally we use the global for this, but lets keep it local until we start using it later on.
		if tbl.loadfail and tbl.loadfail==true then
			serv_msg(_f("%q contains invalid records - we shouldn't overwrite it. Please fix it.",fmfile))
			return
		end
		
		local file,err = io.open(fmfile, 'w')
		if err then			
			msg = "ERROR: Could not create "..fmfile..". Error is: ".. err
			net.log(msg)
			return false, msg
		end
		
		if file then
			local ser = Factory.create(Serialize, file)
			-- serialize using a common env, aka commonenv, so varibales can crossref each other during save.
			ser:serialize_simple2(strtblname, tbl, commonenv)
			file:close()
			return _f("%s successfully updated",strtblname)
		else
			return nil,_f("### SERVMAN ERROR: %q update failed",strtblname)
		end	
	end
	
	if fmevent=='load' then
		local ok = false
		--load and compile file
		local loadf, err = loadfile(fmfile)
		if err then
			msg = "### SERVMAN ERROR: Could not load/compile '"..fmfile.."' - Error: " .. err
			log_write(msg)
			--serv_msg(msg)
			return false, msg
		else
			local tbltmp
			--run file in protected mode to catch possible runtime errors
			ok, tbltmp = pcall(loadf)
			if not ok then
				msg = "### SERVMAN ERROR: Could not execute '"..fmfile.."' file. Error: " .. tbltmp
				log_write(msg)
				-- serv_msg(msg)
				tbltmp = { loadfail = true }
				return false, msg
			else
				msg = _f("SERVMAN: Succesfully loaded %q.",fmfile)
				log_write(msg)
				--serv_msg(msg)
				return tbltmp
			end
		end	
	end
end

function players_changed(id, addr, port, name, ucid)
	local msg
	local plAction
	local player_count = tcount(tblPlayersSrv)
	
	if id~=nil and addr~=nil then
		-- added player
		log_write(string.format("SERVER::players_changed(), new player"))
		player_create(id, addr, name, ucid)
		plAction='create'
		player_count=player_count+1
	elseif id~=nil then
		-- removed player
		log_write(string.format("SERVER::players_changed(), remove player"))
		player_remove(id)
		plAction='remove'
		player_count=player_count-1
	else
		return
	end
	
	-- ACTIONS to check when people connect
	if plAction=='create' then
		local bkevent
		-- we can have a locked server even if bankicks are disabled.
		if locked then
			msg = "Server is locked."
			bkevent = "server_locked"
			BanKickManager(id,bkevent,msg)
			return false, "ServMan: " .. _(msg)
		end
		
		if conf.bankick_enabled then
			if conf.bankick_byucid or conf.bankick_byip or conf.bankick_byname then
				local bmsg, berr = BanExist(nil,name,addr,ucid)
				if bmsg then
					local banreason = bmsg
					msg = "DENIED: "..banreason..""
					bkevent = "in_banlist"
					BanKickManager(id,bkevent,msg)
					tblPlayersSrv[id].will_be_kicked = true
					return false, "ServMan: " .. _(msg)
				elseif berr then
					serv_msg(_f("###ERROR ON_CONNECT: %s", berr))
				end
			end
			--if player name banned or empty (the latter is necessary to discern humans from AI in the events.lua script)
			if (trim(name) == "") or (conf.bankick_byname and (banned_names[trim(string.lower(name))] or banned_names[trim(name)])) then
				local banreason = "Name '"..name.."' not allowed"
				msg = "BANNED: "..banreason..""
				bkevent = "name_banned"
				BanKickManager(id,bkevent,msg)
				tblPlayersSrv[id].will_be_kicked = true
				return false, "ServMan: " .. _(msg)
			--if player banned by IP
			elseif conf.bankick_byip and in_banned_IP_range(addr) then
				-- checks for the subnetted ip-range bans
				local banreason = "IP-range banned"
				msg = "BANNED IP: "..banreason..""
				bkevent = "in_banlist"
				BanKickManager(id,bkevent,msg)
				tblPlayersSrv[id].will_be_kicked = true
				return false, "ServMan: " .. _(msg)
			--if player's penalty time after previous kick has not expired yet
			elseif (conf.wait_after_kick > 0 and kicked_players[addr] and (os.difftime(os.time(), 
					kicked_players[addr].last_time) < 60 * conf.wait_after_kick)) then
				msg = _f("Penalty %d mins. Try again later.",conf.wait_after_kick)
				bkevent = "penalty_time"
				BanKickManager(id,bkevent,msg)		
				tblPlayersSrv[id].will_be_kicked = true
				return false, "ServMan: " .. _(msg)
			end
		end
		
		if MOTD_playerconnect==false then
			-- activate 2 min counter, if already active no new MOTD-counter, we don't need MOTD spam on player connect.
			MOTD_playerconnect=true
			last_MOTD=os.time()
		end
		
		--resume mission if server was empty and function enabled
		resume_or_pause()

	end
	
	-- ACTIONS to check when people disconnect
	if plAction=='remove' then
		if net.get_name(id) then
			msg = _f("Disconnected client: [%d] %q", id, net.get_name(id))
		elseif tblPlayersSrv[id] then
			msg = _f("Disconnected client: [%d] %q", id, tblPlayersSrv[id].name)
		else
			msg = _f("Disconnected client: [%d]", id)
		end
		log_write(msg)
		
		if tcount(tblPlayersSrv)==1 and not mutex then
			--unlock server if locked
			if locked then
				locked = false
				local report = _("Server has been unlocked after all players left")
				serv_msg(report)
				log_write(report)
			end
			
			--pause mission if enabled
			if conf.pause_if_server_empty then
				net.pause()
				paused_on_miz(true)
			end
			
			--restart server if enabled
			if conf.restart_if_server_empty then
				local report = _("Automatic restart of current mission (server empty)")
				serv_msg(report)
				log_write(report)
				paused_on_miz(false)
				MOTD_playerconnect=false
				return net.load_mission(current_mission)
			end
		end
		
		tblPlayersSrv[id] = nil
		mutex = false
	end
	
	-- ACTIONS to check regardless of connect / disconnect.
	
	
	return
end

function player_create(id, addr, name, ucid)
	if tblPlayersSrv[id] then
		log_write(string.format("SERVER::on_connect, Existing player - resetting. This should normally not happen."))	
		local p = tblPlayersSrv[id]
		p.plid = id
		p.name = name
		p.addr = addr
		p.ucid = tostring(ucid)
		p.is_subadmin = false
		p.permlevel = 0
		p.teamkills = 0
		p.AI_teamkills = 0
		p.friendly_fire = 0
		p.collisions = 0
		p.login_tries = 0
		p.will_be_kicked = false
		p.ping_warnings = 0
		p.last_mizvote = 0
		p.last_votekick = 0
		if not p.last_collision then p.last_collision = {} end
		if not p.last_friendly_fire then p.last_friendly_fire = {} end
		p.ping.count = 0
		p.ping.sum = 0
	else
		log_write(string.format("SERVER::player_create(%s,%s,%s,%s)",id, addr, name, ucid))
		tblPlayersSrv[id] = {
				plid = id,
				name = name,
				addr = addr,
				ucid = tostring(ucid),
				is_subadmin = false,
				permlevel = 0,
				teamkills = 0,
				AI_teamkills = 0,
				friendly_fire = 0,
				collisions = 0,
				login_tries = 0,
				will_be_kicked = false,
				ping_warnings = 0,
				last_mizvote = 0,
				last_votekick = 0,
				last_collision = {}, 
				last_friendly_fire = {}, 
				ping = { count = 0, sum = 0 } 			
			}
	end
end

function player_remove(id)
	local msg
	
	--log that subadmin left
	if tblPlayersSrv[id] and tblPlayersSrv[id].permlevel>=permlevel.admin then
		msg = _f("Subadmin %q logged out", tblPlayersSrv[id].name)
		serv_msg(msg)
		log_write(msg)
	end
	
	--delete player's vote if votekick active and stop votekick if player to be kicked left
	votekick("delete", id)
	
	--delete player's vote if missionvote-/poll active and stop vote/poll if server empty
	missionpoll("delete", id)
	missionvote("delete", id)
	
	tblPlayersSrv[id] = nil
end

--------------------------------------------------
-- load event callbacks

function server_loadaddon(libfile)

	local newenv = getfenv(1)
	net.log(sm_short.."Load library: "..libfile)
	local chunk, err1 = loadfile("Scripts/Addons/"..libfile) -- loads and compiles the chunk

	if chunk then
		net.log(sm_short.."Library loaded: "..libfile)
		if newenv then
			net.log(sm_short.."Setting Env")
			setfenv(chunk, newenv)	
		end
		net.log(sm_short.."Protected call")
		local chunkref, err2 = pcall(chunk)
		if not err2 then
			return chunkref
		else
			net.log(sm_short.."Protected call failed: "..tostring(err2))
			return nil
		end
	else
		net.log(sm_short.."Library couldn't be loaded: "..tostring(err1))
	end
end


server_loadaddon('ServMan3/servman_events.lua')
server_loadaddon("ServMan3/LuaSerializer/Serializer.lua")
net.log(sm_short..'servman_server.lua loaded')

-- if config hasn't been loaded, do so. At recompile all the variables & config will be reset.
if not servman_initcompleted then load_config() end

-- dofile('./Scripts/net/events.lua')
