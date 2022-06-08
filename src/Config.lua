local RunService = game:GetService("RunService")
if RunService:IsServer() then
	return {
		Chances = {},
		VIP = {
			Users = {},
			Groups = {},
		},
		Gamepasses = {
			Test = 123,
		},
		Version = 12,
	}
else
	return {

	}
end