--!strict
local _Package = script.Parent.Parent
local _Packages = _Package.Parent
-- Services
-- Packages
-- Modules
-- Types
local Util = require(_Package:WaitForChild("Util"))

type DataType = Util.DataType

--- @type FormatDictionary {[string]: DataType}
--- @within Midas
---
--- A parameter of OnBatchSaveInvoke. A dictionary of the assigned data types for each key in the rows, used to inform how to structure data in the API requests.
type FormatDictionary = { [string]: DataType }

--- @type DataList {[number]: {[string]: unknown}}
--- @within Midas
---
--- A parameter of OnBatchSaveInvoke. A list of dictionaries containing unknown data that can be processed into storage safe data
type DataList = { [number]: { [string]: unknown } }

--- @type PayloadRecorder (size: number) -> ()
--- @within Midas
---
--- A parameter of OnBatchSaveInvoke. In order to respect bandwidth limits, Midas attempts to track how much data is being sent out. Once you know how much that is call this function. Native methods like MongoDB will handle it for you, just pass it on as a parameter.
type PayloadRecorder = (size: number) -> ()

--- @type OnBatchInsertInvoke (projectId: string, dataSetId: string, dataTableId: string, dataList: DataList, format: FormatDictionary,onPayloadSizeKnownInvoke: PayloadRecorder) -> boolean
--- @within Midas
---
--- The function called by the framework whenever it wants to mass insert data
export type OnBatchInsertInvoke = (
	projectId: string,
	dataSetId: string,
	dataTableId: string,
	dataList: DataList,
	format: FormatDictionary,
	onPayloadSizeKnownInvoke: PayloadRecorder
) -> boolean

--- @type OnBatchSetInvoke (projectId: string, dataSetId: string, dataTableId: string, onKey: string, dataList: DataList, format: FormatDictionary,onPayloadSizeKnownInvoke: PayloadRecorder) -> boolean
--- @within Midas
---
--- The function called by the framework whenever it wants to mass write data at a specific key
export type OnBatchSetInvoke = (
	projectId: string,
	dataSetId: string,
	dataTableId: string,
	onKey: string,
	dataList: DataList,
	format: FormatDictionary,
	onPayloadSizeKnownInvoke: PayloadRecorder
) -> boolean

-- Constants
-- Variables
-- References
-- Private Functions
-- Class
local StorageUtil = {}

return StorageUtil
