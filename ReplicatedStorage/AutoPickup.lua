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
    local PickupRadius = 30

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
        Default = 30,
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

    -- Hàm kiểm tra điều kiện Rarity & Stats
    local function passesFilter(item)
        local textContent = ""
        
        -- Quét thông tin chữ hiển thị trên BillboardGui / SurfaceGui
        for _, descendant in pairs(item:GetDescendants()) do
            if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
                textContent = textContent .. " " .. string.lower(descendant.Text)
            end
        end

        -- Lọc theo Rarity nếu có chọn
        local hasRarityFilter = false
        for _, _ in pairs(SelectedRarities) do hasRarityFilter = true break end

        if hasRarityFilter then
            local matchedRarity = false
            for rarityName, isSelected in pairs(SelectedRarities) do
                if isSelected and string.find(textContent, string.lower(rarityName)) then
                    matchedRarity = true
                    break
                end
            end
            if not matchedRarity then return false end
        end

        -- Lọc theo Stats nếu có chọn
        local hasStatFilter = false
        for _, _ in pairs(SelectedStats) do hasStatFilter = true break end

        if hasStatFilter then
            local matchedStat = false
            for statName, isSelected in pairs(SelectedStats) do
                if isSelected and string.find(textContent, string.lower(statName)) then
                    matchedStat = true
                    break
                end
            end
            if not matchedStat then return false end
        end

        return true
    end

    -- Hàm nhặt vật phẩm bằng ProximityPrompt hoặc Touch
    local function tryPickup(promptOrPart, hrp)
        if promptOrPart:IsA("ProximityPrompt") then
            if promptOrPart.Enabled then
                -- Kích hoạt nút bấm E tự động
                fireproximityprompt(promptOrPart)
            end
        elseif promptOrPart:IsA("BasePart") and promptOrPart:FindFirstChild("TouchInterest") then
            firetouchinterest(hrp, promptOrPart, 0)
            firetouchinterest(hrp, promptOrPart, 1)
        end
    end

    -- Vòng lặp nhặt đồ tự động
    task.spawn(function()
        while task.wait(0.1) do
            if AutoPickupEnabled then
                local player = game.Players.LocalPlayer
                local character = player and player.Character
                local hrp = character and character:FindFirstChild("HumanoidRootPart")

                if hrp then
                    -- Quét tất cả ProximityPrompt có trong Workspace
                    for _, prompt in pairs(workspace:GetDescendants()) do
                        if prompt:IsA("ProximityPrompt") then
                            local parentPart = prompt.Parent
                            if parentPart and parentPart:IsA("BasePart") then
                                local dist = (parentPart.Position - hrp.Position).Magnitude
                                if dist <= PickupRadius then
                                    if passesFilter(parentPart.Parent) or passesFilter(parentPart) then
                                        fireproximityprompt(prompt)
                                    end
                                end
                            else
                                fireproximityprompt(prompt)
                            end
                        end
                    end
                end
            end
        end
    end)
end
