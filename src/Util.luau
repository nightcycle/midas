--!strict
-- Services
-- Packages
-- Modules
-- Types
type DateTimeData = {
	Year: number,
	Month: number,
	Day: number,
	Hour: number,
	Minute: number,
	Second: number,
	Millisecond: number,
}
type LuneDateTimeData = {
	year: number,
	month: number,
	day: number,
	hour: number,
	minute: number,
	second: number,
	millisecond: number,
}
export type PartialLuneDatetime = {
	unixTimestampMillis: number,
	toUniversalTime: (self: PartialLuneDatetime) -> LuneDateTimeData,
}

--- @type DataType "Binary" | "Date" | "Decimal128" | "Double" | "Int32" | "Int64" | "Boolean" | "Array" | "Object" | "String"
--- @within Midas
---
--- The pre-approved storage types. Good for type validation + allocating the most efficient amount of storage space.
export type DataType =
	"Binary"
	| "Date"
	| "Decimal128"
	| "Double"
	| "Int32"
	| "Int64"
	| "Boolean"
	| "Array"
	| "Object"
	| "String"

-- Constants
-- Variables
-- References
-- Private Functions
-- Class
local Util = {}

function Util.getIfDateTimeLike(value: unknown): boolean
	if typeof(value) == "DateTime" then
		return true
	else
		local isLune = false
		pcall(function()
			isLune = (value :: any).unixTimestampMillis ~= nil
		end)
		return isLune
	end
end

function Util.toTimeString(rawDateTime: DateTime | PartialLuneDatetime): string
	assert(rawDateTime ~= nil)
	local isLune = false
	pcall(function()
		isLune = (rawDateTime :: any).UnixTimestampMillis == nil
	end)
	if isLune then
		local datetime: PartialLuneDatetime = rawDateTime :: any
		local data: LuneDateTimeData = datetime:toUniversalTime()
		return `{data["year"]}-{string.format("%02d", data["month"])}-{string.format("%02d", data["day"])}T{string.format(
			"%02d",
			data["hour"]
		)}:{string.format("%02d", data["minute"])}:{string.format("%02d", data["second"])}.{string.format(
			"%03d",
			data["millisecond"]
		)}Z`
	else
		local dateTime: DateTime = rawDateTime :: any
		local data = dateTime:ToUniversalTime() :: DateTimeData
		return `{data["Year"]}-{string.format("%02d", data["Month"])}-{string.format("%02d", data["Day"])}T{string.format(
			"%02d",
			data["Hour"]
		)}:{string.format("%02d", data["Minute"])}:{string.format("%02d", data["Second"])}.{string.format(
			"%03d",
			data["Millisecond"]
		)}Z`
	end
end

return Util
