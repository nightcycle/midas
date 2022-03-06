--[=[
	Encrypts a table, preparing it to be stored on a datastore.
	@class Encrypter
]=]

local runService = game:GetService("RunService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local httpService = game:GetService("HttpService")
local players = game:GetService("Players")

local packages = require(replicatedStorage:WaitForChild("Packages"))
local import = packages("import")
local maidConstructor = packages('maid')
local mathUtils = packages('math')
local tableUtils = packages('table')

local typeConversions = {
    ["Vector3"] = {
        To = function(serialObject)
            return Vector3.new(serialObject.X, serialObject.Y, serialObject.Z)
        end,
        From = function(val)
            return {
                SerialType = "Vector3",
                X = mathUtils.round(val.X, 0.01),
                Y = mathUtils.round(val.Y, 0.01),
                Z = mathUtils.round(val.Z, 0.01),
            }
        end,
    },
    ["Color3"] = {
        To = function(serialObject)
            return Color3.fromHex(serialObject.Hex)
        end,
        From = function(val)
            return {
                SerialType = "Color3",
                Hex = val:ToHex(),
            }
        end,
    },
    ["CFrame"] = {
        To = function(serialObject)
            return CFrame.new(
                serialObject.X,
                serialObject.Y,
                serialObject.Z,
                serialObject.R00,
                serialObject.R01,
                serialObject.R02,
                serialObject.R10,
                serialObject.R11,
                serialObject.R12,
                serialObject.R20,
                serialObject.R21,
                serialObject.R22
            )
        end,
        From = function(val)
            local x, y, z, R00, R01, R02, R10, R11, R12, R20, R21, R22 = val:GetComponents()
            return {
                SerialType = "CFrame",
                X = mathUtils.round(x, 0.01),
                Y = mathUtils.round(y, 0.01),
                Z = mathUtils.round(z, 0.01),
                R00 = mathUtils.round(R00, 0.01),
                R01 = mathUtils.round(R01, 0.01),
                R02 = mathUtils.round(R02, 0.01),
                R10 = mathUtils.round(R10, 0.01),
                R11 = mathUtils.round(R11, 0.01),
                R12 = mathUtils.round(R12, 0.01),
                R20 = mathUtils.round(R20, 0.01),
                R21 = mathUtils.round(R21, 0.01),
                R22 = mathUtils.round(R22, 0.01),
            }
        end,
    },
}

function serializeValue(v)
	-- print("V", v, "TypeOf", typeof(v))
    local converters = typeConversions[typeof(v)]
--     print("Result", converters)
    if converters then
        return converters.From(v)
    end
    return v
end

function deserializeValue(v)
    local converters = typeConversions[v.SerialType]
    if converters then
        return converters.To(v)
    end
    return v
end

function serialize(tabl, portedTableList)
	portedTableList = portedTableList or {}
	if portedTableList[tabl] then return tabl end
	portedTableList[tabl] = true
	for k, v in pairs(tabl) do
		-- print("Loading", k, v, type(v))
		if typeConversions[typeof(v)] ~= nil then
			-- print("B")
			tabl[k] = serializeValue(v)
		elseif type(v) == "table" then
			-- print("A")
			tabl[k] = serialize(v, portedTableList)
		end
	end
	return tabl
end

function deserialize(tabl, portedTableList)
    portedTableList = portedTableList or {}
    if portedTableList[tabl] then return tabl end
    portedTableList[tabl] = true
    for k, v in pairs(tabl) do
        if type(v) == "table" and v.SerialType == nil then
            tabl[k] = deserialize(v, portedTableList)
        elseif type(v) == "table" and v.SerialType ~= nil then
            tabl[k] = deserializeValue(v)
        end
    end
    return tabl
end


local dictionary, length = {}, 0
for i = 32, 127 do
	if i ~= 34 and i ~= 92 then
		local c = string.char(i)
		dictionary[c], dictionary[length] = length, c
		length = length + 1
	end
end

local escapemap = {}
for i = 1, 34 do
	i = ({34, 92, 127})[i-31] or i
	local c, e = string.char(i), string.char(i + 31)
	escapemap[c], escapemap[e] = e, c
end
local function escape(s)
	return (s:gsub("[%c\"\\]", function(c)
		return "\127"..escapemap[c]
	end))
end

local function unescape(s)
	return (s:gsub("\127(.)", function(c)
		return escapemap[c]
	end))
end

local function copy(t)
	local new = {}
	for k, v in pairs(t) do
		new[k] = v
	end
	return new
end

local function tobase93(n)
	local value = ""
	repeat
		local remainder = n%93
		value = dictionary[remainder]..value
		n = (n - remainder)/93
	until n == 0
	return value
end

local function tobase10(value)
	local n = 0
	for i = 1, #value do
		n = n + 93^(i-1)*dictionary[value:sub(-i, -i)]
	end
	return n
end

function compress(text)
	local dictionary = copy(dictionary)
	local key, sequence, size = "", {}, #dictionary
	local width, spans, span = 1, {}, 0
	local function listkey(key)
		local value = tobase93(dictionary[key])
		if #value > width then
			width, span, spans[width] = #value, 0, span
		end
		sequence[#sequence+1] = (" "):rep(width - #value)..value
		span = span + 1
	end
	text = escape(text)
	local prevScore = 0
	for i = 1, #text do
		if math.random(15000) == 1 then
			if math.random(20) == 1 then
				local score = math.floor(100*i/#text)
				if score ~= prevScore then
					prevScore = score
					print(score.."%")
				end
			end
			task.wait()
		end
		local c = text:sub(i, i)
		local new = key..c
		if dictionary[new] then
			key = new
		else
			listkey(key)
			key, size = c, size+1
			dictionary[new], dictionary[size] = size, new
		end
	end
    listkey(key)
	spans[width] = span
    return table.concat(spans, ",").."|"..table.concat(sequence)
end

function decompress(text)
	local dictionary = copy(dictionary)
	local sequence, spans, content = {}, text:match("(.-)|(.*)")
	local groups, start = {}, 1
	for span in spans:gmatch("%d+") do
		local width = #groups+1
		groups[width] = content:sub(start, start + span*width - 1)
		start = start + span*width
	end
	local previous;
	for width = 1, #groups do
		for value in groups[width]:gmatch(('.'):rep(width)) do
			local entry = dictionary[tobase10(value)]
			if previous then
				if entry then
					sequence[#sequence+1] = entry
					dictionary[#dictionary+1] = previous..entry:sub(1, 1)
				else
					entry = previous..previous:sub(1, 1)
					sequence[#sequence+1] = entry
					dictionary[#dictionary+1] = entry
				end
			else
				sequence[1] = entry
			end
			previous = entry
		end
	end
	return unescape(table.concat(sequence))
end

return {
	set = function(data:table, compressionEnabled:boolean)
		compressionEnabled = false
		if not data or data == "" then return "" end
		--serialize variables
		data = tableUtils.deepCopy(data)
		data = serialize(data)
		-- print("SET", data)
		--convert to JSON
		data = httpService:JSONEncode(data)
		--compress from JSON
		if compressionEnabled then
			local l1 = string.len(data)
			print("Pre", l1)
			data = compress(data)
			local l2 = string.len(data)
			print("Post", l2)
			print("Reduction", 1 - l2/l1)
			return compress(data)
		else
			return data
		end
	end,
	get = function(data:string, compressionEnabled:boolean)
		compressionEnabled = false
		if not data or data == "" then return {} end
		--decompress to JSON
		-- print(data)
		if compressionEnabled then
			data = decompress(data)
		end
		--convert from JSON
		data = httpService:JSONDecode(data)
		--deserialize variables
		-- print(data)
		return deserialize(data)
	end,
}