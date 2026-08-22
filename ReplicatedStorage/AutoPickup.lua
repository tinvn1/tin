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
    local PickupRadius = 40

    -- UI Elements
    PickupTab:AddToggle("ToggleAutoPickup", {
        Title = "Enable Auto Pickup",
        Default = false,
        Callback = function(Value)
            AutoPickupEnabled = Value
        end
    })

    PickupTab:AddSlider("PickupDistance", {
        Title = "Khoảng cách nhặt (Studs)",
        Min = 10,
        Max = 100,
        Default = 40,
        Rounding = 0,
        Callback = function(Value)
            PickupRadius = Value
        end
    })

    PickupTab:AddDropdown("SelectRarity", {
        Title = "Filter by Rarity (Để trống = Nhặt tất cả)",
        Values = Rarities,
        Multi = true,
        Default = {},
        Callback = function(Value)
            SelectedRarities = Value
        end
    })

    PickupTab:AddDropdown("SelectStats", {
        Title = "Filter by Desired Stats (Để trống = Nhặt tất cả)",
        Values = StatOptions,
        Multi = true,
        Default = {},
        Callback = function(Value)
            SelectedStats = Value
        end
    })

    -- Hàm ép buộc kích hoạt ProximityPrompt (Bypass triệt để)
    local function forceTriggerPrompt(prompt)
        if not prompt or not prompt.Enabled then return end

        -- Bỏ qua thời gian giữ phím E
        local originalHold = prompt.HoldDuration
        prompt.HoldDuration = 0

        -- Kích hoạt theo 3 cách song song
        pcall(function() fireproximityprompt(prompt) end)
        
        pcall(function()
            if prompt.InputHoldBegin then
                prompt:InputHoldBegin()
                task.wait(0.02)
                prompt:InputHoldEnd()
            end
        end)

        prompt.HoldDuration = originalHold
    end

    -- Vòng lặp nhặt đồ
    task.spawn(function()
        while task.wait(0.05) do
            if AutoPickupEnabled then
                local player = game.Players.LocalPlayer
                local character = player and player.Character
                local hrp = character and character:FindFirstChild("HumanoidRootPart")

                if hrp then
                    for _, obj in pairs(workspace:GetDescendants()) do
                        if obj:IsA("ProximityPrompt") then
                            local part = obj.Parent
                            if part and part:IsA("BasePart") then
                                local dist = (part.Position - hrp.Position).Magnitude
                                if dist <= PickupRadius then
                                    forceTriggerPrompt(obj)
                                end
                            else
                                forceTriggerPrompt(obj)
                            end
                        end
                    end
                end
            end
        end
    end)
end
