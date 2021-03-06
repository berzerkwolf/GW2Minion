-- flips a table so keys become values
function table_invert(t)
	if (ValidTable(t)) then
		local s={}
		for k,v in pairs(t) do
			s[v]=k
		end
		return s
	else
		error("table_invert(), no valid table received.",2)
	end
end

-- takes in a % number and gives back a random number near that value, for randomizing skill usage at x% hp
function randomize(val)
	if ( val <= 100 and val > 0) then
		local high,low
		if ( (val + 15) > 100) then
			high = 100			
		else
			high = val + 15
		end
		if ( (val - 15) <= 0) then
			low = 1			
		else
			low = val - 15
		end
		return math.random(low,high)
	end
	return 0
end

function TimeSince(previousTime)
	if (type(previousTime) == "number") then
		previousTime = previousTime or 0
		return ml_global_information.Now - previousTime
	end
	error("TimeSince(), no valid number received.",2)
end

function IsNullString( test ) 
	return (test == "" or not test)
end

function Now()
	return ml_global_information.Now
end

function MultiComp(search, criteria)
	--Use, multiple OR's in one line, returns true or false
	--search can be either a number or string
	--criteria should be (,)-separated for OR's, (+)-separated for AND's
	
	--ctype should be 1 for strings, 2 for numbers.
	local ctype = 1
	if tonumber(search) ~= nil then
		ctype = 2
	end
	
	for _orids in StringSplit(criteria,",") do
		local found = false
		for _andid in StringSplit(_orids,"+") do
			found = false
			if ctype == 1 then
				if search == _andid then found = true end
			elseif ctype == 2 then
				if search == tonumber(_andid) then found = true end
			end
			if (not found) then 
				break
			end
		end
		if (found) then 
			return true 
		end
	end
	return false
end

function PathDistance(posTable)
	if ( TableSize(posTable) > 0) then
		local distance = 0
		local id1, pos1 = next(posTable)
		if (id1 ~= nil and pos1 ~= nil) then
			local id2, pos2 = next(posTable, id1)
			if (id1 ~= nil and pos2 ~= nil) then
				while (id2 ~= nil and pos2 ~= nil) do
					local posDistance = math.sqrt(math.pow(pos2.x-pos1.x,2) + math.pow(pos2.y-pos1.y,2) + math.pow(pos2.z-pos1.z,2))
					distance = distance + posDistance
					pos1 = pos2
					id2, pos2 = next(posTable,id2)
				end
			end
		end
		return distance
	end
	error("PathDistance(), no valid position table received.",2)
end

function FileExists(file)
  local f = fileread(file)
  if ( TableSize(f) > 0) then
    return true
  end
  return false 
end

function LinesFrom(file)
	lines = fileread(file)
	cleanedLines = {}
	--strip any bad line endings
	if (ValidTable(lines)) then
		for i,line in pairs(lines) do
			if line:sub(line:len(),line:len()+1) == "\r" then
				cleanedLines[i] = line:sub(1,line:len()-1)
			else
				cleanedLines[i] = line
			end
		end
	end
	
  return cleanedLines 
end

function StringSplit(s,sep)
	if (ValidString(s) and ValidString(sep)) then
		local lasti, done, g = 1, false, s:gmatch('(.-)'..sep..'()')
		return function()
			if done then return end
			local v,i = g()
			if s == '' or sep == '' then done = true return s end
			if v == nil then done = true return s:sub(lasti) end
			lasti = i
			return v
		end
	else
		error("StringSplit(), no valid string received.",2)
	end
end

function StringToTable(str, delimiter)
    local t = {}
    local search = "(.-)" .. delimiter
	local last_char = 1
	local i = 1
	str = string.gsub(str,"\r","")
	
	local index, char, data = str:find(search,1)
	while index do
		if data ~= "" then
			t[i] = data
		end
		last_char = char+1
		index, char, data = str:find(search, last_char)
		i = i + 1
	end
	
	if last_char <= #str then
		data = str:sub(last_char)
		t[i] = data
	end
	
	return t
end

function ExecuteFunction(args)
	if args == nil then
		return
	end
	
	if (type(args) == "function") then
		args()
	elseif (type(args) == "string") then
	
		local t = StringToTable(args,";")
		local start = 1
		local finish = TableSize(t)
		
		for x = start,finish do
			local f = _G
			for v in t[x]:gmatch("[^%.]+") do
				f=f[v]
			end
			f()
		end
	
	elseif (type(args) == "table") then
		local numArgs = TableSize(args) - 1
		local f = _G
		for v in args[1]:gmatch("[^%.]+") do
			f=f[v]
		end
		
		if (numArgs == 1) then
			f(args[2])
		elseif (numArgs == 2) then
			f(args[2],args[3])
		elseif (numArgs == 3) then
			f(args[2],args[3],args[4])
		end
	end
end

function StringContains(sString, item)

    if (sString == nil) then return false end
            
    for _orids in StringSplit(sString,",") do
        if (tostring(item) == tostring(_orids)) then 
            return true
        end        
    end
    return false
end

