return function(Window, Fluent)
    local PickupTab = Window:AddTab({ Title = "Auto Pickup", Icon = "shopping-bag" })

    local Rarities = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical" }
    local StatOptions = { 
        "Crit Chance", "Crit Damage", "Damage", 
        "Mana Regen", "Gold Bonus", "Luck", 
        "Health", "ReflectDamage", "Slash" 
    }

    local SelectedRarities = {}
    local SelectedStats = {}
    local PickupRadius = 40

    PickupTab:AddToggle("ToggleAutoPickup", {
        Title = "Enable Auto Pickup",
        Default = false,
        Callback = function(Value)
            _G.DunkHubState.AutoPickup = Value
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

    local function passesFilter(model)
        if not model then return false end
        local fullText = ""
        
        for _, desc in pairs(model:GetDescendants()) do
            if desc:IsA("TextLabel") or desc:IsA("TextButton") then
                fullText = fullText .. " " .. string.lower(desc.Text)
            end
        end

        for attrName, attrVal in pairs(model:GetAttributes()) do
            fullText = fullText .. " " .. string.lower(tostring(attrName)) .. " " .. string.lower(tostring(attrVal))
        end

        local activeRarities = {}
        for rarity, state in pairs(SelectedRarities) do
            if state == true then table.insert(activeRarities, string.lower(rarity)) end
        end

        if #activeRarities > 0 then
            local matchRarity = false
            for _, rName in ipairs(activeRarities) do
                if string.find(fullText, rName) then matchRarity = true break end
            end
            if not matchRarity then return false end
        end

        local activeStats = {}
        for stat, state in pairs(SelectedStats) do
            if state == true then table.insert(activeStats, string.lower(stat)) end
        end

        if #activeStats > 0 then
            local matchStat = false
            for _, sName in ipairs(activeStats) do
                if string.find(fullText, sName) then matchStat = true break end
            end
            if not matchStat then return false end
        end

        return true
    end

    local function triggerPrompt(prompt)
        if not prompt then return end
        
        -- Bypass các giới hạn của Game ép ProximityPrompt kích hoạt ngay lập tức
        prompt.HoldDuration = 0
        prompt.RequiresLineOfSight = false
        prompt.MaxActivationDistance = math.huge
        prompt.Enabled = true

        if fireproximityprompt then
            pcall(function() fireproximityprompt(prompt) end)
        else
            pcall(function()
                if prompt.InputHoldBegin then
                    prompt:InputHoldBegin()
                    task.wait(0.01)
                    prompt:InputHoldEnd()
                end
            end)
        end
    end

    -- Vòng lặp tự động hủy nếu script bị load lại
    task.spawn(function()
        while task.wait(0.05) do
            if not _G.DunkHubLoaded then break end

            if _G.DunkHubState and _G.DunkHubState.AutoPickup then
                local player = game.Players.LocalPlayer
                local character = player and player.Character
                local hrp = character and character:FindFirstChild("HumanoidRootPart")

                if hrp then
                    for _, obj in pairs(workspace:GetDescendants()) do
                        if obj:IsA("ProximityPrompt") then
                            local itemModel = obj:FindFirstAncestorOfClass("Model") or obj.Parent
                            
                            -- Tìm vị trí Part thực tế của món đồ để đo khoảng cách
                            local targetPart = nil
                            if obj.Parent and obj.Parent:IsA("BasePart") then
                                targetPart = obj.Parent
                            elseif itemModel then
                                targetPart = itemModel:FindFirstChildWhichIsA("BasePart", true)
                            end

                            if targetPart and (targetPart.Position - hrp.Position).Magnitude <= PickupRadius then
                                if passesFilter(itemModel) then
                                    triggerPrompt(obj)
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
end
