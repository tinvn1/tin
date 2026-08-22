return function(Window, Fluent)
    local PickupTab = Window:AddTab({ Title = "Auto Pickup", Icon = "shopping-bag" })

    -- Options Data
    local Rarities = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical" }
    local StatOptions = { 
        "Crit Chance", "Crit Damage", "Damage", 
        "Mana Regen", "Gold Bonus", "Luck", 
        "Health", "ReflectDamage", "Slash" 
    }

    -- Settings State
    local SelectedRarities = {}
    local SelectedStats = {}
    local AutoPickupEnabled = false

    -- UI Elements
    PickupTab:AddToggle("ToggleAutoPickup", {
        Title = "Enable Auto Pickup",
        Default = false,
        Callback = function(Value)
            AutoPickupEnabled = Value
        end
    })

    PickupTab:AddDropdown("SelectRarity", {
        Title = "Filter by Rarity",
        Values = Rarities,
        Multi = true,
        Default = {},
        Callback = function(Value)
            SelectedRarities = Value
        end
    })

    PickupTab:AddDropdown("SelectStats", {
        Title = "Filter by Desired Stats",
        Values = StatOptions,
        Multi = true,
        Default = {},
        Callback = function(Value)
            SelectedStats = Value
        end
    })

    -- Pickup Logic Loop
    task.spawn(function()
        while task.wait(0.1) do
            if AutoPickupEnabled then
                for _, item in pairs(workspace:GetChildren()) do
                    if item:FindFirstChild("TouchInterest") or item:IsA("BasePart") then
                        local hrp = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                        if hrp and item:IsA("BasePart") and (item.Position - hrp.Position).Magnitude < 30 then
                            firetouchinterest(hrp, item, 0)
                            firetouchinterest(hrp, item, 1)
                        end
                    end
                end
            end
        end
    end)
end
