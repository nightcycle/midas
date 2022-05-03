local RunService = game:GetService("RunService")
if RunService:IsClient() then
	return {

	}
else
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
end