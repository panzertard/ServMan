
-- permission level table, for better visualization of the levels when others want to edit it.
local permlevel = {
	anon = 0, -- anyone connecting for the first time.
	friend = 1, -- It's not in use yet. Implemented for later use.
	squad = 2, -- squad login puts you at this level
	admin = 3, -- another admin login puts you here. If you disable squad logins, you log directly in to this level.
	superadm = 4 -- intended to be the local server only, not fully implmented as that quite yet.
	}

local cmdprf = '/' -- prefix for servercommands in the chat. Can be changed to another character.

-- main commands, you can tweak permissions or help categories.
-- You CANNOT change the content of a "cmd='nnnnn'", it will break the internal commands.
-- You can change the PERM levels or category keywords.
local maincmd = {
	l 		= { cmd = "load", 		perm = permlevel.squad,		cat = "mission" },
	m 		= { cmd = "missions",	perm = permlevel.anon,		cat = "mission" },
	log		= { cmd = "login",		perm = permlevel.anon,		cat = "player,admin" },
	logo 	= { cmd = "logout",		perm = permlevel.anon,		cat = "player" },
	v 		= { cmd = "vote",		perm = permlevel.anon,		cat = "vote,player,mission" },
	pl 		= { cmd = "players",	perm = permlevel.anon,		cat = "info,player" },
	i 		= { cmd = "info",		perm = permlevel.anon,		cat = "info" },
	yes		= { cmd = "yes",		perm = permlevel.anon,		cat = "vote" },
	no		= { cmd = "no",			perm = permlevel.anon,		cat = "vote" },
	t		= { cmd = "timeleft",	perm = permlevel.anon,		cat = "info" },
	times	= { cmd = "timeset",	perm = permlevel.squad,		cat = "mission,server" },
	r 		= { cmd = "rules",		perm = permlevel.anon,		cat = "info" },
	re		= { cmd = "resume",		perm = permlevel.anon,		cat = "server" },
	rei		= { cmd = "reinit",		perm = permlevel.admin,		cat = "server,admin" },
	rep		= { cmd = "report",		perm = permlevel.anon,		cat = "player" },
	rec		= { cmd = "recompile",	perm = permlevel.admin,		cat = "server" },
	rest	= { cmd = "restart",	perm = permlevel.squad,		cat = "mission" },
	h		= { cmd = "help",		perm = permlevel.anon,		cat = "info" },
	stop	= { cmd = "stopvotes",	perm = permlevel.squad,		cat = "admin" },
	k 		= { cmd = "kick", 		perm = permlevel.squad,		cat = "player,admin" },
	b	 	= { cmd = "ban", 		perm = permlevel.admin,		cat = "player,admin" },
	banl 	= { cmd = "banlist", 	perm = permlevel.admin,		cat = "admin" },
	wh	 	= { cmd = "whoami", 	perm = permlevel.anon,		cat = "player" },
	pa 		= { cmd = "pause",		perm = permlevel.squad,		cat = "server" },
	un 		= { cmd = "unlock",		perm = permlevel.squad,		cat = "server" },
	save	= { cmd = "save",		perm = permlevel.admin,		cat = "server" },	
	conf	= { cmd = "config",		perm = permlevel.admin,		cat = "config" },	
	set		= { cmd = "set",		perm = permlevel.admin,		cat = "server" },
	lock 	= { cmd = "lock",		perm = permlevel.squad,		cat = "server" },
	ver 	= { cmd = "version",	perm = permlevel.anon,		cat = "info" }
}

