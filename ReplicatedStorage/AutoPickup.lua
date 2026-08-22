return function(Window, Fluent)
    if not Window or not Fluent then return end

    local success, err = pcall(function()
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

            local rawText = table.concat(textList, " \n ")
            local lowerText = string.lower(rawText)

            local activeSkills = {}
            for k, v in pairs(SelectedSkills) do if v == true then table.insert(activeSkills, string.lower(k)) end end

            local activeRarities = {}
            for k, v in pairs(SelectedRarities) do if v == true then table.insert(activeRarities, string.lower(k)) end end

            local activeStats = {}
            for k, v in pairs(SelectedStats) do if v == true then table.insert(activeStats, k) end end

            if #activeSkills == 0 and #activeRarities == 0 and #activeStats == 0 then
                return true
            end

            -- 1. Ưu tiên Skill
            if #activeSkills > 0 then
                for _, skillName in ipairs(activeSkills) do
                    if string.find(lowerText, skillName, 1, true) then
                        return true
                    end
                end
            end

            -- 2. Lọc Rarity
            local rarityPassed = true
            if #activeRarities > 0 then
                rarityPassed = false
                for _, rName in ipairs(activeRarities) do
                    if string.find(lowerText, rName, 1, true) then
                        rarityPassed = true
                        break
                    end
                end
            end

            -- 3. Lọc Stat & %
            local statPassed = true
            if #activeStats > 0 then
                statPassed = false
                for _, statName in ipairs(activeStats) do
                    local cleanStat = string.lower(statName)
                    if string.find(lowerText, cleanStat, 1, true) then
                        local minReq = StatMinValues[statName] or 0
                        if minReq <= 0 then
                            statPassed = true
                            break
                        else
                            for line in lowerText:gmatch("[^\r\n]+") do
                                if string.find(line, cleanStat, 1, true) then
                                    local num = line:match("(%d+)%%") or line:match("(%d+)")
                                    if num and tonumber(num) >= minReq then
                                        statPassed = true
                                        break
                                    end
                                end
                            end
                        end
                    end
                    if statPassed then break end
                end
            end

            return rarityPassed and statPassed
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
    end)

    if not success then
        warn("[AutoPickup Error]: " .. tostring(err))
    end
end
