return function(Window, Fluent)
    local PickupTab = Window:AddTab({ Title = "Auto Pickup", Icon = "shopping-bag" })

    local Rarities = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical" }
    local StatOptions = { 
        "Crit Chance", "Crit Damage", "Damage", 
        "Mana Regen", "Gold Bonus", "Luck", 
        "Health", "ReflectDamage", "Slash", "Immunity"
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
        Title = "Filter by Rarity (Để trống = Nhặt tất cả)",
        Values = Rarities,
        Multi = true,
        Default = {},
        Callback = function(Value)
            SelectedRarities = Value
        end
    })

    PickupTab:AddDropdown("SelectStats", {
        Title = "Chọn Chỉ Số Cần Lọc",
        Values = StatOptions,
        Multi = true,
        Default = {},
        Callback = function(Value)
            SelectedStats = Value
        end
    })

    PickupTab:AddSection("Cấu hình % Tối thiểu cho Chỉ Số")

    -- Tạo sẵn Input % cho từng Stat để tránh lỗi Dynamic UI của Fluent
    for _, statName in ipairs(StatOptions) do
        StatMinValues[statName] = 0
        PickupTab:AddInput("Input_" .. statName, {
            Title = "Tối thiểu % cho " .. statName,
            Default = "0",
            Numeric = true,
            Finished = false,
            Callback = function(val)
                StatMinValues[statName] = tonumber(val) or 0
            end
        })
    end

    local function passesFilter(model)
        if not model then return false end
        
        local rawText = model.Name .. " "
        for _, desc in pairs(model:GetDescendants()) do
            if desc:IsA("TextLabel") or desc:IsA("TextButton") then
                rawText = rawText .. " " .. desc.Text
            end
        end

        for attrName, attrVal in pairs(model:GetAttributes()) do
            rawText = rawText .. " " .. tostring(attrName) .. " " .. tostring(attrVal)
        end

        local lowerText = string.lower(rawText)
        local cleanFullText = string.gsub(lowerText, "%s+", "")

        -- 1. ƯU TIÊN LỌC SKILL
        for skillName, enabled in pairs(SelectedSkills) do
            if enabled then
                local cleanSkill = string.lower(string.gsub(skillName, "%s+", ""))
                if string.find(cleanFullText, cleanSkill, 1, true) then
                    return true
                end
            end
        end

        -- 2. LỌC CHỈ SỐ (%)
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

        -- Nếu không chọn bộ lọc nào -> Nhặt tất cả
        local hasAnyFilter = false
        for _, v in pairs(SelectedSkills) do if v then hasAnyFilter = true break end end
        for _, v in pairs(SelectedStats) do if v then hasAnyFilter = true break end end
        for _, v in pairs(SelectedRarities) do if v then hasAnyFilter = true break end end

        return not hasAnyFilter
    end

    local function triggerPrompt(prompt)
        if not prompt then return end
        
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

    -- Vòng lặp tự động nhặt đồ
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