-- help, adjust the text if you like.
local mainhelp = {
	l 		= { options = "{ <mission-id> | conf }",
					short = "Loads a mission or config, use '"..cmdprf.."missions to view mission-id's.",
					more = { "To see which mission that is active, use the '"..cmdprf.."mission command, and look for the --><-- around the mission number.", 
							"To load the custom config, use the keyword 'conf'." }
				},
	m 		= { options = "",
					short = "List missions available",
					more = "Notice the active mission got -><- around the number"
				},
	log	 	= { options = "{'password'} | { 'username' 'password' }",
					short = "Login to the server as subadmin or squadaccess",
					more = { "SQUAD: Note the SQUAD access login MAY require a username + password",
							"   Check with your CO or Server Admin for more info.",
							"ADMINS: When SQUAD-access is enabled, you MUST first log into SQUAD before",
							"   you proceed with regular subadmin login with *your* password. (no username).",
							"   When SQUAD mode is disabled, you login with *your* password only, just like before." }
				},
	logo 	= { options = "",
					short = "Log out from subadmin.",
					more = "" },
	v 		= { options = "{ k <id> | k 'namefilter' | m <id> | m }",
					short = "Vote Kick player, new Mission Id, Mission-poll or Endmission",
					more = {	"Notice that the '"..cmdprf.."v m' (no id) starts a missionpoll instead of a mission-vote.",
								"Users should respond to this with /v <id> where <id> is a number",
								"Examples :", 
								"  "..cmdprf.."v k 3 = vote a kick for player with ID 3",
								"  "..cmdprf.."vote k Panzer = vote a kick for players with 'panzer' in their names",
								"  "..cmdprf.."v m 4 = vote a new mission, mission id 4",
								"  "..cmdprf.."v m = poll, where users must respond with "..cmdprf.."v <idnumber>",
								"  "..cmdprf.."v 3 = answer to a Mission-poll, where user votes for mission #3"
					}
				},
	pl 		= { options = "['namefilter']",
					short = "List players, or players using the namefilter",
					more = "Example: '"..cmdprf.."player 666th' = will list only players with '666th' in their name" },
	i 		= { options = "",
					short = "Server settings information",
					more = "A brief overview over the settings being used by the server" },
	yes		= { options = "",
					short = "A reply that is only valid during a vote",
					more = "You will agree with the voter in the current vote" },
	no		= { options = "",
					short = "A reply that is only valid during a vote",
					more = "You will disagree with the voter in the current vote" },
	t		= { options = "",
					short = "Displays how much time left to next mission/restart",
					more = {	"The time left may vary depending on the settings used by the server",
								"See '"..cmdprf.."timeset' for more info on how to set the timeleft for this round." }
					},
	times	= { options = "<minutes>",
					short = "Sets time remaining before next restart/mission rotation.",
					more = {	"You can use this to add more time to the current round. It wont save the time to the DEFAULT config.",
								"However it will be saved in the CUSTOM conf if you choose to save this.",
								"If you need to increase the mission timer permanently you should edit the conf_serverconfig.lua" }
					},
	r 		= { options = "",
					short = "Displays the server rules for anyone to see. Obey them or you may get removed from the server.",
					more = "The server rules for conduct are set by the server admins." },
	re		= { options = "",
					short = "Resumes the server if it is paused",
					more = "The server may be paused during startup, all users can resume a server." },
	rei		= { options = "",
					short = "Reload all the default conf_nnnnn.lua files",
					more = "May also reset mission-timers and TK/FF info if this is set in the config." },
	rep		= { options = "'your message here'",
					short = "Make a REPORT in the Server chatlogs for the Admins.",
					more = "You may have to notify a admin that you sent in a report if they forget to check the logs." },
	rec		= { options = "",
					short = "Recompile Servman Script",
					more = "Abuse this and your server will die a painful death." },
	rest	= { options = "",
					short = "force a mission restart",
					more = "Mission restart will also reset the mission-timer." },
	h		= { options = "['category filter']",
					short = "Online help. Remember to try the "..cmdprf.."command ? per command",
					more = {	"Command syntax help - meaning of the:",
								"[] means optional, {}means required, | means OR" ,
								"<nn> means number-value without arrows, 'texthere' means text-value without quotes",
								"*** How to read the help syntax ***",
								"For example: "..cmdprf.."kick {<n>| 'name' } means you should use '"..cmdprf.."kick 3' or '"..cmdprf.."kick panzertard', but you cannot just use '"..cmdprf.."kick' with no more parameters",
								"For example:",
								"  "..cmdprf.."v[ote] { m <id> | k <id> | k 'name' } means you can use '"..cmdprf.."v' or '"..cmdprf.."vot' (everything in the [] is optional", 
								"  for the command, and either 'm' or 'k' is required for the next word, as well as 'm' only accepts ID as a number.",
								"  With 'k' you can choose to use either a number (ex: '"..cmdprf.."vote k 3') or a name (Ex: '"..cmdprf.."vote k panzertard')",
								"  And you cannot use the "..cmdprf.."vote command alone without any input" }
					},
	stop	= { options = "",
					short = "Stop all votes in progress",
					more = "All votes will be stopped, missionvotes/polls, kickvotes or endmission" },
	k 		= { options = "{ <id> | 'namefilter' }",
					short = "Kick a player by ID or parts of his name.",
					more = { "The kick-command supports up to 3 simultanious kicks.",
							"The namefilter is a include filter, so for example:",
							"   "..cmdprf.."k 104th panzer me",
							"   will kick all people with '104th', 'panzer' as part of their name as well as",
							"   anyone with 'me' as part of the name. It *can* empty your server, so be careful!",
							"*** Note: You CAN NOT mix names and numbers kick methods." }
				},
	b		= { options = "{ <id> | 'namefilter' } ['reason'] ",
					short = "Ban+kick a player by ID or parts of his name.",
					more = { "The Bankick-command ONLY 1 ban per command - any text after this is considered as a comment.",
							"The namefilter is a include filter, so for example:",
							"   "..cmdprf.."ban 666th weapon hax0rs",
							"   will bankick all people with '666th' as part of their name as well as",
							"   adding the comment 'weapon haxors'. Always add a comment for your CO/Admin to read.",
							"   To lift a ban you must use the '"..cmdprf.."banlist r filter' command",
							"*** Note: You can quickly empty your server if not used with caution!" }
				},
	banl	= { options = "[r] { <id> | 'namefilter' | 'ipfilter' }",
					short = "Display Bans by IP, ID or parts of his name, optionally remove a ban from the list",
					more = { "The Banlist will manage the server bans.",
							"The IP- or name-filter is a include filter, so for example:",
							"   "..cmdprf.."banli panzer",
							"   will list all people with 'panzer' as part of their name.",
							"   The same goes for IP, so for example "..cmdprf.."banlist 192. will list all bans",
							"   containing that IP-octet and dot. ",
							"   To lift a ban you must use the "..cmdprf.."banlist r <option>",
							"*** Note: If you use just numbers, it will assume you're trying to use an ID." }
				},				
	pa 		= { options = "",
					short = "Pauses the mission",
					more = "To take a break and leave everyone hanging, pause is a good method." },
	wh 		= { options = "",
					short = "Info about yourself",
					more = { "You're confused, you're not sure who you are. You take a close look",
							"in the mirror and you notice a torn scarred face. This is me? Why!?" }
				},
	ver 		= { options = "",
					short = "Version info",
					more = { "Just what it says" }
				},				
	un 		= { options = "",
					short = "Unlocks the server from a lockdown",
					more = "When the server is locked, new players cannot join. Use '"..cmdprf.."unlock' to open it again." },
	lock 	= { options = "",
					short = "Locks the server, preventing new players from joining.",
					more = "When the server is locked, new players cannot join. Use '"..cmdprf.."unlock' to open it again." },
	set 	= { options = "'setting'=on|off",
					short = "Adjust a server-config setting without restart",
					more = {	"Examples: ",
								"   '"..cmdprf.."set kicks=off' to disable kicks/bans while server is running",
								"   '"..cmdprf.."set votekick=off' to enable votekick for this session if disabled in Config",
								"Other settings to turn on/off:",
								"    kicks, restart, pause, resume, votekick, votemission, banbyname, banbyip, banbyucid",
								"See 'conf_dynsettings.lua' for full config of which settings that are available." }
				},
	conf 		= { options = "[ load <n> | load <part-of-name> | save <name> ] ",
					short = "List, load or save a serverconfig, use '"..cmdprf.."conf load myConfig' to load a config.",
					more = { "To see which config that is active, use the '"..cmdprf.."conf', and look for the --><-- around the mission number.", 
							"	To load a custom config, use the keyword 'load' and part of a name, or a Config-number.",
							"	To save the current config, use the keyword 'save' and add a name after it.",
							"	Note: All saved files are put in the '\Saves Games\DCS Warthog\ServMan' folder",
							"Examples: ",
								"   '"..cmdprf.."load Public' to load your file called Public profile, with filename CONF_Public.lua",
								"   '"..cmdprf.."load pub' to load the first configfile it finds which contain 'pub' in the name",
								"   '"..cmdprf.."save Squadnite' to save the current config into a profile called Squadnite, with the filename CONF_Squadnite.lua"
							}
				},				
	save	= { options = "{ conf }",
					short = "Save the current server config to a custom configuration-file.",
					more = { "To save the custom config, use the keyword 'conf'." }
				}
}


return { cmdprf, permlevel, maincmd, mainhelp }

