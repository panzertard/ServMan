------------------------------------------------------------------
-- SERVMAN SERVER MANAGEMENT MOD
-- FILE: events.lua
-- VERSION: 3.0.1
-- AUTHORS: Eagle Dynamics, Panzertard and a caffeine overdose
------------------------------------------------------------------

net.log("SERVMAN:EVENTS initializing")

local log_write = server.log_write

local function translate(str)
	if str ~= "" then
		return gettext.translate(str)
	else
		return ""
	end
end

local function dtranslate(dom, str)
	if str ~= "" then
		return gettext.dtranslate(dom, str)
	else
		return ""
	end
end

_ = translate

if not unit2player then local unit2player = {} end
if not players then local players = server.tblPlayersSrv end


------------------------------------------------------------------
-- NETWORK GAME CALLBACKS, Events
------------------------------------------------------------------

-- called when simulation starts
function on_start()
	net.log("EVENTS::on_start()")
	server.log_write("----------------------------------------")
	server.log_write("EVENTS::on_start()")
	-- -- TODO: move this to client.on_connect
	if not net.is_server() then	
		-- I dont think this situation should occur, but just in case it does.
		local myid = net.get_local_id()
		local myname = net.get_name(myid)
		players[myid] = { name = myname }
		log(string.format("Started network game. My id=%d, my name=%q", myid, myname))
		return true
	end
	
	local myid = net.get_local_id()
	local myname = net.get_name(myid)

	unit2player = {}
	server.log_write(string.format("Started network game. My id=%d, my name=%q", myid, myname))
	players = server.tblPlayersSrv

	if not players[myid] then
		server.log_write("EVENTS::on_start, Server didn't exist, reset server info. Panzer. Check this.")
		players[myid] = { 
			-- id = myid, 
			name = myname, 
			last_collision = {}, 
			last_friendly_fire = {}, 
			ping = { count = 0, sum = 0 } 
		}
	end
	server.resume_or_pause()
	
end

-- called when simulation stops
function on_stop()
	--server.log_write("EVENTS::on_stop()")
end

-- called on client only.
function on_pause()
end

-- called on client only.
function on_resume()
end

