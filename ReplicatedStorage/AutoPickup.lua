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
        Title = "Lọc Rarity",
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

    local function passesFilter(itemModel)
        if not itemModel then return false end

        local rawText = itemModel.Name .. " "
        for _, desc in pairs(itemModel:GetDescendants()) do
            if desc:IsA("TextLabel") or desc:IsA("TextButton") then
                rawText = rawText .. " " .. desc.Text
            end
        end
        for attrName, attrVal in pairs(itemModel:GetAttributes()) do
            rawText = rawText .. " " .. tostring(attrName) .. " " .. tostring(attrVal)
        end

        local lowerText = string.lower(rawText)

        -- 1. ƯU TIÊN SKILL
        for skillName, enabled in pairs(SelectedSkills) do
            if enabled then
                local cleanSkill = string.lower(string.gsub(skillName, "%s+", ""))
                local cleanFull = string.lower(string.gsub(rawText, "%s+", ""))
                if string.find(cleanFull, cleanSkill, 1, true) then
                    return true
                end
            end
        end

        -- 2. LỌC STATS & % TỐI THIỂU
        for statName, enabled in pairs(SelectedStats) do
            if enabled then
                local cleanStatKey = string.lower(string.gsub(statName, "%s+", ""))
                local cleanFullText = string.lower(string.gsub(rawText, "%s+", ""))

                if string.find(cleanFullText, cleanStatKey, 1, true) then
                    local minReq = StatMinValues[statName] or 0
                    if minReq <= 0 then
                        return true
                    end

                    for valStr in rawText:gmatch("%+?%s*(%d+)%%") do
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

        local hasAnyFilter = false
        for _, v in pairs(SelectedSkills) do if v then hasAnyFilter = true break end end
        for _, v in pairs(SelectedStats) do if v then hasAnyFilter = true break end end
        for _, v in pairs(SelectedRarities) do if v then hasAnyFilter = true break end end

        return not hasAnyFilter
    end

    -- HÀM KÍCH HOẠT MỚI: DÙNG NHIỀU CÁCH ĐỂ BẮT GAME PHẢI NHẶT
    local function triggerPrompt(prompt)
        if not prompt or not prompt.Enabled then return end

        -- Cách 1: Gọi hàm gốc của Executor
        if fireproximityprompt then
            pcall(function() fireproximityprompt(prompt) end)
        end

        -- Cách 2: Bấm phím E ảo bằng VirtualInputManager
        pcall(function()
            Vim:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            task.wait(0.02)
            Vim:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        end)

        -- Cách 3: Trigger sự kiện trực tiếp của ProximityPrompt
        pcall(function()
            if prompt.InputHoldBegin then
                prompt:InputHoldBegin()
                prompt:InputHoldEnd()
            end
        end)
    end

    -- VÒNG LẶP CHÍNH
    task.spawn(function()
        while task.wait(0.1) do
            if _G.DunkHubSession ~= sessionID then break end

            if _G.DunkHubState.AutoPickup then
                local player = game.Players.LocalPlayer
                local character = player and player.Character
                local hrp = character and character:FindFirstChild("HumanoidRootPart")

                if hrp then
                    for _, obj in pairs(workspace:GetDescendants()) do
                        if obj:IsA("ProximityPrompt") then
                            local itemModel = obj:FindFirstAncestorOfClass("Model") or obj.Parent
                            local part = obj.Parent:IsA("BasePart") and obj.Parent or obj.Parent:FindFirstChildWhichIsA("BasePart") or hrp

                            if itemModel and (part.Position - hrp.Position).Magnitude <= PickupRadius then
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
