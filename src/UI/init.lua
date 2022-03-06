local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")

local src = script.Parent
local packages = src.Parent
local synth = require(packages:WaitForChild("synthetic"))

local player = players.LocalPlayer
local playerGui = player.PlayerGui

local MidasUI = synth.New "ScreenGui" {
	Name = "MidasUI",
	Parent = playerGui,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 1000,
}

