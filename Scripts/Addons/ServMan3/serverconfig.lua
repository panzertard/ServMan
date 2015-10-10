------------------------------------------------------------------
-- SERVMAN SERVER MANAGEMENT MOD
-- FILE: serverconfig.lua
-- VERSION: 3.1
-- AUTHORS: Acedy, Panzertard, =RvE=Yoda, Grimes
------------------------------------------------------------------

------------------------------------------------------------------
-- Table with server configuration variables
------------------------------------------------------------------

local config = 
{
	-- NOTE --- SORRY TRANSLATION IS NOT COMPLETE --- WILL NOT WORK AS EXPECTED ---
	-- NOTE --- SORRY TRANSLATION IS NOT COMPLETE --- WILL NOT WORK AS EXPECTED ---
	--Determines the language of server messages. Default is English "en". A table with translated strings has to
	--be added to file "translations.lua". Other languages available: German ("de").
	-- NOTE --- SORRY TRANSLATION IS NOT COMPLETE --- WILL NOT WORK AS EXPECTED ---
	-- NOTE --- SORRY TRANSLATION IS NOT COMPLETE --- WILL NOT WORK AS EXPECTED ---
	language					= "en",

	--If true players are allowed to initiate a vote or poll to load missions. Set to false to disable.
	missionvotes				= true,
	
	--Time in seconds after which an ongoing vote/poll will be closed and evaluated.
	vote_timeout				= 60,
	
	--Minimum amount of votes (in percent of all players) needed for a valid vote/poll. If the percentage of votes
	--is lower than this value, the result will be discarded. Value must be between 0 and 100.
	min_votes_in_percent		= 50,
	
	--Time after starting a vote that a player cannot initiate another vote of the same kind
	--(i.e. votekick or missionvote/-poll). In minutes. Must be >= 0. Default is 5 minutes.
	time_between_votes			= 1,
	
	--Time in minutes after which the current mission restarts automatically.
	--Mission rotation needs to be disabled. Set to 0 to disable.
	restart_miz_after			= 360,
	
	--Time in minutes after which the next mission in the Missions/Multiplayer folder will be loaded (automatic
	--mission rotation). Set to 0 to disable. If mission resarting is enabled as well, then rotating has priority.
	rotate_miz_after			= 0,

	-- NEW: will allow a mission rotate/restart announcement to appear. 3 examples below:
	-- NOTE: Order must be incremental, smallest numbers first.
	-- miz_rotate_announcement = { 1,2,3,4,5,10,15,60,120,180 },   -- at 3 hours, 2 hours, 1 hour, 15 mins, 10 mins, and every min from 5 to 1 min
	-- miz_rotate_announcement = { 1,5,10,15,60 },					-- at 1 hour, 15 mins, 10 mins, 5 min and final call at 1 min.
	--miz_rotate_announcement = { 0 }, 							-- disabled
	miz_rotate_announcement = { 1,2,3,4,5,10,15,60 },
	
	--If true the current mission will be paused once all players left the server. Set to false to disable.
	pause_if_server_empty		= false,
	
	--If true the current mission will be unpaused when a new player enters an empty server. A mission will also be
	--resumed ~1min after loading if the server is not empty. Set to false to disable.
	resume_if_server_not_empty	= true,

	--If true the server automatically restarts the current mission when all players left the server.
	--Set to false to disable.
	restart_if_server_empty		= false,
	
	--Number of human teamkills after which a player will be kicked automatically. Set to 0 to disable.
	kick_after_teamkills		= 1,
	
	--Number of AI teamkills incidents after which a player will be kicked automatically. Set to 0 to disable.
	kick_after_AI_teamkills		= 2,
	
	--Number of friendly fire (damaging human teammates) incidents after which a player will be kicked automatically. Set to 0 to disable.
	kick_after_friendly_fire 	= 1,
	
	--Minimum time in seconds after which a 2nd friendly fire event of one player against the same teammate will logged/reported.
	--Set to 0 to log/report all friendly fire incidents (this may cause message spamming). Default is 3.
	friendly_fire_interval		= 2,

	--Minimum time in seconds between collisions of two teammates that will be logged/reported. Set to 0 to disable collision logging/reporting. 
	collision_interval			= 5,
	
	--If true the stat counters (for human and AI teamkills, friendly fire events, team collisions and ping warnings) of all players will be reset 
	--to zero on each new mission start. If disabled these player stats will accumulate over all missions. Set to false to disable.
	reset_TK_stats_on_miz		= false,
	
	--Score below which the player will be kicked automatically. Must be negative. Set to 0 to disable.
	--Can be used together with "kick_after_teamkills" and/or "kick_after_AI_teamkills" and/or "kick_after_friendly_fire".
	kick_below_score			= 0,
	
	--Number of high average ping warnings after which a player will be kicked.
	--Set to 0 to disable ping logging and kicking for high ping.
	kick_after_max_ping_events	= 3,
	
	--Maximum average ping. Average is calculated over the last 100 ping values, and only for non-spectating players (excluding subadmins).
	--Must be positive, default is 500. Option is only relevant when kick_after_max_ping_events > 0.
	max_average_ping			= 500,
	
	--Penalty time in minutes that a player cannot reconnect after being kicked. Set to 0 to disable.
	wait_after_kick				= 60,
	
	--Number of kicks after which a player will be banned automatically.
	--The player's IP will be added to local banlist. Set to 0 to disable.
	autoban_after_kicks			= 2,
	
	--URL of masterbanlist. Set to "" to disable. URL format: "[http://][<user>[:<password>]@]<host>[:<port>][/<path>]"
	--Ex.1: "http://BartS:AyCaramba@www.abc-xyz.net/def/banlist.txt" (if authorization via .htaccess is required)
	--Ex.2: "http://www.abc-xyz.net/def/banlist.txt" (if no authorization is required)
	masterbanlist_URL			= "",
	
	-- bankick_vote:	If true players are allowed to initiate a vote to kick another player. Set to false to disable.
	-- "bankick_by__":	Allows for more flexible control over which filters that will be used for bankicks on player connect.
	-- 					Note the UCID is the new UserID hash calculated from each Players Unique SF key.
	-- 					The key is also unique per product, DCS:BS vs FC2.
	-- bankick_enabled:	Enables or disables all automated ban/kick functions *including* voting, on player-connect, automated (TK/AI) but
	--					NEVER manual adminstrative kicks.
	bankick_vote					= true,
	bankick_byname					= true,
	bankick_byip					= true,
	bankick_byucid					= true,
	bankick_enabled					= true,
	
	--Message of the Day. Use * to indicate line breaks. Set to "" to disable.
	MOTD						= "*Welcome to the 159th DCS World server.*Type /help into chat to see enabled server commands*You can restart or change Missions!*159th TSv3: 78.129.193.145:10119 pw=jacksparrow",
	
	--Time interval in minutes between displaying the message of the day. MOTD will also be shown 2 mins after a new player
	--connected. If MOTD is disabled, only the time remaining until mission rotation/restart is displayed (if enabled)
	MOTD_interval				= 15,
	
	--Server rules as shown by /rules command. Use * to indicate line breaks.
	server_rules				= "1. No teamkilling*2. Do not damage teammates*3. No bad language*4. Treat each other with respect*5.  Enjoy!",

	--Interval of frames after which ServMan checks if scheduled events should be triggered
	--Lower values may (or may not) decrease server performance, higher values may delay scheduled events.
	timer_interval				= 100,
	
	--If true all chat (except server messages) and player reports sent via "/report" will be logged in the Temp/ServMan-Chatlog-<timestamp>.log file.
	--Set to false to disable. Cannot be changed at runtime.
	log_chat					= true,

	-- Level of details appearing the Temp/ServMan-Serverlog-<timestamp>, mostly usefull when debugging. 
	-- Value must be number, 0 = off, 1 = normal, 2 = more, 3 = massive.
	loglevel					= 1,
	
	--If true subadmins are allowed to reload the server configuration using the /init command.
	--Set to false to disable. Server can always use this command.
	reinit_by_admin				= true,
	
	-- Squadron Login.
	-- Set the 'squad_login_enable=false' to disable the whole function.
	-- Squad members will get some more functions over regular users, but the 
    -- full ADMIN functions may still be disabled until he logs in as a FULL ADMIN.
	-- see "/help", "/help server", "/help admin" for more info.
	-- *** NOTE SECURITY: If you set Suffix & Prefix to "" (blank) then ANYONE can login 
	--     with squad access.
	-- *** RELATED: Anyone can IMPERSONATE a Squad member by observing your names.

	-- Minimalistic security example:
	--   - No prefix / suffix
	--   - No Username
	--   - Password only
	-- Low to Medium security example
	--   - Prefix = ""
	--   - Suffix = ""
	--   - Username = "champs"
	--   - Password = "win!"
	-- High security example
	--   - Prefix = "666th"
	--   - Suffix = "_sqd"
	--   - username = "Champions"
	--   - Password = "IneverCrash!"

	squad_login_enable			= true,
	squad_prefix				= "",
	squad_suffix				= "",
	squad_username				= "",
	squad_password				= "",

	-- Decides which level to kick, anon users only or even squad member.
	-- Even admins kan be kicked. But not the server itself - it is superadm.
	-- Levels are:
		-- anon = 0,
		-- friend = 1,
		-- squad = 2,
		-- admin = 3,
		-- superadm = 4
	-- If you set kickbanlevel = 2, then everyone including squad-members can 
	-- be kicked/banned for offences. Admins cannot be kicked banned at 
	-- level 2, in that case you should set kickbanlevel = 3
	kickbanlevel		= 2,
	
	missionfolder		= lfs.writedir() .. '\Missions', -- not tested yet with DCS 1.5

	kick_on_phrase 		= true,
	-- added by Grimes in version 3.1.1
	-- Searches DB of words. if a chat message features one of the words the player will be kicked.
	--
}
}


