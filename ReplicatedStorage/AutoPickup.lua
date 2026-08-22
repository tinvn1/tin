return function(Window, Fluent, sessionID)
    local PickupTab = Window:AddTab({ Title = "Auto Pickup", Icon = "shopping-bag" })

    -- Danh sách chỉ số chuẩn
    local Rarities = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical" }
    local StatOptions = { 
        "Crit Chance", "Crit Damage", "Damage", 
        "Mana Regen", "Gold Bonus", "Luck", 
        "Health", "Reflect Damage", "Slash", "Damage Reduction", "Immunity Chance"
    }

    local SelectedRarities = {}
    local SelectedStats = {}
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
        Title = "Filter by Rarity (Để trống = Bỏ qua)",
        Values = Rarities,
        Multi = true,
        Default = {},
        Callback = function(Value)
            SelectedRarities = Value
        end
    })

    PickupTab:AddDropdown("SelectStats", {
        Title = "Filter by Stats (BẮT BUỘC TRÙNG CHỈ SỐ)",
        Values = StatOptions,
        Multi = true,
        Default = {},
        Callback = function(Value)
            SelectedStats = Value
        end
    })

    -- Hàm làm sạch chuỗi (xóa khoảng trắng, ký tự đặc biệt, chuyển chữ thường)
    local function cleanString(str)
        if not str then return "" end
        return string.lower(string.gsub(tostring(str), "[%s%p]", ""))
    end

    -- Logic kiểm tra lọc chính xác
    local function passesFilter(itemModel)
        if not itemModel then return false end

        -- Gom toàn bộ chữ từ Billboard, TextLabel, Name, Attributes
        local rawText = itemModel.Name .. " "
        
        for _, v in pairs(itemModel:GetDescendants()) do
            if v:IsA("TextLabel") or v:IsA("TextButton") then
                rawText = rawText .. " " .. v.Text
            end
        end

        for attrName, attrVal in pairs(itemModel:GetAttributes()) do
            rawText = rawText .. " " .. tostring(attrName) .. " " .. tostring(attrVal)
        end

        local cleanedItemText = cleanString(rawText)

        -- 1. Lọc theo Rarity (Nếu có chọn)
        local activeRarities = {}
        for rName, enabled in pairs(SelectedRarities) do
            if enabled then
                table.insert(activeRarities, cleanString(rName))
            end
        end

        if #activeRarities > 0 then
            local matchRarity = false
            for _, cleanRarity in ipairs(activeRarities) do
                if string.find(cleanedItemText, cleanRarity) then
                    matchRarity = true
                    break
                end
            end
            if not matchRarity then return false end
        end

        -- 2. Lọc theo Stat (Nếu có chọn)
        local activeStats = {}
        for sName, enabled in pairs(SelectedStats) do
            if enabled then
                table.insert(activeStats, cleanString(sName))
            end
        end

        if #activeStats > 0 then
            local matchStat = false
            for _, cleanStat in ipairs(activeStats) do
                if string.find(cleanedItemText, cleanStat) then
                    matchStat = true
                    break
                end
            end
            if not matchStat then return false end
        end

        return true
    end

    -- Hàm kích hoạt nút Pick Up (E)
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

    -- Vòng lặp nhặt đồ
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
