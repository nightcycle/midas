local src = script.Parent.Parent
local packages = src.Parent
local synth = require(packages:WaitForChild("synthetic"))

return function(txt: string)
	local _Text = synth.State(txt)
	local inst = synth.New "Frame" {
		Name = "Feedback",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(300, 0),
		
		[synth.Children] = {
			synth.New "Frame" {
				Name = "Feedback",
				AnchorPoint = Vector2.new(0.5, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Color3.new(),
				BackgroundTransparency = 0.5,
				ClipsDescendants = true,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(300, 0),
				
				[synth.Children] = {
					synth.New "TextLabel" {
						Name = "Feedback",
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundColor3 = Color3.fromRGB(26, 26, 26),
						Size = UDim2.fromScale(1, 0),
						Font = Enum.Font.Ubuntu,
						Text = "Feedback",
						TextColor3 = Color3.new(1, 1, 1),
						TextSize = 14,
						TextXAlignment = Enum.TextXAlignment.Left,
						
						[synth.Children] = {
							synth.New "UIPadding" {
								PaddingBottom = UDim.new(0, 5),
								PaddingLeft = UDim.new(0, 5),
								PaddingRight = UDim.new(0, 5),
								PaddingTop = UDim.new(0, 5)
							}
						}
					},
					synth.New "UICorner" {
						CornerRadius = UDim.new(0, 4)
					},
					synth.New "UIListLayout" {
						SortOrder = Enum.SortOrder.LayoutOrder
					},
					synth.New "Frame" {
						Name = "SliderHolder",
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundColor3 = Color3.new(1, 1, 1),
						BackgroundTransparency = 1,
						LayoutOrder = 2,
						Size = UDim2.new(1, 0, 0, 40),
						
						[synth.Children] = {
							synth.New "Slider" {
								ValueTextEnabled = synth.State(true),
								Input = synth.State(3),
								Notches = synth.State(5),
								MinimumValue = synth.State(1),
								MaximumValue = synth.State(5),
								Color = synth.State(Color3.fromHSV(0.6,1,1))
							},
							synth.New "UIPadding" {
								PaddingBottom = UDim.new(0, 5),
								PaddingLeft = UDim.new(0, 5),
								PaddingRight = UDim.new(0, 5),
								PaddingTop = UDim.new(0, 5)
							}
						}
					},
					synth.New "TextLabel" {
						Name = "Description",
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundColor3 = Color3.new(1, 1, 1),
						BackgroundTransparency = 1,
						LayoutOrder = 1,
						Size = UDim2.fromScale(1, 0),
						Font = Enum.Font.SourceSans,
						RichText = true,
						Text = _Text,
						TextColor3 = Color3.new(1, 1, 1),
						TextSize = 14,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						
						[synth.Children] = {
							synth.New "UIPadding" {
								PaddingBottom = UDim.new(0, 5),
								PaddingLeft = UDim.new(0, 5),
								PaddingRight = UDim.new(0, 5),
								PaddingTop = UDim.new(0, 5)
							}
						}
					},
					synth.New "UIStroke" {
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Color = Color3.fromRGB(76, 76, 76),
						Thickness = 2
					}
				}
			},
			synth.New "TextButton" {
				Name = "ExitButton",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(189, 45, 47),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromOffset(18, 18),
				Font = Enum.Font.GothamBold,
				Text = "X",
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 15,
				
				[synth.Children] = {
					synth.New "UICorner" {
						CornerRadius = UDim.new(0.5, 0)
					},
					synth.New "UIStroke" {
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Color = Color3.new(1, 1, 1),
						Thickness = 2
					}
				}
			}
		}
	}
	return inst
end
