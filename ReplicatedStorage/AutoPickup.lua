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

        local SelectSkills = PickupTab:AddDropdown("SelectSkills", {
            Title = "Lọc Skill (Có Skill này = Nhặt Ngay)",
            Values = SkillOptions, Multi = true, Default = {}
        })

        local SelectRarity = PickupTab:AddDropdown("SelectRarity", {
            Title = "Filter by Rarity",
            Values = Rarities, Multi = true, Default = {}
        })

        local SelectStats = PickupTab:AddDropdown("SelectStats", {
            Title = "Chọn Chỉ Số Cần Lọc",
            Values = StatOptions, Multi = true, Default = {}
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

        local function passesFilter(model, prompt)
            if not model then return false end

            -- 1. Lấy dữ liệu đã tích chọn từ Fluent UI chuẩn xác
            local rawSkills = (SelectSkills and SelectSkills.Value) or {}
            local rawRarities = (SelectRarity and SelectRarity.Value) or {}
            local rawStats = (SelectStats and SelectStats.Value) or {}

            local activeSkills = {}
            for name, enabled in pairs(rawSkills) do
                if enabled == true then table.insert(activeSkills, string.lower(name)) end
            end

            local activeRarities = {}
            for name, enabled in pairs(rawRarities) do
                if enabled == true then table.insert(activeRarities, string.lower(name)) end
            end

            local activeStats = {}
            for name, enabled in pairs(rawStats) do
                if enabled == true then table.insert(activeStats, name) end
            end

            -- Nếu không tích cái nào -> Nhặt hết
            if #activeSkills == 0 and #activeRarities == 0 and #activeStats == 0 then
                return true
            end

            -- 2. Đọc Attribute từ ảnh Studio
            local itemTier = tostring(model:GetAttribute("ItemTier") or ""):lower()
            local enchantName = tostring(model:GetAttribute("EnchantName") or ""):lower()
            local enchantVal = tonumber(model:GetAttribute("EnchantValue")) or tonumber(model:GetAttribute("EnchantBaseValue")) or 0
            local skillId = tostring(model:GetAttribute("SkillId") or ""):lower()

            local fullModelName = (model.Name .. " " .. (prompt and prompt.ObjectText or "")):lower()

            -- 3. ĐIỀU KIỆN 1: ƯU TIÊN SKILL
            if #activeSkills > 0 then
                for _, skillName in ipairs(activeSkills) do
                    if skillId:find(skillName, 1, true) or fullModelName:find(skillName, 1, true) then
                        return true
                    end
                end
            end

            -- 4. ĐIỀU KIỆN 2: LỌC RARITY
            local rarityPassed = true
            if #activeRarities > 0 then
                rarityPassed = false
                for _, rName in ipairs(activeRarities) do
                    if itemTier == rName or fullModelName:find(rName, 1, true) then
                        rarityPassed = true
                        break
                    end
                end
            end

            -- 5. ĐIỀU KIỆN 3: LỌC STATS & %
            local statPassed = true
            if #activeStats > 0 then
                statPassed = false
                for _, statName in ipairs(activeStats) do
                    local cleanStat = string.lower(statName)
                    if enchantName == cleanStat or enchantName:find(cleanStat, 1, true) or fullModelName:find(cleanStat, 1, true) then
                        local minReq = StatMinValues[statName] or 0
                        if enchantVal >= minReq then
                            statPassed = true
                            break
                        end
                    end
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
                                    local ok, filterResult = pcall(function()
                                        return passesFilter(itemModel, obj)
                                    end)
                                    if ok and filterResult then
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
