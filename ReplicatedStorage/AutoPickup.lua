local function passesFilter(model, prompt)
    if not model then return false end

    -- 1. Lấy dữ liệu đã tích chọn từ Fluent UI
    local rawSkills = SelectSkills.Value or {}
    local rawRarities = SelectRarity.Value or {}
    local rawStats = SelectStats.Value or {}

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

    -- 2. Đọc Attribute trực tiếp từ Model hoặc Parent
    local itemTier = tostring(model:GetAttribute("ItemTier") or ""):lower()
    local enchantName = tostring(model:GetAttribute("EnchantName") or ""):lower()
    local enchantVal = tonumber(model:GetAttribute("EnchantValue")) or tonumber(model:GetAttribute("EnchantBaseValue")) or 0
    local skillId = tostring(model:GetAttribute("SkillId") or ""):lower()

    -- Chuỗi tổng hợp để fallback quét nếu cần
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
            -- Kiểm tra xem EnchantName của món đồ có trùng với Stat chọn không
            if enchantName == cleanStat or enchantName:find(cleanStat, 1, true) then
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
