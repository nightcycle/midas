local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")

local src = script.Parent.Parent
local packages = src.Parent
local synth = require(packages:WaitForChild("synthetic"))

return function ()
	return synth.New "Frame" {
		Name = "Greeting",
		AnchorPoint = Vector2.new(0.5, 0.5),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.new(),
		BackgroundTransparency = 0.6,
		BorderColor3 = Color3.fromRGB(27, 42, 53),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(400, 0),
		Visible = false,
		
		[synth.Children] = {
			synth.New "UICorner" {
			},
			synth.New "UIStroke" {
				Color = Color3.fromRGB(52, 52, 52),
				Thickness = 3
			},
			synth.New "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 5)
			},
			synth.New "TextLabel" {
				Name = "TitleLabel",
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 30),
				Font = Enum.Font.Ubuntu,
				Text = "Welcome to Strandead!",
				TextColor3 = Color3.fromRGB(199, 199, 199),
				TextSize = 30
			},
			synth.New "UIPadding" {
				PaddingBottom = UDim.new(0, 5),
				PaddingLeft = UDim.new(0, 5),
				PaddingRight = UDim.new(0, 5),
				PaddingTop = UDim.new(0, 5)
			},
			synth.New "Frame" {
				Name = "TitleDivider",
				BackgroundColor3 = Color3.fromRGB(52, 52, 52),
				BorderSizePixel = 0,
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 2)
			},
			synth.New "Frame" {
				Name = "CheckboxFrame",
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Color3.new(),
				BackgroundTransparency = 0.7,
				BorderColor3 = Color3.fromRGB(27, 42, 53),
				LayoutOrder = 3,
				Size = UDim2.fromScale(1, 0),
				
				[synth.Children] = {
					synth.New "Frame" {
						Name = "PromptHolder",
						BackgroundColor3 = Color3.new(1, 1, 1),
						BackgroundTransparency = 1,
						LayoutOrder = 1,
						Size = UDim2.fromOffset(30, 30),
						
						[synth.Children] = {
							synth.New "ImageButton" {
								Name = "Checkbox",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundColor3 = Color3.new(1, 1, 1),
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromOffset(20, 20),
								Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
							}
						}
					},
					synth.New "UIListLayout" {
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 2)
					},
					synth.New "TextLabel" {
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundColor3 = Color3.new(),
						BackgroundTransparency = 0.5,
						Size = UDim2.new(1, -35, 0, 0),
						Font = Enum.Font.TitilliumWeb,
						LineHeight = 1.15,
						Text = "Hello do you agree to press this checkmark because we spent a long time on the checkmark selection animation",
						TextColor3 = Color3.new(1, 1, 1),
						TextSize = 18,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Right,
						
						[synth.Children] = {
							synth.New "UICorner" {
								CornerRadius = UDim.new(0, 4)
							},
							synth.New "UIPadding" {
								PaddingBottom = UDim.new(0, 2),
								PaddingLeft = UDim.new(0, 5),
								PaddingRight = UDim.new(0, 5),
								PaddingTop = UDim.new(0, 2)
							}
						}
					},
					synth.New "UICorner" {
						CornerRadius = UDim.new(0, 4)
					}
				}
			},
			synth.New "Frame" {
				Name = "CheckboxFrame",
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Color3.new(),
				BackgroundTransparency = 0.7,
				BorderColor3 = Color3.fromRGB(27, 42, 53),
				LayoutOrder = 4,
				Size = UDim2.fromScale(1, 0),
				
				[synth.Children] = {
					synth.New "Frame" {
						Name = "PromptHolder",
						BackgroundColor3 = Color3.new(1, 1, 1),
						BackgroundTransparency = 1,
						LayoutOrder = 1,
						Size = UDim2.fromOffset(30, 30),
						
						[synth.Children] = {
							synth.New "ImageButton" {
								Name = "Checkbox",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundColor3 = Color3.new(1, 1, 1),
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromOffset(20, 20),
								Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
							}
						}
					},
					synth.New "UIListLayout" {
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 2)
					},
					synth.New "TextLabel" {
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundColor3 = Color3.new(),
						BackgroundTransparency = 0.5,
						Size = UDim2.new(1, -35, 0, 0),
						Font = Enum.Font.TitilliumWeb,
						LineHeight = 1.15,
						Text = "Hello do you agree to press this checkmark because we spent a long time on the checkmark selection animation",
						TextColor3 = Color3.new(1, 1, 1),
						TextSize = 18,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Right,
						
						[synth.Children] = {
							synth.New "UICorner" {
								CornerRadius = UDim.new(0, 4)
							},
							synth.New "UIPadding" {
								PaddingBottom = UDim.new(0, 2),
								PaddingLeft = UDim.new(0, 5),
								PaddingRight = UDim.new(0, 5),
								PaddingTop = UDim.new(0, 2)
							}
						}
					},
					synth.New "UICorner" {
						CornerRadius = UDim.new(0, 4)
					}
				}
			},
			synth.New "TextLabel" {
				Name = "Description",
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Color3.new(),
				BackgroundTransparency = 0.6,
				LayoutOrder = 2,
				Size = UDim2.fromScale(1, 0),
				Font = Enum.Font.Ubuntu,
				LineHeight = 1.15,
				RichText = true,
				Text = "Long backstory short: I got a balloon at the carnival, I drew a face on him, I sprayed him with special life-long-lasting spray I created, and I named him Balloony. He became my best friend in the whole world, yada-yada-yada, then one tragic day when I was protecting our garden as a lawn gnome, Balloony started floating away.",
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 14,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				
				[synth.Children] = {
					synth.New "UIPadding" {
						PaddingBottom = UDim.new(0, 5),
						PaddingLeft = UDim.new(0, 5),
						PaddingRight = UDim.new(0, 5),
						PaddingTop = UDim.new(0, 5)
					},
					synth.New "UICorner" {
						CornerRadius = UDim.new(0, 4)
					}
				}
			},
			synth.New "Frame" {
				Name = "PlayFrame",
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 1,
				LayoutOrder = 5,
				Size = UDim2.fromScale(1, 0),
				
				[synth.Children] = {
					synth.New "UIListLayout" {
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Center
					},
					synth.New "TextButton" {
						Name = "PlayButton",
						AutomaticSize = Enum.AutomaticSize.XY,
						BackgroundColor3 = Color3.fromRGB(0, 170, 255),
						Font = Enum.Font.Ubuntu,
						Text = "Enter Game",
						TextColor3 = Color3.new(1, 1, 1),
						TextSize = 14,
						
						[synth.Children] = {
							synth.New "UICorner" {
								CornerRadius = UDim.new(0, 4)
							},
							synth.New "UIPadding" {
								PaddingBottom = UDim.new(0, 5),
								PaddingLeft = UDim.new(0, 10),
								PaddingRight = UDim.new(0, 10),
								PaddingTop = UDim.new(0, 5)
							},
							synth.New "UIStroke" {
								ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
								Color = Color3.fromRGB(117, 154, 255)
							}
						}
					}
				}
			}
		}
	}
end

