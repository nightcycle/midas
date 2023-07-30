--!strict
local Package = script.Parent
local Types = require(Package.Types)

local Config: Types.ConfigurationData = {
	Version = {
		Major = 0,
		Minor = 0,
		Patch = 0,
	},
	BytesPerMinutePerPlayer = 2000*15,
	SendDeltaState = false, --Send just the changes of state, not the entirety
	SendDataToPlayFab = true,
	PrintEventsInStudio = true,
	PrintLog = false,
	Keys = {},
	Encoding = {
		Marker = "~",
		Dictionary = {
			Properties = {},
			Values = {},
		},
		Arrays = {},
	},
	Template = {
		State = {
			Chat = {
				LastMessage = true,
				Count = true,
			},
			Character = {
				IsDead = true,
				Height = true,
				Mass = true,
				State = true,
				WalkSpeed = true,
				Position = true,
				Altitude = true,
				JumpPower = true,
				Health = true,
				MaxHealth = true,
				Deaths = true,
			},
			Population = {
				Total = true,
				Team = true,
				PeakFriends = true,
				Friends = true,
				SpeakingDistance = true,
			},
			Performance = {
				
				Client = {
					Ping = true,
					FPS = true,
				},
				Server = {
					EventsPerMinute = true,
					Ping = true,
					ServerTime = true,
					HeartRate = true,
					Instances = true,
					MovingParts = true,
					Network = {
						Data = {
							Send = true,
							Receive = true,
						},
						Physics = {
							Send = true,
							Receive = true,
						},
					},
					Memory = {
						Internal = true,
						HttpCache = true,
						Instances = true,
						Signals = true,
						LuaHeap = true,
						Script = true,
						PhysicsCollision = true,
						PhysicsParts = true,
						CSG = true,
						Particle = true,
						Part = true,
						MeshPart = true,
						SpatialHash = true,
						TerrainGraphics = true,
						Textures = true,
						CharacterTextures = true,
						SoundsData = true,
						SoundsStreaming = true,
						TerrainVoxels = true,
						Guis = true,
						Animations = true,
						Pathfinding = true,
					},
				},
			},
			Spending = {
				Product = true,
				Gamepass = true,
				Total = true,
			},
			Groups = {},
			Badges = {},
			Demographics = {
				AccountAge = true,
				RobloxLanguage = true,
				SystemLanguage = true,
				UserSettings = {
					Fullscreen = true,
					GamepadCameraSensitivity = true,
					MouseSensitivity = true,
					SavedQualityLevel = true,
				},
				Platform = {
					Accelerometer = true,
					Gamepad = true,
					Gyroscope = true,
					Keyboard = true,
					Mouse = true,
					Touch = true,
					VR = true,
					ScreenSize = true,
					ScreenRatio = true,
				},
			},
		},
		Event = {
			Join = {
				Teleport = true,
				Enter = true,
			},
			Chat = {
				Spoke = true,
			},
			Character = {
				Died = true,
			},
			Spending = {
				Purchase = {
					Product = true,
					Gamepass = true,
				},
			},
			Exit = {
				Quit = true,
				Disconnect = true,
				Close = true,
			},
		}
	},
}

return Config
