--!strict
-- References
local Package = script.Parent
local Packages = Package.Parent

-- Packages
local Config = require(Package:WaitForChild("Config"))
local TableUtil = require(Packages:WaitForChild("TableUtil"))
local Util = {}

function Util.encode(fullData: {[string]: any}): {[string]: any}
	fullData = TableUtil.deepCopy(fullData)
	
	local function replaceKeys(data: {[string]: any})
		local out = {}
		for k, v in pairs(data) do
			k = string.gsub(k, Config.Encoding.Marker, "")
			if type(v) == "table" then
				v = replaceKeys(v)
				if type(v) == "string" then
					v = v:gsub(Config.Encoding.Marker, "")
				end
			end

			if Config.Encoding.Dictionary.Properties[k] then
				local key = Config.Encoding.Dictionary.Properties[k]
				key = key:gsub(Config.Encoding.Marker, "")
				out[Config.Encoding.Marker .. key] = v
			else
				out[k] = v
			end
		end
		return out
	end

	local function replaceBinaryList(data: {[string]: any}, binArray: {[number]: string})
		local encodedStr = Config.Encoding.Marker
		for _, item in ipairs(binArray) do
			local v = "0"
			if data[item] then
				if data[item] == true then
					v = "1"
				end
			end
			encodedStr = encodedStr .. v
		end
		return encodedStr
	end

	local function replaceValues(data: {[string]: any}, valDict: {[string]: any}, binArrayReg: {[string]: any})
		local out = {}

		for k, v in pairs(data) do
			local nxtBinArrayReg: {[string]: any} |  {[number]: any} = {}
			if binArrayReg[k] then
				nxtBinArrayReg = binArrayReg[k]
			end

			if type(v) == "string" then
				v = string.gsub(v, Config.Encoding.Marker, "")
			end

			if valDict[k] then
				if type(v) == "table" then
					if type(nxtBinArrayReg) == "table" and #nxtBinArrayReg > 0 then
						v = replaceBinaryList(v, nxtBinArrayReg :: any)
					else
						v = replaceValues(v, valDict[k], nxtBinArrayReg :: any)
					end
				else
					if valDict[k][v] then
						local encoded_v = valDict[k][v]
						encoded_v = encoded_v:gsub(Config.Encoding.Marker, "")
						v = Config.Encoding.Marker .. encoded_v
					end
				end
			else
				if type(v) == "table" then
					if type(nxtBinArrayReg) == "table" and #nxtBinArrayReg > 0 then
						v = replaceBinaryList(v, nxtBinArrayReg :: any)
					else
						v = replaceValues(v, {}, nxtBinArrayReg :: any)
					end
				end
			end

			out[k] = v
		end

		return out
	end

	return replaceKeys(replaceValues(fullData, Config.Encoding.Dictionary.Values, Config.Encoding.Arrays :: any))
end

function Util.decode(encodedData: {[string]: any})
	encodedData = TableUtil.deepCopy(encodedData)

	local function restoreKeys(data: {[string]: any})
		local out = {}
		for k, v in pairs(data) do
			if type(v) == "table" then
				v = restoreKeys(v)
			end

			local decodedKey = k
			if string.sub(k, 1, #Config.Encoding.Marker) == Config.Encoding.Marker then
				for originalKey, encodedKey in pairs(Config.Encoding.Dictionary.Properties) do
					if k == Config.Encoding.Marker .. encodedKey then
						decodedKey = originalKey
						break
					end
				end
			end

			out[decodedKey] = v
		end
		return out
	end

	local function restoreBinaryList(encodedStr: string, binArray: {[number]: string})
		local restoredData = {}
		for i, key in ipairs(binArray) do
			local v = string.sub(encodedStr, i + #Config.Encoding.Marker, i + #Config.Encoding.Marker)
			if v == "1" then
				restoredData[key] = true
			else
				restoredData[key] = false
			end
		end
		return restoredData
	end

	local function restoreValues(data: {[string]: any}, valDict: {[string]: any}, binArrayReg: {[string]: any})
		local out = {}

		for k, v in pairs(data) do
			local nxtBinArrayReg = {}
			if binArrayReg[k] then
				nxtBinArrayReg = binArrayReg[k]
			end

			if type(v) == "table" then
				if valDict[k] then
					v = restoreValues(v, valDict[k], nxtBinArrayReg :: any)
				else
					v = restoreValues(v, {}, nxtBinArrayReg :: any)
				end
			else
				if type(v) == "string" then
					if string.find(v, Config.Encoding.Marker) then
						if type(nxtBinArrayReg) == "table" and #nxtBinArrayReg > 0 then
							v = restoreBinaryList(v, nxtBinArrayReg :: any)
						elseif valDict[k] then
							for origV, altV in pairs(valDict[k]) do
								if v == altV then
									v = origV
								end
							end
						end
					end
				end
			end

			out[k] = v
		end

		return out
	end

	return restoreValues(restoreKeys(encodedData), Config.Encoding.Dictionary.Values, Config.Encoding.Arrays :: any)
end



return Util