------------------------------------------------------------------
-- Table of sub-administrator names and passwords
-- Names/passwords cannot contain the following characters: " \ %
------------------------------------------------------------------
--[[

Format/Example:
-- Please pay attention to the commas at the end of the line, it is required.
local subadmins=
{
	["BartS"] = "Ay!Caramba12",
	["Homer"] = "doh!!",
	["name"] = "password"
}
]]
local subadmins=
{
	
}

------------------------------------------------------------------
-- Table of banned IP ranges
------------------------------------------------------------------
--[[
Format/Example:
local banned_IP_ranges =
{
	{ from = "123.34.61.1", to = "123.34.61.255" },
	{ from = "67.113.0.1", to = "67.113.255.255" }
}
]]

local banned_IP_ranges =
{
	
}


------------------------------------------------------------------
-- Table of banned names
------------------------------------------------------------------
--[[
Format/Example:
local banned_names =
{
	["unknown"] = true,
	["Ho Chi Minh"] = true
}
]]
local banned_names =
{
	["unknown"] = true
}
-- kick phrases seperated by commas. Note that the script automatically filters out a number of characters due to the string.find() function not liking it. Function also makes all text lower case.
-- {'-', '(', ')', '_', '[', ']', '.', '#', ' ', '{', '}', '$', '%', '?', '+', '^'}
local kick_phrase = 
{
	'curseword',
}
return { config, subadmins, banned_IP_ranges, banned_names, kick_phrase}