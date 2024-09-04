--!strict
-- Services
-- Packages
-- Modules
local StorageUtil = require("./Util")
-- Types
export type OnBatchInsertInvoke = StorageUtil.OnBatchInsertInvoke
export type OnBatchSetInvoke = StorageUtil.OnBatchSetInvoke
-- Constants
-- Variables
-- References
-- Private Functions
-- Class
local Util = {}

Util.MongoDB = require(script:WaitForChild("MongoDB"))

return Util
