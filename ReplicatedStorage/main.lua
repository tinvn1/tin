local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local Remote = ReplicatedStorage:WaitForChild("RuneWeaponSkillRemote")

-- ==========================================
-- 1. CẤU HÌNH ĐƯỜNG DẪN GITHUB TẢI SKILL DYNAMIC
-- ==========================================
-- Đường dẫn gốc tới folder chứa file skill trên GitHub (Lưu ý dấu / ở cuối)
local GITHUB_BASE_URL = "https://raw.githubusercontent.com/tinvn1/tin/main/ReplicatedStorage/SkillPatterns/"

-- Danh sách tất cả các Skill hiển thị trên Hub GUI
local SkillList = {
    "FireSword",
    "Meteo",
    "PrimeIceSwordV2",
    "StarFire",
    "Summon"
}

-- Mảng lưu trữ dữ liệu cache để không phải tải lại nhiều lần
local LoadedSkillPatterns = {}
local InvalidSkills = {} -- Đánh dấu skill nào tải thất bại/không có dữ liệu
local SpamConfig = {}

for _, skillName in ipairs(SkillList) do
    SpamConfig[skillName] = { Enabled = false, Delay = 0.5 }
end

-- ==========================================
-- 2. KHỞI TẠO GUI ORION LIBRARY
-- ==========================================
local OrionLib = loadstring(game:HttpGet('https://raw.githubusercontent.com/jensonhirst/Orion/main/source'))()

local Window = OrionLib:MakeWindow({
    Name = "Rune Weapon Hub", 
    HidePremium = false, 
    SaveConfig = true,
    ConfigFolder = "RuneWeaponConfig"
})

local SkillTab = Window:MakeTab({ Name = "Auto Skills", Icon = "rbxassetid://4483345998" })
local PlayerTab = Window:MakeTab({ Name = "Player Actions", Icon = "rbxassetid://4483345998" })
local ConfigTab = Window:MakeTab({ Name = "Configuration", Icon = "rbxassetid://4483345998" })

-- ==========================================
-- 3. HÀM TẢI NÉT VẼ DYNAMIC & CAST SKILL
-- ==========================================
local function getCharacterCFrame()
    local character = LocalPlayer.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        return character.HumanoidRootPart.CFrame
    end
    return CFrame.new()
end

-- Hàm lấy pattern: Nếu chưa có thì tải từ GitHub về
local function getOrFetchSkillPattern(skillName)
    if LoadedSkillPatterns[skillName] then
        return LoadedSkillPatterns[skillName]
    end

    if InvalidSkills[skillName] then
        return nil
    end

    local fileUrl = GITHUB_BASE_URL .. skillName .. ".lua"
    local success, result = pcall(function()
        local rawCode = game:HttpGet(fileUrl)
        return loadstring(rawCode)()
    end)

    if success and type(result) == "table" then
        LoadedSkillPatterns[skillName] = result
        OrionLib:MakeNotification({
            Name = "Thành công",
            Content = "Đã tải dữ liệu nét vẽ cho: " .. skillName,
            Time = 2
        })
        return result
    else
        InvalidSkills[skillName] = true
        OrionLib:MakeNotification({
            Name = "Cảnh báo Skill",
            Content = "Không tìm thấy hoặc sai dữ liệu nét vẽ: " .. skillName,
            Time = 4
        })
        return nil
    end
end

local function castSkill(skillName)
    local pattern = getOrFetchSkillPattern(skillName)
    if pattern and Remote then
        local currentCFrame = getCharacterCFrame()
        pcall(function()
            Remote:InvokeServer("TryCast", skillName, pattern, currentCFrame)
        end)
    end
end

local spamThreads = {}
local function setSkillState(skillName, state)
    local config = SpamConfig[skillName]
    if not config then return end

    config.Enabled = state

    if config.Enabled then
        if not spamThreads[skillName] then
            spamThreads[skillName] = task.spawn(function()
                while config.Enabled do
                    castSkill(skillName)
                    task.wait(config.Delay)
                end
                spamThreads[skillName] = nil
            end)
        end
    end
end

-- ==========================================
-- 4. TỰ ĐỘNG TẠO UI TỪ DANH SÁCH SKILL
-- ==========================================
local SkillToggles = {}
local KeyEnumList = {
    Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, 
    Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six, 
    Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine
}
local SkillKeyBinds = {}

