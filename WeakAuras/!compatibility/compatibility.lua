--[[
	UnitAlternatePowerInfo
	UnitAlternatePowerTextureInfo
	GetRealEclipseDirection
--]]
function wipe(t)
	if type(t) ~= "table" then
		error(("bad argument #1 to 'wipe' (table expected, got %s)"):format(t and type(t) or "no value"), 2)
	end
	for k in pairs(t) do
		t[k] = nil
	end
  return t
end
table.wipe = wipe

-----------
-- print --
-----------
do
	local LOCAL_ToStringAllTemp = {};
	function tostringall(...)
    local n = select('#', ...);
    -- Simple versions for common argument counts
    if (n == 1) then
			return tostring(...);
			elseif (n == 2) then
			local a, b = ...;
			return tostring(a), tostring(b);
			elseif (n == 3) then
			local a, b, c = ...;
			return tostring(a), tostring(b), tostring(c);
			elseif (n == 0) then
			return;
		end
		
    local needfix;
    for i = 1, n do
			local v = select(i, ...);
			if (type(v) ~= "string") then
				needfix = i;
				break;
			end
		end
    if (not needfix) then return ...; end
		
    wipe(LOCAL_ToStringAllTemp);
    for i = 1, needfix - 1 do
			LOCAL_ToStringAllTemp[i] = select(i, ...);
		end
    for i = needfix, n do
			LOCAL_ToStringAllTemp[i] = tostring(select(i, ...));
		end
    return unpack(LOCAL_ToStringAllTemp);
	end
	
	local LOCAL_PrintHandler =
	function(...)
		DEFAULT_CHAT_FRAME:AddMessage(strjoin(" ", tostringall(...)));
	end
	
	function setprinthandler(func)
    if (type(func) ~= "function") then
			error("Invalid print handler");
			else
			LOCAL_PrintHandler = func;
		end
	end
	
	function getprinthandler() return LOCAL_PrintHandler; end
	
	local geterrorhandler = geterrorhandler;
	local forceinsecure = forceinsecure;
	local pcall = pcall;
	local securecall = securecall;
	
	local function print_inner(...)
    --forceinsecure();
    local ok, err = pcall(LOCAL_PrintHandler, ...);
    if (not ok) then
			local func = geterrorhandler();
			func(err);
		end
	end
	
	function print(...)
    securecall(pcall, print_inner, ...);
	end
	SlashCmdList["PRINT"] = print
	SLASH_PRINT1 = "/print"
end

-- The main issue with UnitAura explained:
-- It does not exist in TBC and therefore we have to write it ourselves.
-- Bufftrigger2 expects a spellId from the function, but we don't really know which one is correct.
-- There is no function that yields the spellId for a spellname.
-- The way it is implemented now is that always the highest spellId for a spellname is returned.
-- Also note that UnitBuff does not return isStealable, unlucky
local spellIdCache = {}
local spellIdCacheId = 0
local spellIdCacheMisses = 0
while spellIdCacheMisses < 53000 do
	spellIdCacheId = spellIdCacheId + 1
	local name, _, icon = GetSpellInfo(spellIdCacheId)

	if(icon == 136243) then -- 136243 is the a gear icon, we can ignore those spells
		spellIdCacheMisses = 0;
	elseif name and name ~= "" then
		spellIdCache[name] = spellIdCacheId
		spellIdCacheMisses = 0
	else
		spellIdCacheMisses = spellIdCacheMisses + 1
	end
end

