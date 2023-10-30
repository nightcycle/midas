--!strict
local _Package = script.Parent
local _Packages = _Package.Parent
-- Services
-- Packages
-- Modules
local StorageUtil = require(script:WaitForChild("Util"))
-- Types
export type OnBatchSaveInvoke = StorageUtil.OnBatchSaveInvoke
-- Constants
-- Variables
-- References
-- Private Functions
-- Class
local Util = {}

Util.MongoDB = require(script:WaitForChild("MongoDB"))

return Util