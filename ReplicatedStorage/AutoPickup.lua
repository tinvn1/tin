return function(Window, Fluent, sessionID)
    local PickupTab = Window:AddTab({ Title = "Auto Pickup", Icon = "shopping-bag" })
    local Vim = game:GetService("VirtualInputManager")

    local Rarities = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical" }
    local StatOptions = { 
        "Damage", "Health", "Crit Chance", "Crit Damage", 
        "Mana Regen", "Gold Bonus", "Luck", "Reflect", "Slash", "Immunity"
    }
    local SkillOptions = {
        "Star Fire", "Whirl Pool", "Summon", "Meteo",
        "Prime Ice Sword", "Ice Sword", "Lighting Staff",
        "Pistol", "Rock Dragon", "Immunity", "Fire Sword",
        "Health", "Ring Water", "Armor Water", "Slash"
    }

    local SelectedRarities = {}
    local SelectedSkills = {}
    local SelectedStats = {}
    local StatMinValues = {}
    local DynamicInputUI = {}
    local PickupRadius = 50

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
        Default = 50,
        Rounding = 0,
        Callback = function(Value)
            PickupRadius = Value
        end
    })

    PickupTab:AddDropdown("SelectSkills", {
        Title = "Lọc Skill (Thấy là nhặt luôn)",
        Values = SkillOptions,
        Multi = true,
        Default = {},
        Callback = function(Value)
            SelectedSkills = Value
        end
    })

    PickupTab:AddDropdown("SelectRarity", {
        Title = "Lọc Rarity (Nhặt mọi đồ phẩm chất này)",
        Values = Rarities,
        Multi = true,
        Default = {},
        Callback = function(Value)
            SelectedRarities = Value
        end
    })

    PickupTab:AddSection("Cấu hình Chỉ Số (%)")

    PickupTab:AddDropdown("SelectStats", {
        Title = "Chọn Chỉ Số Cần Lọc",
        Values = StatOptions,
        Multi = true,
        Default = {},
        Callback = function(Value)
            SelectedStats = Value

            for statName, isSelected in pairs(Value) do
                if isSelected then
                    if not DynamicInputUI[statName] then
                        StatMinValues[statName] = 0
                        DynamicInputUI[statName] = PickupTab:AddInput("Input_" .. statName, {
                            Title = "Tối thiểu % cho " .. statName,
                            Default = "0",
                            Numeric = true,
                            Finished = false,
                            Callback = function(val)
                                StatMinValues[statName] = tonumber(val) or 0
                            end
                        })
                    end
                else
                    if DynamicInputUI[statName] then
                        pcall(function() DynamicInputUI[statName]:Destroy() end)
                        DynamicInputUI[statName] = nil
                        StatMinValues[statName] = nil
                    end
                end
            end
        end
    })

    -- KIỂM TRA ĐIỀU KIỆN LỌC
    local function passesFilter(item)
        if not item then return false end

        -- Lấy toàn bộ văn bản hiển thị từ ItemDropGui / Model
        local rawText = item.Name .. " "
        for _, desc in pairs(item:GetDescendants()) do
            if desc:IsA("TextLabel") or desc:IsA("TextButton") then
                rawText = rawText .. " " .. desc.Text
            end
        end

        local lowerText = string.lower(rawText)
        local cleanFullText = string.gsub(lowerText, "%s+", "")

        -- 1. LỌC SKILL
        for skillName, enabled in pairs(SelectedSkills) do
            if enabled then
                local cleanSkill = string.lower(string.gsub(skillName, "%s+", ""))
                if string.find(cleanFullText, cleanSkill, 1, true) then
                    return true
                end
            end
        end

        -- 2. LỌC STATS & %
        for statName, enabled in pairs(SelectedStats) do
            if enabled then
                local cleanStatKey = string.lower(string.gsub(statName, "%s+", ""))
                if string.find(cleanFullText, cleanStatKey, 1, true) then
                    local minReq = StatMinValues[statName] or 0
                    if minReq <= 0 then
                        return true
                    end

                    for valStr in rawText:gmatch("(%d+)%%") do
                        local numVal = tonumber(valStr)
                        if numVal and numVal >= minReq then
                            return true
                        end
                    end
                end
            end
        end

        -- 3. LỌC RARITY
        for rName, enabled in pairs(SelectedRarities) do
            if enabled then
                if string.find(lowerText, string.lower(rName), 1, true) then
                    return true
                end
            end
        end

        -- Nếu không bật bộ lọc nào -> Nhặt tất cả
        local hasAnyFilter = false
        for _, v in pairs(SelectedSkills) do if v then hasAnyFilter = true break end end
        for _, v in pairs(SelectedStats) do if v then hasAnyFilter = true break end end
        for _, v in pairs(SelectedRarities) do if v then hasAnyFilter = true break end end

        return not hasAnyFilter
    end

    -- THỰC THI NHẶT ĐỒ
    local function triggerPickup(prompt)
        if not prompt then return end

        if fireproximityprompt then
            pcall(function() fireproximityprompt(prompt) end)
        end

        pcall(function()
            Vim:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            task.wait(0.01)
            Vim:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        end)
    end

    -- VÒNG LẶP DÒ QUÉT TẬP TRUNG VÀO WORKSPACE.ITEMDROP
    task.spawn(function()
        while task.wait(0.05) do
            if _G.DunkHubSession ~= sessionID then break end

            if _G.DunkHubState.AutoPickup then
                local player = game.Players.LocalPlayer
                local character = player and player.Character
                local hrp = character and character:FindFirstChild("HumanoidRootPart")
                local itemDropFolder = workspace:FindFirstChild("itemdrop")

                if hrp and itemDropFolder then
                    for _, item in pairs(itemDropFolder:GetChildren()) do
                        local part = item:IsA("BasePart") and item or item:FindFirstChildWhichIsA("BasePart") or item:FindFirstChild("PrimaryPart")

                        if part and (part.Position - hrp.Position).Magnitude <= PickupRadius then
                            if passesFilter(item) then
                                local prompt = item:FindFirstChildWhichIsA("ProximityPrompt", true)
                                if prompt and prompt.Enabled then
                                    triggerPickup(prompt)
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
end