-- UnitAura now parses the spellId from the spellLink, spellIdCache not used atm
function UnitAura(unit, indexOrName, rank, filter)
	--[[
	local aura_index, aura_name, aura_type
	if type(indexOrName) ~= "number" then
		aura_name = indexOrName
	else
		aura_index = indexOrName
	end
	if not filter and rank then
		if type(rank) ~= "number" and rank:find("[HELPFUL,HARMFUL,PLAYER,RAID,CANCELABLE,NOT_CANCELABLE]") then
			filter = rank
			rank = nil
		else
			filter = "HELPFUL" -- default value https://wowwiki.fandom.com/wiki/API_UnitAura
		end
	end
	
	if aura_name then
		local i = 1
    while true do
      name, r, icon, count, duration, expirationTime = UnitBuff(unit, i, filter)
			
			i = i + 1
		end
	end
	--]]
	
	local debuffType
	if ((filter and filter:find("HARMFUL")) or ((rank and rank:find("HARMFUL")) and filter == nil)) then
		debuffType = "HARMFUL";
	elseif ((filter and filter:find("HELPFUL")) or ((rank and rank:find("HARMFUL")) and filter == nil)) then
		debuffType = "HELPFUL";
	else
		debuffType = nil;
	end
  
	local x;
	if(type(indexOrName) == "number") then
		x = indexOrName
	else
		x = 1
	end
	
	if (debuffType == "HELPFUL" or debuffType == nil) then
		local castable = filter and filter:find("PLAYER") and 1 or nil;
		local name, r, icon, count, duration, remaining = UnitBuff(unit, x, castable);
		while (name ~= nil) do
			if ((name == indexOrName or x == indexOrName) and (rank == nil or rank:find("HARMFUL") or rank:find("HELPFUL") or rank == r)) then
				-- Due to a Blizzard bug, having two of the same weapon
				-- proc will return nil for the duration of the second proc.
				-- Crusader (Holy Strength), Mongoose (Lightning Speed),
				-- and Executioner all last 15 seconds.
				duration = duration or 15
				remaining = remaining or GetPlayerBuffTimeLeft(x)
				local spellLink = GetSpellLink(name, r or "")
				local caster = (castable and remaining and remaining > 0) and "player" or nil
				local isStealable = debuffType == "Magic" and 1 or nil
				if spellLink then
					return name, r, icon, count, debuffType, duration, GetTime() + (remaining or 0), caster,  isStealable, nil, tonumber(spellLink:match("spell:(%d+)"))
				else
					return name, r, icon, count, debuffType, duration, GetTime() + (remaining or 0), caster, isStealable, nil, spellIdCache[name]
				end
			end
			x = x + 1;
			name, r, icon, count, duration, remaining = UnitBuff(unit, x, castable);
		end
	end
	
	if (debuffType == "HARMFUL" or debuffType == nil) then
		local removable = nil
		if(type(indexOrName) == "number") then
			x = indexOrName
		else
			x = 1
		end
		local name, r, icon, count, dispelType, duration, expirationTime = UnitDebuff(unit, x, removable);
		while (name ~= nil) do
			if ((name == indexOrName or x == indexOrName) and (rank == nil or rank:find("HARMFUL") or rank:find("HELPFUL") or rank == r)) then
				local spellLink = GetSpellLink(name, r or "")
				local caster = (expirationTime and expirationTime > 0) and "player" or nil
				local isStealable = dispelType == "Magic" and 1 or nil
				if spellLink then
					return name, r, icon, count, dispelType, duration, GetTime() + (expirationTime or 0), caster, isStealable, nil, tonumber(spellLink:match("spell:(%d+)"))
				else
					return name, r, icon, count, dispelType, duration, GetTime() + (expirationTime or 0), caster, isStealable, nil, spellIdCache[name]
				end
			end
			x = x + 1;
			name, r, icon, count, dispelType, duration, expirationTime = UnitDebuff(unit, x, removable);
		end
	end
	return nil;
end

function UnitInVehicle(unit)
	return false
end

function UnitPower(unit, powerType)
	return UnitMana(unit, powerType)
end

function UnitPowerMax(unit, powerType)
	return UnitManaMax(unit, powerType)
end

local hooks = {}

local function SpellID_to_SpellName(spell)
	if type(spell) == "number" then
		return GetSpellInfo(spell)
	else
		if tonumber(spell) then
			return GetSpellInfo(spell)
		else
			return spell
		end
	end
	return
end

hooks.GetSpellCooldown = GetSpellCooldown
function GetSpellCooldown(spell, booktype)
	if booktype and (booktype == BOOKTYPE_SPELL or booktype == BOOKTYPE_PET) then
		return hooks.GetSpellCooldown(spell, booktype) -- вызываем оригинал
	else
		spell = SpellID_to_SpellName(spell)
		-- Add parentheses to the end of spell names like "Faerie Fire (Feral)"
		if spell then
			spell = (string.gsub(spell, "%)$",")()"))
			return hooks.GetSpellCooldown(spell) -- вызываем оригинал
		else
			return nil
		end
	end
end

