
-- Table of settings that can change during runtime / server uptime
-- by using the /SET command. These settings are "type-safe", so any invalid settings/syntax
-- will be discarded. For more help on these, contact the authors. A bottle of Jägermeister is required for more secrets. :D
-- Note, only support for on/off modes.
-- Numbers and values may supported later.
local dynamicsettings = {
		kicks 			= { on = 'server.conf.bankick_enabled=true',			off = 'server.conf.bankick_enabled=false' },
		restart			= { on = 'server.conf.restart_if_server_empty=true',	off = 'server.conf.restart_if_server_empty=false' },
		pause			= { on = 'server.conf.pause_if_server_empty=true',		off = 'server.conf.pause_if_server_empty=false' },
		resume			= { on = 'server.conf.resume_if_server_not_empty=true',	off = 'server.conf.resume_if_server_not_empty=false' },
		votekick		= { on = 'server.conf.bankick_vote=true',				off = 'server.conf.bankick_vote=false' },
		votemission		= { on = 'server.conf.missionvotes=true',				off = 'server.conf.missionvotes=false' },
		banbyname 		= { on = 'server.conf.bankick_byname=true',				off = 'server.conf.bankick_byname=false' },
		banbyip			= { on = 'server.conf.bankick_byip=true',				off = 'server.conf.bankick_byip=false' },
		banbyucid 		= { on = 'server.conf.bankick_byucid=true',				off = 'server.conf.bankick_byucid=false' }
	}
	
return { dynamicsettings }