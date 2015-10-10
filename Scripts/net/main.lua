gettext = require("i_18n")
io = require("io")
lfs = require("lfs")
if not lfs.writedir then lfs.writedir = function() return "./" end end

log = log or function(str) print(str) end
-- loaded once on start

local scripts_dir = "./Scripts/net/"
local temp_dir = lfs.writedir() .. "Temp/"
local config_dir = lfs.writedir() .. "Config/"
local config_file = config_dir .. "network.cfg"

package.path = scripts_dir..'?.lua;'..package.path

server = require('server')
client = require('client')

-- load config file
local function merge(dest, src)
    local k,v
	for k,v in pairs(src) do
		local d = dest[k]
		if k == "integrity_check" then
			dest[k] = v
		elseif type(v)=="table" and type(d)=="table" and v[1] == nil then
			merge(d, v)
		else
			dest[k] = v
		end
	end
end

local function load_env(filename, env)
	local file, err = loadfile(filename)
	local res = false
	if file then
		if env then setfenv(file, env) end
		res, err = pcall(file)
	end
	local msg
	if res then msg = "OK" else msg = err end
	log("loading "..filename.." : "..msg)
	return res, err
end

-- load config
config = {}
load_env("./Scripts/net/default.cfg", config)
local new_config = {}
if load_env(config_file, new_config) then
    merge(config, new_config)
end

-- bind config
server.config = config.server
client.config = config.client

-- sort connection types and put ordered names in connection_types
connection_types = {}

local function conn_cmp(a, b)
    return a[2] < b[2]
end

local ok
ok, connection_types = load_env(scripts_dir..'net_types.lua')
if ok then 
	table.sort(connection_types, conn_cmp)
else
	connection_types = {}
end

function set_connection_type(idx)
	if idx < 1 then return end
	local t = connection_types[idx]
	if type(t)=="table" then config.connection = t end
end

function get_connection_speed()
	return config.connection[2], config.connection[3]
end


dofile(scripts_dir..'save.lua')
--dofile(scripts_dir..'cleanup.lua')
function cleanup_temp(temp_dir) end

-- clean temp files on start
cleanup_temp(temp_dir)

-- called on exit
function on_exit()
	if not config.do_not_save then
	local cfg
        if lfs.attributes(config_dir, "mode") ~= "directory" and not lfs.mkdir(config_dir) then
		cfg = nil
	else
		cfg = io.open(config_file, "w")
        end
	if cfg then
		save(function(str) cfg:write(str) end, config)
		cfg:close()
	else
		log("can't write to "..config_file)
	end
	else
		log("skipped config saving.")
	end

	-- clean temp files on exit as well
	cleanup_temp(temp_dir)
end

--- TEST
--[[
function test_exec(state, str)
	local val, res = net.dostring_in(state, "return " .. str)
	net.log(string.format("%s: (%s) %q", state, tostring(res), val))
end

test_exec("export", "LoGetModelTime()")
test_exec("config", "cmdline")
]]



function loadaddon(filename, newenv)
	local addn = string.upper(string.gsub(filename, "/[%w_.-]*", ": "))
	net.log(addn.."Check to see if Addon is Available: "..filename)
	local chunk, err1 = loadfile("Scripts/Addons/"..filename) -- loads and compiles the chunk
	if chunk then
		net.log(addn.."Addon loaded: "..filename)
		if newenv then
			net.log(addn.."Setting Addon Environment")
			setfenv(chunk, newenv)	
		end
		net.log(addn.."Checking the Addon in a protected environment")
		local chunkref, err2 = assert(pcall(chunk))
		if not err2 then
			return chunkref, nil
		else
			net.log(addn.."Protected call failed with error: "..tostring(err2))
			return nil, nil
		end
	else
		err1 = "ADDON SKIPPED: Couldn't be loaded: "..tostring(err1)
		net.log(addn..err1)
		return nil, err1
	end
end

scriptenv = {}
mainserverenv = getfenv(0)
merge(scriptenv, mainserverenv)
local addonref = loadaddon("ServMan3/servman_server.lua",scriptenv)
mainserverenv = nil
scriptenv.mainserverenv = nil

----------------------
log('Script-Net-main.lua loaded')
----------------------