function on_player_add(plid, name_,...)
	-- players[id] = { name = name_ }
	-- report(_("%s entered the game."), player_info_noside(id))
	
	server.log_write(string.format("EVENTS::on_player_add(%s, %s)",plid, name_))
	local args = ...
	if args and #args>0 then
		server.log_write(string.format("EVENTS::on_player_add -------------------->>>>>>>, New arg %s)",unpack(args)))
		for k,v in pairs(args) do
			server.log_write(string.format("NEWARG::%s=%q",tostring(k),tostring(v)))
		end
	end
	if server.tblPlayersSrv[plid] then
		server.log_write(string.format("EVENTS::on_player_add, Existing player - nothing to do."))	
	else
		server.log_write(string.format("EVENTS::on_player_add, New player."))	
		server.tblPlayersSrv[plid] = {
				plid = plid,
				name = name_,
				ucid = "unknown",
				addr = "unknown",				
				is_subadmin = false,
				is_squad = false,
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
	if server.tblPlayersSrv[plid].will_be_kicked==true then
		report(_("%s tried to enter, got kicked"), player_info_noside(plid))
	else
		report(_("%s entered the game."), player_info_noside(plid))
	end	
	
end

--called when a player leaves the server 
-- Note, this is called after SERVER.on_disconnect in most situations, not sure if it will be called before server, anytime at all.
function on_player_del(id)
	server.log_write(string.format("EVENTS::on_player_del(%s)",id))
	--report(_("%s left the game."), player_info(id))
	local p = players[id]
	if p then
		local unit = p.unit
		if unit then unit2player[unit] = nil end
		players[id] = nil
	end
	
	-- --report(_("%s left the game."), player_info(id))
	-- --delete player
	-- local p = server.tblPlayersSrv[id]
	-- if p then
		-- local unit = p.unit
		-- if unit then unit2player[unit] = nil end
		-- server.tblPlayersSrv[id] = nil
	-- end
	
end



function on_player_name(id, name)
	-- report(_("%s changed name to %q."), player_info(id), name)
	-- players[id].name = name
	server.log_write(string.format("EVENTS::on_player_name(%s, %s)",id, name))
	report(_("%s changed name to %q."), player_info(id), name)
	server.tblPlayersSrv[id].name = name
end

-- not implemented
--function on_player_spawn(id)
--end

function on_player_slot(id, side, unit)
	local p = players[id]
	if p then
		if p.unit then unit2player[p.unit] = nil end
		p.side = side
		p.unit = unit
	end
	if unit ~= "" then
		unit2player[unit] = p
	end
	report(select_by_side(side,
		_("%s joined RED in %s."),
		_("%s joined BLUE in %s."),
		_("%s joined SPECTATORS."))
		, player_info_noside(id), unit_info(unit))
end

-- called when the stats of a player change.
-- Taken from the .\Eagle Dynamics\DCS A-10C\Scripts\net\readme.txt
function on_player_stat(id, stat, value)
	--check that this function is not called on a client. It is necessary to check this because on a client the server's environment is loaded 
	--(and hence this function) between two missions and the hook can also be called during mission loading
	if not net.is_server() then
		server.log_write(string.format("EVENTS:::on_player_stat: Exiting - should not happen if I'm a server"))
		return
	end
	
	local player = server.tblPlayersSrv[id]
	if not player then server.log_write(string.format("EVENTS:on_player_stat. Player not defined, player id = [%d]",id)) return end
	-- some exceptions to the logging
	if server.conf.loglevel==3 and statlookup(stat)=="ping" then server.log_write(string.format("EVENTS:::on_player_stat(%s, %s, %s)",get_name(id),  statlookup(stat), value)) end
	if server.conf.loglevel==2 and statlookup(stat)~="ping" then server.log_write(string.format("EVENTS::on_player_stat(%s, %s, %s)",get_name(id),  statlookup(stat), value)) end
	
	--kick if autokicking below a certain score is enabled and score < limit
	if (stat == 5 and server.conf.kick_below_score < 0 and value < server.conf.kick_below_score) then
		if player ~= nil and player.permlevel<=server.conf.kickbanlevel then
			--return server.kick_ban(id, "Too low score")
			return server.BanKickManager(id, "tk","Too low score")
		end
	end

	--update average ping and warn/kick if too high
	if (stat == 0 and net.get_unit(id) ~= 0 and server.conf.kick_after_max_ping_events > 0)
			and player ~= nil and player.permlevel<=server.conf.kickbanlevel then
		local count = player.ping.count
		player.ping.sum = player.ping.sum + value
		player.ping.count = count + 1
		if count == 100 then --check avg ping every 100 ping events
			player.ping.count = 0
			local max_ping = server.conf.max_average_ping
			local kick_after_max_ping_events = server.conf.kick_after_max_ping_events
			local avg_ping = math.floor(player.ping.sum / 100)
			player.ping.sum = 0
			if avg_ping > max_ping then --issue ping warning 
				player.ping_warnings = player.ping_warnings + 1
				serv_msg(_f("PING-WARNING %d OF %d: Your average ping is too high "
						.. "(%d, allowed is %d)!", player.ping_warnings, 
						kick_after_max_ping_events, avg_ping, max_ping), id)
				server.log_write(_f("PING-WARNING %d OF %d: issued against player id = [%d], "
						.. "addr = %s, name = %q, average ping = %d", player.ping_warnings, 
						kick_after_max_ping_events, id, player.addr, get_name(id), avg_ping))
				if player.ping_warnings >= kick_after_max_ping_events then --kick
					--return server.kick_ban(id, "Ping too high")
					return server.BanKickManager(id, "ping","Ping too high")
				end
			end
		end
	end
end

function on_eject(id)
	server.log_write(string.format("EVENTS::on_eject(%s)",id))
	report(_("%s ejected."), player_info(id))
	return server.log_write(_f("EJECT: Player id = [%d], name = %q ejected.", id, get_name(id)))
	
end

function on_crash(id)
	server.log_write(string.format("EVENTS::on_crash(%s)",id))
	report(_("%s crashed."), player_info(id))
	return server.log_write(_f("CRASH: Player id = [%d], name = %q crashed.", id, get_name(id)))
end

function on_takeoff(id, airdrome)
	server.log_write(string.format("EVENTS::on_takeoff(%s, %q)",id, airdrome))
	local msg
	if airdrome ~= "" then
		msg = _f("%s took off from %s.", player_info(id), dtranslate("missioneditor", airdrome))
		report(msg)
	else
		msg = _f("%s took off.", player_info(id))
	end
	return server.log_write(_f("TAKE-OFF: Player id = [%d], %s", id, msg))
end

function on_landing(id, airdrome)
	server.log_write(string.format("EVENTS::on_landing(%s, %s)",id, airdrome))
	local msg
	if airdrome ~= "" then
		msg = _f("%s landed at %s.", player_info(id), dtranslate("missioneditor", airdrome))
		report(msg)
	else
		msg = _f("%s landed.", player_info(id))
	end
	return server.log_write(_f("LANDING: Player id = [%d], %s", id, msg))end

function on_kill(id, weapon, victim)
	-- if weapon ~= "" then
		-- report(_("%s killed %s with %s."), player_info(id), bot_info(victim), weapon_info(weapon))
	-- else
		-- report(_("%s killed %s."), player_info(id), bot_info(victim))
	-- end

	server.log_write(string.format("EVENTS::on_kill(%s, %s, %s)",tostring(id), tostring(weapon), tostring(victim)))
	
	local player = server.tblPlayersSrv[id]
	if not player then server.log_write(string.format("EVENTS:on_player_stat. Player not defined, player id = [%d]",id)) return end	
	
	--check if killer is actually human (there seems to be a BS bug that calls this function with wrong parameters, confusing human and AI units)
	if player == nil or player.unit == nil or (get_unit_skill(player.unit) ~= "Player" 
			and get_unit_skill(player.unit) ~= "Client") then
		return
	end
	
	--init
	local teamkill = false
	local friendly_fire = false
	local killer = get_name(id)
	local side_victim = unit_side(victim)
	local side_killer = player_side(id)
	local whom = unit_property(victim, 14)
	local msg, log_msg
	local victim_skill = get_unit_skill(victim)
	
	--determine if human killed AI...
	if whom == "" and victim_skill ~= "Player" and victim_skill ~= "Client" then --player killed AI
		whom = unit_type(victim)
		if not whom or whom == "" then 
			whom = "Static Object"
		end
		--check for AI friendly fire
		if side_killer == side_victim then --check if player has already been kicked
			--AI teamkill
			if player == nil then 
				return
			end
			friendly_fire = true
			player.AI_teamkills = player.AI_teamkills + 1
			--log teamkill
			if server.smdebug then
				server.log_write(string.format("EVENTS::whom         %s",tostring(whom)))
				server.log_write(string.format("EVENTS::weapon       %s",tostring(weapon)))
			end
			-- okai, there's been a few snags where the variables didnt turn up with the type that was expected from them.
			-- to rememdy this there's alot of tostring going on here.
			if weapon and weapon ~= "" then
				server.log_write(string.format("EVENTS::AI-TEAMKILL, weapon defined"))
				-- msg = _f("AI-TEAMKILL: %s %q (ID=%d) teamkilled AI unit %s %q with %s!", side_killer, killer, id, side_victim, whom, weapon)
				-- log_msg = _f("AI-TEAMKILL: Player id = [%d], addr = %s, name = %q, side = %s killed friendly AI unit %s %q with %s.", id, player.addr, killer, side_killer, side_victim, whom, weapon)
				msg = string.format("AI-TEAMKILL: %s %q (ID=%d) teamkilled AI unit %s %q with %s!", tostring(side_killer), tostring(killer), id, tostring(side_victim), tostring(whom), tostring(weapon))
				log_msg = string.format("AI-TEAMKILL: Player id = [%d], addr = %s, name = %q, side = %s killed friendly AI unit %s %q with %s.", id, tostring(player.addr), tostring(killer), tostring(side_killer), tostring(side_victim), tostring(whom), tostring(weapon))
			else
				server.log_write(string.format("EVENTS::AI-TEAMKILL, no weapon defined"))
				-- msg = _f("AI-TEAMKILL: %s %q (ID=%d) teamkilled AI unit %s %q!", side_killer, killer, id, side_victim, whom)
				-- log_msg =  _f("AI-TEAMKILL: Player id = [%d], addr = %s, name = %q, side = %s killed friendly AI unit %s %q.", id, player.addr, killer, side_killer, side_victim, whom)
				msg = string.format("AI-TEAMKILL: %s %q (ID=%d) teamkilled AI unit %s %q!", tostring(side_killer), tostring(killer), id, tostring(side_victim), tostring(whom))
				log_msg = string.format("AI-TEAMKILL: Player id = [%d], addr = %s, name = %q, side = %s killed friendly AI unit %s %q.", id, tostring(player.addr), tostring(killer), tostring(side_killer), tostring(side_victim), tostring(whom))
			end
			serv_msg(msg)
			server.log_write(log_msg)
		else
			--no AI teamkill
			if weapon and weapon ~= "" then
				server.log_write(string.format("EVENTS::AI-KILL, weapon defined"))
				-- report(_f("%s %q killed %s %q with %s."), side_killer, killer, side_victim, whom, weapon)
				-- log_msg = _f("AI-KILL: Player id = [%d], name = %q, side = %s killed AI unit %s %q with %s.",
						-- id, killer, side_killer, side_victim, whom, weapon)
				report(_("%s %q killed %s %q with %s."), tostring(side_killer), tostring(killer), tostring(side_victim), tostring(whom), tostring(weapon))
				log_msg = string.format("AI-KILL: Player id = [%s], name = %q, side = %s killed AI unit %s %q with %s.",
						tostring(id), tostring(killer), tostring(side_killer), tostring(side_victim), tostring(whom), tostring(weapon))
			else
				server.log_write(string.format("EVENTS::AI-KILL, no weapon defined"))
				-- report(_f("%s %q killed %s %q."), side_killer, killer, side_victim, whom)
				-- log_msg = _f("AI-KILL: Player id = [%d], name = %q, side = %s killed AI unit %s %q.",
						-- id, killer, side_killer, side_victim, whom)
				report(_("%s %q killed %s %q."), tostring(side_killer), tostring(killer), tostring(side_victim), tostring(whom))
				log_msg = string.format("AI-KILL: Player id = [%s], name = %q, side = %s killed AI unit %s %q.",
						tostring(id), tostring(killer), tostring(side_killer), tostring(side_victim), tostring(whom))
			end
			server.log_write(log_msg)
		end
	else --player killed another human player
		--check for human teamkill
		if side_killer == side_victim and killer ~= whom then
			--human teamkill
			if player == nil then return end --check if player has already been kicked
			teamkill = true
			player.teamkills = player.teamkills + 1
			-- log teamkill
			if weapon and weapon ~= "" then
				server.log_write(string.format("EVENTS::HUMAN-TEAMKILL, weapon defined"))
				-- msg = _f("TEAMKILL: %s %q (ID=%d) teamkilled player %s %q with %s!",
						-- side_killer, killer, id, side_victim, whom, weapon)
				-- log_msg = _f("TEAMKILL: Player id = [%d], addr = %s, name = %q, side = %s "
						-- .. "teamkilled player %s %q with %s.", id, player.addr, killer, 
						-- side_killer, side_victim, whom, weapon)
				msg = string.format("TEAMKILL: %s %q (ID=%d) teamkilled player %s %q with %s!",
						tostring(side_killer), tostring(killer), id, tostring(side_victim), tostring(whom), tostring(weapon))
				log_msg = string.format("TEAMKILL: Player id = [%d], addr = %s, name = %q, side = %s "
						.. "teamkilled player %s %q with %s.", id, tostring(player.addr), tostring(killer), 
						tostring(side_killer), tostring(side_victim), tostring(whom), tostring(weapon))
			else
				server.log_write(string.format("EVENTS::HUMAN-TEAMKILL, no weapon defined"))
				-- msg = _f("TEAMKILL: %s %q (ID=%d) teamkilled player %s %q!",
						-- side_killer, killer, id, side_victim, whom)
				-- log_msg = _f("TEAMKILL: Player id = [%d], addr = %s, name = %q, side = %s "
						-- .. "teamkilled player %s %q.", id, player.addr, killer, 
						-- side_killer, side_victim, whom)
				msg = string.format("TEAMKILL: %s %q (ID=%d) teamkilled player %s %q!",
						tostring(side_killer), tostring(killer), id, tostring(side_victim), tostring(whom))
				log_msg = string.format("TEAMKILL: Player id = [%d], addr = %s, name = %q, side = %s "
						.. "teamkilled player %s %q.", id, tostring(player.addr), tostring(killer), 
						tostring(side_killer), tostring(side_victim), tostring(whom))
			end
			serv_msg(msg)
			server.log_write(log_msg)
		else
			--no human teamkill (or player killed himself)
			if weapon and weapon ~= "" then
				server.log_write(string.format("EVENTS::NON-HUMAN-KILL, weapon defined"))
				-- report(_("%s %q killed player %s %q with %s."), side_killer, killer, side_victim, 
						-- whom, weapon)
				-- log_msg = _f("KILL: Player id = [%d], name = %q, side = %s killed player %s %q with %s.",
						-- id, killer, side_killer, side_victim, whom, weapon)
				report(_("%s %q killed player %s %q with %s."), tostring(side_killer), tostring(killer), tostring(side_victim), 
						tostring(whom), tostring(weapon))
				log_msg = string.format("KILL: Player id = [%d], name = %q, side = %s killed player %s %q with %s.",
						id, tostring(killer), tostring(side_killer), tostring(side_victim), tostring(whom), tostring(weapon))
			else
				server.log_write(string.format("EVENTS::NON-HUMAN-KILL, no weapon defined"))
				-- report(_("%s %q killed player %s %q."), side_killer, killer, side_victim, whom)
				-- log_msg = _f("KILL: Player id = [%d], name = %q, side = %s killed player %s %q.",
						-- id, killer, side_killer, side_victim, whom)
				report(_("%s %q killed player %s %q."), tostring(side_killer), tostring(killer), tostring(side_victim), tostring(whom))
				log_msg = string.format("KILL: Player id = [%d], name = %q, side = %s killed player %s %q.",
						id, tostring(killer), tostring(side_killer), tostring(side_victim), tostring(whom))
			end
			server.log_write(log_msg)
		end
	end
	
	--kick if kicking for too many (human or AI) teamkills is enabled and number of teamkills >= limit
	if (teamkill and server.conf.kick_after_teamkills > 0 and player.permlevel<=server.conf.kickbanlevel
			and player.teamkills >= server.conf.kick_after_teamkills) then
		return server.BanKickManager(id,"tk","Too many Teamkills")
	elseif (friendly_fire and server.conf.kick_after_AI_teamkills > 0 and player.permlevel<=server.conf.kickbanlevel
			and player.AI_teamkills >= server.conf.kick_after_AI_teamkills) then
		return server.BanKickManager(id,"tk","Too many AI teamkills")
	end	
end

function on_mission_end(winner, msg)
	-- if winner == "" then
		-- local red_score = net.check_mission_result("red")
		-- local blue_score = net.check_mission_result("blue")
		-- net.recv_chat(string.format(_("Mission ended, RED score = %f, BLUE score = %f"), red_score, blue_score))
	-- else
		-- local text
		-- if winner == "RED" then text = _("Mission ended, RED won.")
		-- elseif winner == "BLUE" then text = _("Mission ended, BLUE won.")
		-- else text = _("Mission ended.") end
		-- net.recv_chat(text)
		-- if msg ~= "" then net.recv_chat(msg) end
	-- end
	server.log_write(string.format("EVENTS::on_mission_end(%s, %s)",winner, msg))
	if winner == "" then
		local red_score = net.check_mission_result("red")
		local blue_score = net.check_mission_result("blue")
		net.recv_chat(_f("Mission ended, RED score = %f, BLUE score = %f", red_score, blue_score))
	else
		local text
		if winner == "red" then 
			text = _("Mission ended, RED won.")
		elseif winner == "blue" then 
			text = _("Mission ended, BLUE won.")
		else 
			text = _("Mission ended.") 
		end
		net.recv_chat(text)
		if msg ~= "" then 
			net.recv_chat(msg) 
		end
	end	
	
end

function on_damage(shooter_objid, weapon_objid, victim_objid)
	-- --- ORIG EVENTS
	-- local shooter_id = net.get_unit_property(shooter_objid, 2)
	-- local weapon_id = net.get_unit_property(weapon_objid, 2)
	-- local offence_player = unit2player[shooter_id] or unit2player[weapon_id]

	-- local victim_id = net.get_unit_property(victim_objid, 2)
	-- local defence_player = unit2player[victim_id]

	-- if offence_player and defence_player then
		-- if offence_player.side == defence_player.side then
			-- net.recv_chat(string.format(_("%s team-damaged %s"), offence_player.name, defence_player.name))
		-- end
	-- end
	
	--- SERVMAN3
	server.log_write(string.format("EVENTS:::on_damage(%s, %s, %s)",tostring(shooter_objid), tostring(weapon_objid), tostring(victim_objid)))
	local shooter_id = net.get_unit_property(shooter_objid, 2)
	local weapon_id = net.get_unit_property(weapon_objid, 2)
	local offence_player = unit2player[shooter_id] or unit2player[weapon_id]

	local victim_id = net.get_unit_property(victim_objid, 2)
	local defence_player = unit2player[victim_id]
	
	if shooter_id and weapon_id and victim_id then
		server.log_write(string.format("EVENTS:::on_damage(%s, %s, %s)",shooter_id, weapon_id, victim_id))
	end
	
	if offence_player and defence_player then
		if offence_player.side == defence_player.side then
			net.recv_chat(string.format(_("%s team-damaged %s"), offence_player.name, defence_player.name))
		end
	end


	-- determine if human player damaged or rammed teammate
	if offence_player and defence_player then --player shot at another player
		if offence_player.side == defence_player.side and offence_player.id ~= defence_player.id 
				and server.tblPlayersSrv[offence_player.id] ~= nil then --team damage
			-- log friendly fire only when time between last and current incident >= server.conf.friendly_fire_interval
			local curr_time = net.get_real_time()
			if offence_player.last_friendly_fire[defence_player.id] == nil
					or (curr_time - offence_player.last_friendly_fire[defence_player.id]) 
					>= server.conf.friendly_fire_interval then
				offence_player.last_friendly_fire[defence_player.id] = curr_time
				serv_msg(_f("FRIENDLY FIRE: %s %q (ID=%d) damaged teammate %s %q",
						side_name(offence_player.side), offence_player.name, offence_player.id,
						side_name(defence_player.side), defence_player.name))
				server.log_write(_f("FRIENDLY FIRE: Player id = [%d], name = %q, addr = %s, "
						.. "side = %s damaged teammate %s %q", offence_player.id, offence_player.name, 
						server.tblPlayersSrv[offence_player.id].addr, side_name(offence_player.side),  
						side_name(defence_player.side), defence_player.name))
				server.tblPlayersSrv[offence_player.id].friendly_fire = 
						server.tblPlayersSrv[offence_player.id].friendly_fire + 1
			
				--kick if kicking for too many friendly fire incidents is enabled and number of incidents >= limit
				if (server.conf.kick_after_friendly_fire > 0 
						and not server.tblPlayersSrv[offence_player.id].is_subadmin 
						and server.tblPlayersSrv[offence_player.id].friendly_fire 
						>= server.conf.kick_after_friendly_fire) then
					--return server.kick_ban(offence_player.id, "Too much friendly fire")
					return server.BanKickManager(id,"tk","Too much friendly fire")
				end
			end
		end
	elseif server.conf.collision_interval > 0 and defence_player 
			and colliding_player then -- player rammed another
		if colliding_player.side == defence_player.side and colliding_player.id ~= defence_player.id 
				and server.tblPlayersSrv[colliding_player.id] ~= nil 
				and server.tblPlayersSrv[defence_player.id] ~= nil then -- team collision
			-- log collision only when time between last and current collision >= server.conf.collision_interval
			local curr_time = net.get_real_time()
			if colliding_player.last_collision[defence_player.id] == nil
					or (curr_time - colliding_player.last_collision[defence_player.id]) 
					>= server.conf.collision_interval then 
				colliding_player.last_collision[defence_player.id] = curr_time
				defence_player.last_collision[colliding_player.id] = curr_time
				server.tblPlayersSrv[colliding_player.id].collisions = 
						server.tblPlayersSrv[colliding_player.id].collisions + 1
				server.tblPlayersSrv[defence_player.id].collisions = 
						server.tblPlayersSrv[defence_player.id].collisions + 1
				serv_msg(_f("TEAM-COLLISION: %s %q (ID=%d) and %s %q (ID=%d) collided", 
						side_name(colliding_player.side), colliding_player.name, colliding_player.id, 
						side_name(defence_player.side), defence_player.name, defence_player.id))
				server.log_write(_f("TEAM-COLLISION: %s %q (ID=%d, addr=%s) and %s %q (ID=%d, addr=%s) collided", 
						side_name(colliding_player.side), colliding_player.name, colliding_player.id, 
						server.tblPlayersSrv[colliding_player.id].addr, side_name(defence_player.side), 
						defence_player.name, defence_player.id, server.tblPlayersSrv[defence_player.id].addr))
			end
		end
	end


	
	-- -- -- ORIG SERVMAN2
	-- server.log_write(string.format("EVENTS:::on_damage(%s, %s, %s)",tostring(shooter_objid), tostring(weapon_objid), tostring(victim_objid)))
	-- --determine if the units refer to human players
	-- local shooter_id = get_mission_id(shooter_objid)
	-- local weapon_id = get_mission_id(weapon_objid)
	-- local offence_player = unit2player[shooter_id]
	-- local victim_id = get_mission_id(victim_objid)
	-- local defence_player = unit2player[victim_id]
	-- local colliding_player = unit2player[weapon_id]
	
	
	-- if shooter_id and weapon_id and victim_id then
		-- server.log_write(string.format("EVENTS:::on_damage(%s, %s, %s)",shooter_id, weapon_id, victim_id))
	-- end

	-- -- determine if human player damaged or rammed teammate
	-- if offence_player and defence_player then --player shot at another player
		-- if offence_player.side == defence_player.side and offence_player.id ~= defence_player.id 
				-- and server.tblPlayersSrv[offence_player.id] ~= nil then --team damage
			-- -- log friendly fire only when time between last and current incident >= server.conf.friendly_fire_interval
			-- local curr_time = net.get_real_time()
			-- if offence_player.last_friendly_fire[defence_player.id] == nil
					-- or (curr_time - offence_player.last_friendly_fire[defence_player.id]) 
					-- >= server.conf.friendly_fire_interval then
				-- offence_player.last_friendly_fire[defence_player.id] = curr_time
				-- serv_msg(_f("FRIENDLY FIRE: %s %q (ID=%d) damaged teammate %s %q",
						-- side_name(offence_player.side), offence_player.name, offence_player.id,
						-- side_name(defence_player.side), defence_player.name))
				-- server.log_write(_f("FRIENDLY FIRE: Player id = [%d], name = %q, addr = %s, "
						-- .. "side = %s damaged teammate %s %q", offence_player.id, offence_player.name, 
						-- server.tblPlayersSrv[offence_player.id].addr, side_name(offence_player.side),  
						-- side_name(defence_player.side), defence_player.name))
				-- server.tblPlayersSrv[offence_player.id].friendly_fire = 
						-- server.tblPlayersSrv[offence_player.id].friendly_fire + 1
			
				-- --kick if kicking for too many friendly fire incidents is enabled and number of incidents >= limit
				-- if (server.conf.kick_after_friendly_fire > 0 
						-- and not server.tblPlayersSrv[offence_player.id].is_subadmin 
						-- and server.tblPlayersSrv[offence_player.id].friendly_fire 
						-- >= server.conf.kick_after_friendly_fire) then
					-- --return server.kick_ban(offence_player.id, "Too much friendly fire")
					-- return server.BanKickManager(id,"tk","Too much friendly fire")
				-- end
			-- end
		-- end
	-- elseif server.conf.collision_interval > 0 and defence_player 
			-- and colliding_player then -- player rammed another
		-- if colliding_player.side == defence_player.side and colliding_player.id ~= defence_player.id 
				-- and server.tblPlayersSrv[colliding_player.id] ~= nil 
				-- and server.tblPlayersSrv[defence_player.id] ~= nil then -- team collision
			-- -- log collision only when time between last and current collision >= server.conf.collision_interval
			-- local curr_time = net.get_real_time()
			-- if colliding_player.last_collision[defence_player.id] == nil
					-- or (curr_time - colliding_player.last_collision[defence_player.id]) 
					-- >= server.conf.collision_interval then 
				-- colliding_player.last_collision[defence_player.id] = curr_time
				-- defence_player.last_collision[colliding_player.id] = curr_time
				-- server.tblPlayersSrv[colliding_player.id].collisions = 
						-- server.tblPlayersSrv[colliding_player.id].collisions + 1
				-- server.tblPlayersSrv[defence_player.id].collisions = 
						-- server.tblPlayersSrv[defence_player.id].collisions + 1
				-- serv_msg(_f("TEAM-COLLISION: %s %q (ID=%d) and %s %q (ID=%d) collided", 
						-- side_name(colliding_player.side), colliding_player.name, colliding_player.id, 
						-- side_name(defence_player.side), defence_player.name, defence_player.id))
				-- server.log_write(_f("TEAM-COLLISION: %s %q (ID=%d, addr=%s) and %s %q (ID=%d, addr=%s) collided", 
						-- side_name(colliding_player.side), colliding_player.name, colliding_player.id, 
						-- server.tblPlayersSrv[colliding_player.id].addr, side_name(defence_player.side), 
						-- defence_player.name, defence_player.id, server.tblPlayersSrv[defence_player.id].addr))
			-- end
		-- end
	-- end	
end

function on_kill_player(id, weapon, killa)
	-- if weapon ~= "" then
		-- report(_("%s killed %s with %s."), bot_info(killa), player_info(id), weapon_info(weapon))
	-- else
		-- report(_("%s killed %s."), bot_info(killa), player_info(id))
	-- end
	--server.log_write(string.format("EVENTS::on_kill_player(id=%q weapon=%q killa=%q)",tostring(id), tostring(weapon), tostring(killa)))
	if weapon ~= "" and killa ~="" then
		--serv_msg(_f("%s killed %s with %s.", bot_info(killa), player_info(id), weapon_info(weapon)))
		server.log_write(_f("%s killed %s with %s.", bot_info(killa), player_info(id), weapon_info(weapon)))
	elseif killa ~="" then
		--serv_msg(_f("%s killed %s.", bot_info(killa), player_info(id)))
		server.log_write(_f("%s killed %s.", bot_info(killa), player_info(id)))
	else
		--serv_msg(_f("%s is no more.", player_info(id)))
		server.log_write(_f("%s is no more.", player_info(id)))
	end
	return
end

------------------------------------------------------------------
-- Lookups / Conversions
------------------------------------------------------------------

function unit_property(unit, prop)
	return net.get_unit_property(unit, prop) or ""
end

function select_by_side(side, red, blue, spec)
	if side == 1 then return red
	elseif side == 2 then return blue
	else return spec end
end

function unit_type(unit)
	return unit_property(unit, 4)
end

function unit_side(unit)
	local side = unit_property(unit, 11)
	if side == "red" then
		return "Red"
	elseif side == "blue" then
		return "Blue"
	end
	return "Neutral"
end

--converts a side's number to its name
function side_name(side)
	if side == 0 then 
		return "Spectators"
	elseif side == 1 then 
		return "Red"
	else 
		return "Blue"
	end
end

function player_side(pid)
	local p = server.tblPlayersSrv[pid]
	if not p or not p.side then
		return ""
	end

	if p.side == 1 then 
		return "Red"
	elseif p.side == 2 then 
		return "Blue"
	end
	return "Spectator"
end


-- Taken from the .\Eagle Dynamics\DCS A-10C\Scripts\net\readme.txt
function statlookup(statusid)
	local stattable = { 
		[0] = "ping", 
		[1] = "crashes", 
		[2] = "destroyed_groundunits", 
		[3] = "destroyed_airunits", 
		[4] = "destroyed_seaunits", 
		[5] = "score", 
		[6] = "landings", 
		[7] = "ejections"
	}
	return stattable[statusid]
end

player_info_noside = function(id)
	return '"'..get_name(id)..'"';
end

player_info = function(id)
	local p = players[id]
	if not p then return _("UNKNOWN PLAYER") end
	return select_by_side(players[id].side, _("RED player"), _("BLUE player"), _("SPECTATOR")) .. ' "' .. p.name .. '"'
end

unit_info = function(unit)
	return dtranslate("missioneditor", unit_property(unit, 4))
end

bot_info = function(unit)
	local info = unit_property(unit, 14)
	if info == "" then info = unit_info(unit) end
	if info == "" then info = _("Building") end
	return '"'..info..'"'
end

weapon_info = function(weapon)
	return dtranslate("missioneditor", weapon)
end

get_name = function(id)
	local p = players[id]
	if p then return p.name end
	return _("UNKNOWN PLAYER")
end

--converts runtime object id to mission id
function get_mission_id(obj_id)
	--execute the given string in the Scripts/compile.lua environment (= mission file)
    local miz_id, ok = net.dostring_in("mission", 
			"if db.units_by_ID["..tostring(obj_id).."] ~= nil then return db.units_by_ID["
			..tostring(obj_id).."].unitId else return -1 end")
	if ok then
		return miz_id
	else
		return "-1"
	end
end

--returns the unit's skill from the database/missionfile
function get_unit_skill(unit_id)
	if unit_id == nil then return "unknown" end
	--execute the given string in the Scripts/compile.lua environment (= mission file)
	local skill, ok = net.dostring_in("mission",
			"if db.units[tostring("..unit_id..")] ~= nil then return db.units[tostring("
					.. unit_id .. ")].skill else return 'unknown' end")
	if ok then
		return skill
	else
		return "unknown"
	end
end



------------------------------------------------------------------
-- Functions / Actions
------------------------------------------------------------------

--formats a string with the given number of arguments and reports it locally
report = function(msg, ...)
	net.recv_chat("#" .. string.format(msg, ...))
	if net.is_server() then server.chatlog_write(1, string.format(msg, ...)) end	
end

--sends a server message. If recipient_id is specified then the msg will only be send to that player
function serv_msg(msg, recipient_id)
	local message = "#" .. msg
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

-- formats a string 
function _f(str, ...)
	return string.format(_(str), ...)
end


------------------------------------------------------------------

net.log(server.sm_short..'servman_events.lua loaded')