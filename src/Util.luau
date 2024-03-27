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

function Util.toTimeString(dateTime: DateTime): string
	local data = dateTime:ToUniversalTime() :: DateTimeData
	return `{data["Year"]}-{string.format("%02d", data["Month"])}-{string.format("%02d", data["Day"])}T{string.format("%02d", data["Hour"])}:{string.format("%02d", data["Minute"])}:{string.format("%02d", data["Second"])}.{string.format("%03d", data["Millisecond"])}Z`
end

return Util