function ApproxEqual(num1, num2)
    return math.abs(math.abs(num1) - math.abs(num2)) < .000001
end

function TableContains(table, element)
  for _, value in pairs(table) do
    if value == element then
      return true
    end
  end
  return false
end

function ValidTable(table)
    return table ~= nil and TableSize(table) > 0
end

function ValidString(string)
	return type(string) == "string" and #string > 0
end

function TrimString(new_string, count)
	return new_string:sub(1,new_string:len() - count)
end

-- returns a table containing first entry in the list, list of keys, and list of values
function GetComboBoxList(entryTable)
	local firstkey = ""
	local firstvalue = ""
	local keylist = ""
	local valuelist = ""
	
	for key, value in pairs(entryTable) do
		if (type(key) == "string" or type(key) == "number") then
			if (keylist == "") then
				keylist = tostring(key)
				firstkey = tostring(key)
			else
				keylist = keylist..","..tostring(key)
			end
		end
		
		if (type(value) == "string" or type(value) == "number") then
			if (valuelist == "") then
				valuelist = tostring(value)
				firstvalue = tostring(value)
			else
				valuelist = valuelist..","..tostring(value)
			end
		end
	end
	
	return { firstKey = firstkey, firstValue = firstvalue, keyList = keylist, valueList = valuelist}
end

function round(num, idp)
  return tonumber(string.format("%." .. (idp or 0) .. "f", num))
end

function findfunction(x)
  assert(type(x) == "string")
  local f=_G
  for v in x:gmatch("[^%.]+") do
    if type(f) ~= "table" then
       return nil, "looking for '"..v.."' expected table, not "..type(f)
    end
    f=f[v]
  end
  if type(f) == "function" then
    return f
  else
    return nil, "expected function, not "..type(f)
  end
end

function table_merge(t1, t2)
    for k,v in pairs(t2) do t1[k] = v end
end

function pairsByKeys (t, f)
  local a = {}
  for n in pairs(t) do table.insert(a, n) end
  table.sort(a, f)
  local i = 0      -- iterator variable
  local iter = function ()   -- iterator function
	i = i + 1
	if a[i] == nil then return nil
	else return a[i], t[a[i]]
	end
  end
  return iter
end

function spairs(t, order)
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys 
    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
		--table.sort(keys, function(a,b) return t[a].name < t[b].name end)
    else
        table.sort(keys)
    end

    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

function GetRandomTableEntry(t)
    if (ValidTable(t)) then
        local i = math.random(1,TableSize(t))
        local counter = 1
        for key, value in pairs(t) do
            if (counter == i) then
                return value
            else
                counter = counter + 1
            end
        end
    end
    
    ml_debug("Error in GetRandomTableEntry()")
end

function TableInsertSort(tblSort, iInsertPoint, vInsertValue)
	assert(type(tblSort) == "table", "First parameter must be the table to sort.")
	assert(type(iInsertPoint) == "number", "Second parameter must be an integer insertion point.")
	assert(vInsertValue ~= nil, "Third parameter must be a non-null variant to be inserted.")
	
	local orderedTable = {}
	local tempTable = {}
	local t = tblSort
	local p = iInsertPoint
	local size = TableSize(t)
	
	if (size < p) then
		t[p] = vInsertValue
		orderedTable = t
	else
		--d("Size was not less than p.")
		for k,v in spairs(t) do
			if (tonumber(k) >= p) then
				tempTable[tonumber(k)+1] = v
			end
		end
			
		local x = (TableSize(t) + 1)
		for i=1,x do
			if i < p then
				orderedTable[i] = t[i]
			elseif i == p then
				orderedTable[i] = vInsertValue
			elseif i > p then
				orderedTable[i] = tempTable[i]
			end
		end
	end
	return orderedTable
end

function TableRemoveSort(tblSort, iRemovePoint)
	assert(type(tblSort) == "table", "First parameter must be the table to sort.")
	assert(type(iRemovePoint) == "number", "Second parameter must be an integer insertion point.")
	
	local orderedTable = {}
	local tempTable = {}
	local t = tblSort
	local p = iRemovePoint
	local size = TableSize(t)
	
	assert(not(p > size or p < 1), "Removal point is out of range.")
	
	if (size == p) then
		--d("Entry was highest on list, remove it and return.")
		t[p] = nil
		orderedTable = t
	else
		--d("Entry was not highest on list.")
		for k,v in spairs(t) do
			if tonumber(k) > p then
				tempTable[tonumber(k)-1] = v
			end
		end
		
		local x = (TableSize(t) - 1)
		
		for i=1,x do
			if i < p then
				orderedTable[i] = t[i]
			elseif i >= p then
				orderedTable[i] = tempTable[i]
			end
		end
	end
	return orderedTable
end

--psuedo enum values for task classes
TS_FAILED = 0
TS_SUCCEEDED = 1
TS_PROGRESSING = 2

TP_IMMEDIATE = 0
TP_ASAP = 1

IMMEDIATE_GOAL = 1
REACTIVE_GOAL = 2
LONG_TERM_GOAL = 3