SkillTab:AddSection({ Name = "Bật/Tắt Auto Kỹ Năng (" .. #SkillList .. " Skills)" })

for index, skillName in ipairs(SkillList) do
    local keyText = index <= #KeyEnumList and (" [Phím " .. index .. "]") or ""
    
    SkillToggles[skillName] = SkillTab:AddToggle({
        Name = "Auto " .. skillName .. keyText,
        Default = false,
        Save = true,
        Flag = "Toggle_" .. skillName,
        Callback = function(Value) setSkillState(skillName, Value) end
    })

    if index <= #KeyEnumList then
        SkillKeyBinds[KeyEnumList[index]] = skillName
    end
end

SkillTab:AddSection({ Name = "Chỉnh Delay Bằng Tay (Giây)" })

for _, skillName in ipairs(SkillList) do
    SkillTab:AddSlider({
        Name = "Delay " .. skillName,
        Min = 0.1, Max = 5.0, Default = 0.5, Increment = 0.1, ValueName = "s", Save = true, Flag = "Delay_" .. skillName,
        Callback = function(Value)
            if SpamConfig[skillName] then
                SpamConfig[skillName].Delay = Value
            end
        end
    })
end

-- ==========================================
-- 5. CÁC TÍNH NĂNG PLAYER (UNDERGROUND & PLATFORM)
-- ==========================================
local isPlatformActive = false
local createdPlatform = nil
local isUnderground = false
local undergroundOffset = -10

local PlayerToggles = {}

PlayerToggles.Underground = PlayerTab:AddToggle({
    Name = "Ẩn dưới đất (Underground) [Phím Z]",
    Default = false, Save = true, Flag = "Toggle_Underground",
    Callback = function(Value)
        local character = LocalPlayer.Character
        if not character or not character:FindFirstChild("HumanoidRootPart") then return end
        local hrp = character.HumanoidRootPart

        if isUnderground == Value then return end
        isUnderground = Value

        if isUnderground then
            hrp.CFrame = hrp.CFrame * CFrame.new(0, undergroundOffset, 0)
        else
            hrp.CFrame = hrp.CFrame * CFrame.new(0, -undergroundOffset, 0)
        end
    end
})

PlayerToggles.Platform = PlayerTab:AddToggle({
    Name = "Tạo Bệ Đứng (Platform) [Phím X]",
    Default = false, Save = true, Flag = "Toggle_Platform",
    Callback = function(Value)
        local character = LocalPlayer.Character
        if not character or not character:FindFirstChild("HumanoidRootPart") then return end
        local hrp = character.HumanoidRootPart

        if isPlatformActive == Value then return end
        isPlatformActive = Value

        if not isPlatformActive then
            if createdPlatform then
                createdPlatform:Destroy()
                createdPlatform = nil
            end
        else
            local platform = Instance.new("Part")
            platform.Name = "CustomPlayerPlatform"
            platform.Size = Vector3.new(6, 1, 6)
            platform.Anchored = true
            platform.CanCollide = true
            platform.Material = Enum.Material.SmoothPlastic
            platform.Transparency = 0.3
            platform.Color = Color3.fromRGB(0, 170, 255)
            platform.CFrame = hrp.CFrame * CFrame.new(0, -3.5, 0)
            platform.Parent = workspace
            createdPlatform = platform
        end
    end
})

-- ==========================================
-- 6. TAB CẤU HÌNH & XỬ LÝ PHÍM TẮT
-- ==========================================
ConfigTab:AddSection({ Name = "Lưu & Quản Lý Cấu Hình" })
ConfigTab:AddButton({
    Name = "Lưu cấu hình (Save Config)",
    Callback = function()
        pcall(function() OrionLib:SaveConfig() end)
        OrionLib:MakeNotification({ Name = "Thành công", Content = "Đã lưu cài đặt!", Time = 3 })
    end
})

ConfigTab:AddButton({
    Name = "Tải cấu hình đã lưu (Load Config)",
    Callback = function()
        pcall(function() OrionLib:LoadConfig() end)
        OrionLib:MakeNotification({ Name = "Thành công", Content = "Đã tải cấu hình!", Time = 3 })
    end
})

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == Enum.KeyCode.Z then
        PlayerToggles.Underground:Set(not isUnderground)
    elseif input.KeyCode == Enum.KeyCode.X then
        PlayerToggles.Platform:Set(not isPlatformActive)
    else
        local targetSkill = SkillKeyBinds[input.KeyCode]
        if targetSkill and SkillToggles[targetSkill] then
            local currentState = SpamConfig[targetSkill] and SpamConfig[targetSkill].Enabled
            SkillToggles[targetSkill]:Set(not currentState)
        end
    end
end)

OrionLib:Init()
