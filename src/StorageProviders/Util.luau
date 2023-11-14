--!strict
local _Package = script.Parent.Parent
local _Packages = _Package.Parent
-- Services
-- Packages
-- Modules
-- Types
local Util = require(_Package:WaitForChild("Util"))
type DataType = Util.DataType
export type OnBatchSaveInvoke = (
	projectId: string, 
	dataSetId: string, 
	dataTableId: string, 
	dataList: {[number]: {[string]: unknown}}, 
	format: {[string]: DataType},
	onPayloadSizeKnownInvoke: (size: number) -> ()
) -> boolean

-- Constants
-- Variables
-- References
-- Private Functions
-- Class
local StorageUtil = {}

return StorageUtil