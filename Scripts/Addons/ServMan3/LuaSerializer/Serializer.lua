-- Copyright (C) 2006, Eagle Dynamics.
-- Serialization module based on the sample from the book
-- "Programming in Lua" by Roberto Ierusalimschy. - Rio de Janeiro, 2003
local base = _G
local Factory = require('Factory')

module('Serializer')
mtab = { __index = _M }

function new(fout)
  return Factory.create(_M, fout)
end

function construct(self, fout)
  self.fout = fout
end

function basicSerialize(self, o)
  if base.type(o) == "number" then
    return o
  elseif base.type(o) == "boolean" then
    return base.tostring(o)
  else -- assume it is a string
    return base.string.format("%q", o)
  end
end

-- Use third argument as a local table for saved table names accumulation
-- to avoid repeated serialization.
-- Данный вариант позволяет сериализовать таблицы с произвольными символьными ключами.
function serialize(self, name, value, saved)
  saved = saved or {}
  self.fout:write(name, " = ")
  if base.type(value) == "number" or base.type(value) == "string" or base.type(value) == "boolean" then
    self.fout:write(self:basicSerialize(value), "\n")
  elseif base.type(value) == "table" then
    if saved[value] then -- value already saved?
      self.fout:write(saved[value], "\n") -- use its previous name
    else
      saved[value] = name -- save name for next time
      self.fout:write("{}\n") -- create a new table
      for k,v in base.pairs(value) do -- serialize its fields
        local fieldname = base.string.format("%s[%s]", name, self:basicSerialize(k))
        self:serialize(fieldname, v, saved)
      end
    end
  else
    base.error("Cannot serialize a "..base.type(value))
  end
end

-- Более наглядная и простая сериализация без экономии повторяющихся таблиц.
-- Предполагается, что символьные ключи в таблицах являются идентификаторами Lua.
function serialize_simple(self, name, value, level)
  if level == nil then level = "" end
  if level ~= "" then level = level.."  " end
  self.fout:write(level, name, " = ")
  if base.type(value) == "number" or base.type(value) == "string" or base.type(value) == "boolean" then
    self.fout:write(self:basicSerialize(value), ",\n")
  elseif base.type(value) == "table" then
      self.fout:write("\n"..level.."{\n") -- create a new table
      for k,v in base.pairs(value) do -- serialize its fields
        local key
        if base.type(k) == "number" then
          key = base.string.format("[%s]", k)
        else
          key = k
        end
        self:serialize_simple(key, v, level.."  ")
      end
      if level == "" then
        self.fout:write(level.."} -- end of "..name.."\n")
      else
        self.fout:write(level.."}, -- end of "..name.."\n")
      end
  else
    base.error("Cannot serialize a "..base.type(value).." name:"..name)
  end
end


-- Helper, tablecount.
-- Sometimes #mytable doesn't return the correct count.
tcount = function(t)
	local i, kk, vv
	i = 0
	if t then
		if base.type(t)=='table' then
			for kk,vv in base.pairs(t) do
				i = i +1
			end
		elseif (base.type(t)=='string' and t~='') or (base.type(t)=='number') then
			i = 1
		end
	end
	return i
end


function serialize_simple2(self, name, value, saved, level, more)
	saved = saved or {}
	local lclprefix = ""
	local basename = ""
	if level == nil then
		-- first recursion
		level = 0
		lclprefix = "local "
		basename = name
	end
	more = more or false
	
	local strlvl, morestr, strcomment,newl
	strcomment = ""
	if level ~= 0 then 
		strlvl = base.string.rep("\t",level)
	else
		strlvl = ""
	end
	local i = 0
	local tmp

	if more then
		morestr=", "
	else
		morestr=""
	end
	self.fout:write(lclprefix, strlvl, name, " = ")

	if base.type(value) == "number" or base.type(value) == "string" or base.type(value) == "boolean" then
		if more then
			self.fout:write(self:basicSerialize(value), ",\n")
		else
			self.fout:write(self:basicSerialize(value))
		end
	elseif base.type(value) == "table" then
		if saved[value] then -- value already saved?
			self.fout:write(saved[value], "n1\n") -- use its previous name
		else
			saved[value] = name -- save name for next time
			self.fout:write("{ \n") -- create a new table
			local vcount = tcount(value)
			local mypairs
			
			for k,v in base.pairs(value) do
				if base.type(k)=='number' then
					mypairs = base.ipairs
					break
				else
					mypairs = base.pairs
					break
				end
			end
			
			if nil~=mypairs then
				for k,v in mypairs(value) do -- serialize its fields
					local key
					i = i + 1

					if i<vcount then
						more=true
					else
						more=false
					end

					if base.type(k) == "number" then
						key = base.string.format("[%s]", k)
					else
						key = base.string.format("%s", k)
					end
					self:serialize_simple2(key, v, saved, level+1, more)
				end
			end
			strcomment = "\n"..strlvl.."}"
		end
		if morestr~="" and strcomment~="" then newl="\n" else newl="" end
		self.fout:write(strcomment,morestr,newl)

	else
		base.error("Cannot serialize a "..base.type(value))
	end
	if lclprefix~="" then
		self.fout:write("\nreturn { ", basename," }")
	end
	return
end

-- serialization to string

local serialize_to_string_result

function add_to_string(str)
  serialize_to_string_result = serialize_to_string_result..str    
end --

function serialize_to_string(self, name, value)
  serialize_to_string_result = ""
  self:serialize_to_string_simple(name, value)
  return serialize_to_string_result
end -- func                              

function serialize_to_string_simple(self, name, value,level)
    local level   =  level or ""
    add_to_string(level..name.."=")
    if  base.type(value) == "number" or 
        base.type(value) == "string" or 
        base.type(value) == "boolean" then
        add_to_string(self:basicSerialize(value) .. ",\n")
    elseif base.type(value) == "table" then
        add_to_string("\n"..level.."{\n")
        for k,v in base.pairs(value) do -- serialize its fields
            local key
            if base.type(k) == "number" then          key = base.string.format("[%s]"  , k)
            else                                      key = base.string.format("[%q]", k)         end
            self:serialize_to_string_simple(key,v,level.."\t")
        end
        if level == "" then   add_to_string(level.."}\n")
        else                  add_to_string(level.."},\n") end
    else   
        base.error("Cannot serialize a "..base.type(value))
    end
end -- func

function serialize_to_string_noCR(self, name, value)
  serialize_to_string_result = ""
  self:serialize_to_string_simple_noCR(name, value)
  -- delete last ","
  return base.string.sub(serialize_to_string_result,1,base.string.len(serialize_to_string_result)-1)
end -- func                              

function serialize_to_string_simple_noCR(self, name, value)
  add_to_string(name.."=")
  if base.type(value) == "number" or base.type(value) == "string" or base.type(value) == "boolean" then
      add_to_string(self:basicSerialize(value) .. ",")
  elseif base.type(value) == "table" then
      add_to_string("{")
      for k,v in base.pairs(value) do -- serialize its fields
        local key
        if base.type(k) == "number" then
          key = base.string.format("[%s]", k)
        else
          key = base.string.format("['%s']", k)
        end
        self:serialize_to_string_simple_noCR(key, v)
      end
      add_to_string("},")
  else
      base.error("Cannot serialize a "..base.type(value))
  end
end -- func
