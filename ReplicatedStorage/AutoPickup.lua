return function(Window, Fluent, sessionID)
    local PickupTab = Window:AddTab({ Title = "Auto Pickup", Icon = "shopping-bag" })

    -- Danh sách Rarity & Stats
    local Rarities = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical" }
    local StatOptions = { 
        "Crit Chance", "Crit Damage", "Damage", 
        "Mana Regen", "Gold Bonus", "Luck", 
        "Health", "ReflectDamage", "Slash" 
    }

    -- Danh sách Chiêu thức (Skills) trích xuất từ Inventory
    local SkillOptions = {
        "Star Fire", "Whirl Pool", "Summon", "Meteo",
        "Prime Ice Sword", "Ice Sword", "Lighting Staff",
        "Pistol", "Rock Dragon", "Immunity", "Fire Sword",
        "Health", "Ring Water", "Armor Water", "Slash"
    }

    -- State lưu cấu hình
    local SelectedRarities = {}
    local SelectedStats = {}
    local SelectedSkills = {}
    local PickupRadius = 40

    -- UI Controls
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
        Title = "Filter by Rarity (Trống = Bỏ qua)",
        Values = Rarities,
        Multi = true,
        Default = {},
        Callback = function(Value)
            SelectedRarities = Value
        end
    })

    PickupTab:AddDropdown("SelectStats", {
        Title = "Filter by Stats (Trống = Bỏ qua)",
        Values = StatOptions,
        Multi = true,
        Default = {},
        Callback = function(Value)
            SelectedStats = Value
        end
    })

    PickupTab:AddDropdown("SelectSkills", {
        Title = "Filter by Skill Name (Trống = Bỏ qua)",
        Values = SkillOptions,
        Multi = true,
        Default = {},
        Callback = function(Value)
            SelectedSkills = Value
        end
    })

    -- Logic kiểm tra bộ lọc
    local function passesFilter(itemModel)
        if not itemModel then return false end

        -- Gom toàn bộ Text từ TextLabel, TextButton, Name và Attributes
        local textData = string.lower(itemModel.Name) .. " "
        
        for _, v in pairs(itemModel:GetDescendants()) do
            if v:IsA("TextLabel") or v:IsA("TextButton") then
                textData = textData .. " " .. string.lower(v.Text)
            end
        end

        for attrName, attrVal in pairs(itemModel:GetAttributes()) do
            textData = textData .. " " .. string.lower(tostring(attrName)) .. " " .. string.lower(tostring(attrVal))
        end

        -- 1. Kiểm tra Lọc Rarity
        local reqRarities = {}
        for rName, enabled in pairs(SelectedRarities) do
            if enabled then table.insert(reqRarities, string.lower(rName)) end
        end

        if #reqRarities > 0 then
            local matched = false
            for _, r in ipairs(reqRarities) do
                if string.find(textData, r) then matched = true break end
            end
            if not matched then return false end
        end

        -- 2. Kiểm tra Lọc Stats
        local reqStats = {}
        for sName, enabled in pairs(SelectedStats) do
            if enabled then table.insert(reqStats, string.lower(sName)) end
        end

        if #reqStats > 0 then
            local matched = false
            for _, s in ipairs(reqStats) do
                if string.find(textData, s) then matched = true break end
            end
            if not matched then return false end
        end

        -- 3. Kiểm tra Lọc Chiêu Thức (Skill)
        local reqSkills = {}
        for skillName, enabled in pairs(SelectedSkills) do
            if enabled then table.insert(reqSkills, string.lower(skillName)) end
        end

        if #reqSkills > 0 then
            local matched = false
            for _, sk in ipairs(reqSkills) do
                if string.find(textData, sk) then matched = true break end
            end
            if not matched then return false end
        end

        return true
    end

    -- Hàm kích hoạt ProximityPrompt
    local function triggerPrompt(prompt)
        if not prompt or not prompt.Enabled then return end
        local origHold = prompt.HoldDuration
        prompt.HoldDuration = 0

        pcall(function() fireproximityprompt(prompt) end)
        pcall(function()
            if prompt.InputHoldBegin then
                prompt:InputHoldBegin()
                task.wait(0.01)
                prompt:InputHoldEnd()
            end
        end)

        prompt.HoldDuration = origHold
    end

    -- Vòng lặp tự động nhặt
    task.spawn(function()
        while task.wait(0.05) do
            if _G.DunkHubSession ~= sessionID then break end

            if _G.DunkHubState.AutoPickup then
                local player = game.Players.LocalPlayer
                local character = player and player.Character
                local hrp = character and character:FindFirstChild("HumanoidRootPart")

                if hrp then
                    for _, obj in pairs(workspace:GetDescendants()) do
                        if obj:IsA("ProximityPrompt") then
                            local itemModel = obj:FindFirstAncestorOfClass("Model") or obj.Parent
                            local part = obj.Parent:IsA("BasePart") and obj.Parent or hrp

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
