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

    if not _G.DunkHubState then _G.DunkHubState = {} end
    _G.DunkHubState.AutoPickup = false

    PickupTab:AddToggle("ToggleAutoPickup", {
        Title = "Enable Auto Pickup",
        Default = false,
        Callback = function(Value)
            _G.DunkHubState.AutoPickup = Value
        end
    })

    PickupTab:AddSlider("PickupDistance", {
        Title = "Khoảng cách nhặt (Studs)",
        Min = 10, Max = 100, Default = 40, Rounding = 0,
        Callback = function(Value) PickupRadius = Value end
    })

    PickupTab:AddDropdown("SelectSkills", {
        Title = "Lọc Skill (Có Skill này = Nhặt Ngay)",
        Values = SkillOptions, Multi = true, Default = {},
        Callback = function(Value) SelectedSkills = Value end
    })

    PickupTab:AddDropdown("SelectRarity", {
        Title = "Filter by Rarity",
        Values = Rarities, Multi = true, Default = {},
        Callback = function(Value) SelectedRarities = Value end
    })

    PickupTab:AddDropdown("SelectStats", {
        Title = "Chọn Chỉ Số Cần Lọc",
        Values = StatOptions, Multi = true, Default = {},
        Callback = function(Value) SelectedStats = Value end
    })

    PickupTab:AddSection("Cấu hình % Tối thiểu cho Chỉ Số")

    for _, statName in ipairs(StatOptions) do
        StatMinValues[statName] = 0
        PickupTab:AddInput("Input_" .. statName, {
            Title = "Tối thiểu % cho " .. statName,
            Default = "0", Numeric = true, Finished = false,
            Callback = function(val)
                StatMinValues[statName] = tonumber(val) or 0
            end
        })
    end

    local function passesFilter(model)
        if not model then return false end
        
        local textList = { model.Name }
        for _, desc in pairs(model:GetDescendants()) do
            if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Text and desc.Text ~= "" then
                table.insert(textList, desc.Text)
            end
        end
        for attrName, attrVal in pairs(model:GetAttributes()) do
            table.insert(textList, tostring(attrName) .. " " .. tostring(attrVal))
        end

        local rawText = table.concat(textList, " ")
        local lowerText = string.lower(rawText)

        local hasSkill = false
        for _, v in pairs(SelectedSkills) do if v == true then hasSkill = true break end end

        local hasRarity = false
        for _, v in pairs(SelectedRarities) do if v == true then hasRarity = true break end end

        local hasStat = false
        for _, v in pairs(SelectedStats) do if v == true then hasStat = true break end end

        -- Nếu không bật lọc nào -> Nhặt tất cả
        if not hasSkill and not hasRarity and not hasStat then
            return true
        end

        -- 1. ƯU TIÊN SKILL: Có skill đã chọn là nhặt luôn
        if hasSkill then
            for skillName, enabled in pairs(SelectedSkills) do
                if enabled == true and string.find(lowerText, string.lower(skillName), 1, true) then
                    return true
                end
            end
        end

        -- 2. KẾT HỢP RARITY VÀ STATS (Phải thoả mãn CẢ HAI nếu cùng chọn)
        local rarityMatched = not hasRarity
        if hasRarity then
            for rName, enabled in pairs(SelectedRarities) do
                if enabled == true and string.find(lowerText, string.lower(rName), 1, true) then
                    rarityMatched = true
                    break
                end
            end
        end

        local statMatched = not hasStat
        if hasStat then
            for statName, enabled in pairs(SelectedStats) do
                if enabled == true and string.find(lowerText, string.lower(statName), 1, true) then
                    local minReq = StatMinValues[statName] or 0
                    if minReq <= 0 then
                        statMatched = true
                        break
                    else
                        for valStr in rawText:gmatch("(%d+)%%") do
                            if (tonumber(valStr) or 0) >= minReq then
                                statMatched = true
                                break
                            end
                        end
                    end
                end
            end
        end

        return rarityMatched and statMatched
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

    task.spawn(function()
        while task.wait(0.05) do
            if _G.DunkHubState and _G.DunkHubState.AutoPickup then
                local player = game.Players.LocalPlayer
                local character = player and player.Character
                local hrp = character and character:FindFirstChild("HumanoidRootPart")

                if hrp then
                    for _, obj in pairs(workspace:GetDescendants()) do
                        if obj:IsA("ProximityPrompt") then
                            local itemModel = obj:FindFirstAncestorOfClass("Model") or obj.Parent
                            local targetPart = (obj.Parent and obj.Parent:IsA("BasePart") and obj.Parent) or (itemModel and itemModel:FindFirstChildWhichIsA("BasePart", true))

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
