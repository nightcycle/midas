--!strict
local _Package = script.Parent.Parent
local _Packages = _Package.Parent
-- Services
-- Packages
-- Modules
-- Types
local Util = require(_Package:WaitForChild("Util"))
type DataType = Util.DataType
export type OnSaveInvoke = (
	projectId: string, 
	dataSetId: string, 
	dataTableId: string, 
	data: {[string]: unknown},
	formats: {[string]: DataType}
) -> boolean


-- Constants
-- Variables
-- References
-- Private Functions
-- Class
local StorageUtil = {}

return StorageUtil