hooks.IsUsableSpell = IsUsableSpell
function IsUsableSpell(spell, booktype)
	if booktype and (booktype == BOOKTYPE_SPELL or booktype == BOOKTYPE_PET) then
		return hooks.IsUsableSpell(spell, booktype) -- вызываем оригинал
	else
		spell = SpellID_to_SpellName(spell)
		if spell then
			spell = (string.gsub(spell, "%)$",")()"))
			return hooks.IsUsableSpell(spell) -- вызываем оригинал
		else
			return nil
		end
	end
end

hooks.IsSpellInRange = IsSpellInRange
function IsSpellInRange(spell, booktype, unit)
	if booktype then
		if booktype == BOOKTYPE_SPELL or booktype == BOOKTYPE_PET then
			return hooks.IsSpellInRange(spell, booktype, unit) -- вызываем оригинал
		else
			unit = booktype
			spell = SpellID_to_SpellName(spell)
			return hooks.IsSpellInRange(spell, unit) -- вызываем оригинал
		end
	else
		spell = SpellID_to_SpellName(spell)
		return hooks.IsSpellInRange(spell) -- вызываем оригинал
	end
end

hooksecurefunc("CreateFrame", function(frameType, name, parent, template)
	if template == "GameTooltipTemplate" then
		local f = getglobal(name)
		f.SetUnitAura = function(self, unit, index, filter)
			if filter and filter:match("HARMFUL") then
				self:SetUnitDebuff(unit, index, filter)
			else
				self:SetUnitBuff(unit, index, filter)
			end
		end
	end
	return f
end)

function GetSpellBookID(spellID, booktype)
	booktype = booktype or BOOKTYPE_SPELL
	local book_id = 1
	while true do
		local link = GetSpellLink(book_id, booktype)
		if not link then return end
		local id = tonumber(link:match('H.-:(%d+)|h'))
		if id == spellID then
		  return book_id
		end
		book_id = book_id + 1
	end
end

function IsSpellKnown(spellID, isPetSpell)
	local book_id = GetSpellBookID(spellID, isPetSpell and BOOKTYPE_PET or BOOKTYPE_SPELL)
	return book_id ~= nil
end

function PrintTab(obj, max_depth, level, meta_level)
	if not obj or obj == "" then
		print('Root = nil')
		return
	end
	if not level then level = 0 end
	if not max_depth then max_depth = 299 end
	if level == 0 then
		obj = {Root = obj}
	end
	
	local Table_stack
	if not Table_stack then
		Table_stack = {}
	end
	local inset = strrep('   ', level)
	inset = '\19'..inset
	local close_flag = false
	local meta_flag = false
	for m_key, m_value in pairs(obj) do
		key = m_key
		value = m_value
		if type(key) == 'table' then
			key = 'table_key'
			elseif type(key) == 'function' then
			key = 'function'
			elseif type(key) == 'userdata' then
			key = 'userdata'
		end
		if type(value) == 'table' then
			if not Table_stack[value] and (level < max_depth) then
				print(inset..'['..key..'] = {')
				Table_stack[value] = true
				PrintTab(value, max_depth, level+1, obj, meta_level)
				else
				close_flag = true
				print(inset..'['..key..'] = {...}')
			end
			elseif type(value) == 'function' then
			print(inset..'['..key..'] = function')
			elseif type(value) == 'userdata' then
			local user_data = 'userdata'
			if pcall(function() obj:GetName() end) then
				user_data = obj:GetName() or ''
			end
			print(inset..'['..key..'] = '..user_data)
			elseif type(value) == 'boolean' then
			print(inset..'['..key..'] = '..tostring(value))
			else
			print(inset..'['..key..'] = '..value)
		end
	end
	local meta = getmetatable(obj)
	if meta and meta_level   then
		if not Table_stack[meta] and (level < max_depth) then
			print(inset..'[metatable] = {')
			Table_stack[meta] = true
			PrintTab(meta, max_depth, level+1, obj, meta_level)
			else
			meta_flag = true
			print(inset..'['..key..'] = {...}')
		end
	end
	if not close_flag and level > 0 then
		inset = strrep('   ', level-1)
		inset = '\19'..inset
		print(inset..'}')
	end
	if level == 0 then
		for k, v in pairs(Table_stack) do
			Table_stack[k] = nil
		end
		Table_stack = nil
	end
end
