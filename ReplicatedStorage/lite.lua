-- ============================================================
-- RUNE HUB | LITE VERSION (SKILL SPAM ONLY)
-- ============================================================

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local Remote = ReplicatedStorage:WaitForChild("RuneWeaponSkillRemote", 10)

-- ==========================================
-- 1. QUÉT FOLDER SKILL TỪ GITHUB
-- ==========================================
local REPO_OWNER = "tinvn1"
local REPO_NAME = "tin"
local FOLDER_PATH = "ReplicatedStorage/SkillPatterns"
local API_URL = string.format("https://api.github.com/repos/%s/%s/contents/%s", REPO_OWNER, REPO_NAME, FOLDER_PATH)

local SkillList = {}
local SkillDownloadUrls = {}

local function fetchSkillListFromGitHub()
    local success, response = pcall(function() return game:HttpGet(API_URL) end)
    if success and response then
        local decodeSuccess, fileDataList = pcall(function() return HttpService:JSONDecode(response) end)
        if decodeSuccess and type(fileDataList) == "table" then
            for _, fileItem in ipairs(fileDataList) do
                if fileItem.type == "file" and fileItem.name:match("%.lua$") then
                    local skillName = fileItem.name:gsub("%.lua$", "")
                    table.insert(SkillList, skillName)
                    SkillDownloadUrls[skillName] = fileItem.download_url
                end
            end
        end
    end
end
fetchSkillListFromGitHub()

local SkillDropdownOptions = {"None"}
for _, name in ipairs(SkillList) do table.insert(SkillDropdownOptions, name) end

-- ==========================================
-- 2. KHỞI TẠO UI FLUENT
-- ==========================================
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Rune Hub | Lite Version",
    SubTitle = "v1.0 Skill Spam Only",
    TabWidth = 140,
    Size = UDim2.fromOffset(520, 420),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Slots    = Window:AddTab({ Title = "Skill Slots", Icon = "zap" }),
    Keyboard = Window:AddTab({ Title = "Keybinds (PC)", Icon = "keyboard" })
}

-- ==========================================
-- 3. LOGIC XỬ LÝ SKILL
-- ==========================================
local MasterSkillEnabled = true
local LoadedSkillPatterns = {}
local slotThreads = {}

local SlotConfig = {
    [1] = { Skill = "None", AllowSpam = false, Delay = 0.5, Key = Enum.KeyCode.One, IsSpamming = false },
    [2] = { Skill = "None", AllowSpam = false, Delay = 0.5, Key = Enum.KeyCode.Two, IsSpamming = false },
    [3] = { Skill = "None", AllowSpam = false, Delay = 0.5, Key = Enum.KeyCode.Three, IsSpamming = false },
    [4] = { Skill = "None", AllowSpam = false, Delay = 0.5, Key = Enum.KeyCode.Four, IsSpamming = false }
}

local MobileButtons = {}
local MobileMasterBtn = nil

local function getCharacterCFrame()
    if LocalPlayer and LocalPlayer.Character then
        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then return hrp.CFrame end
    end
    if workspace.CurrentCamera then return workspace.CurrentCamera.CFrame end
    return CFrame.new()
end

local function getOrFetchSkillPattern(skillName)
    if skillName == "None" or skillName == "" then return nil end
    if LoadedSkillPatterns[skillName] then return LoadedSkillPatterns[skillName] end
    local rawUrl = SkillDownloadUrls[skillName]
    if not rawUrl then return nil end

    local success, result = pcall(function()
        return loadstring(game:HttpGet(rawUrl))()
    end)
    if success and type(result) == "table" then
        LoadedSkillPatterns[skillName] = result
        return result
    end
    return nil
end

local function castSkillBySlot(slotNum)
    if not MasterSkillEnabled then return end
    local cfg = SlotConfig[slotNum]
    if not cfg or cfg.Skill == "None" then return end
    local pattern = getOrFetchSkillPattern(cfg.Skill)
    if pattern and Remote then
        pcall(function()
            Remote:InvokeServer("TryCast", cfg.Skill, pattern, getCharacterCFrame())
        end)
    end
end

local function toggleSpamSlot(slotNum, state)
    local cfg = SlotConfig[slotNum]
    if not cfg or cfg.Skill == "None" then return end

    if state == nil then cfg.IsSpamming = not cfg.IsSpamming else cfg.IsSpamming = state end

    if cfg.IsSpamming and MasterSkillEnabled then
        if not slotThreads[slotNum] then
            slotThreads[slotNum] = task.spawn(function()
                while cfg.IsSpamming and MasterSkillEnabled and cfg.Skill ~= "None" do
                    castSkillBySlot(slotNum)
                    task.wait(cfg.Delay)
                end
                slotThreads[slotNum] = nil
            end)
        end
    end

    if MobileButtons[slotNum] then
        MobileButtons[slotNum].BackgroundColor3 = (cfg.IsSpamming and MasterSkillEnabled) and Color3.fromRGB(0, 180, 80) or Color3.fromRGB(25, 25, 35)
    end
end

local function handleSkillTrigger(slotNum)
    if not MasterSkillEnabled then return end
    local cfg = SlotConfig[slotNum]
    if not cfg or cfg.Skill == "None" then return end
    if cfg.AllowSpam then toggleSpamSlot(slotNum) else castSkillBySlot(slotNum) end
end

local function setMasterSkillState(state)
    MasterSkillEnabled = state
    if not state then
        for slotNum = 1, 4 do
            SlotConfig[slotNum].IsSpamming = false
            if MobileButtons[slotNum] then
                MobileButtons[slotNum].BackgroundColor3 = Color3.fromRGB(25, 25, 35)
            end
        end
    end
    
    if MobileMasterBtn then
        MobileMasterBtn.Text = state and "SKILL: ON" or "SKILL: OFF"
        MobileMasterBtn.BackgroundColor3 = state and Color3.fromRGB(0, 170, 80) or Color3.fromRGB(180, 40, 40)
    end
end

-- LẮNG NGHE PHÍM TẮT PC
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or not MasterSkillEnabled then return end
    for slotNum, cfg in pairs(SlotConfig) do
        if input.KeyCode == cfg.Key then
            handleSkillTrigger(slotNum)
        end
    end
end)

-- ==========================================
-- 4. DỰNG GIAO DIỆN (UI)
-- ==========================================

-- TAB 1: SKILL SLOTS
Tabs.Slots:AddToggle("MasterSkillToggle", {
    Title = "Bật / Tắt Hệ Thống Skill",
    Default = true,
    Callback = function(Value) setMasterSkillState(Value) end
})

Tabs.Slots:AddSection("Cài Đặt Slot (1 - 4)")
for slot = 1, 4 do
    Tabs.Slots:AddDropdown("SlotDropdown_" .. slot, {
        Title = "Slot " .. slot .. " - Chọn Skill",
        Values = SkillDropdownOptions,
        Default = "None",
        Callback = function(Value)
            SlotConfig[slot].Skill = Value
            if Value == "None" then toggleSpamSlot(slot, false) end
            if MobileButtons[slot] then
                MobileButtons[slot].Visible = (Value ~= "None")
                MobileButtons[slot].Text = string.format("[%d]\n%s", slot, Value)
            end
        end
    })

    Tabs.Slots:AddToggle("SlotSpam_" .. slot, {
        Title = "Bật Auto Spam - Slot " .. slot,
        Default = false,
        Callback = function(Value)
            SlotConfig[slot].AllowSpam = Value
            if not Value then toggleSpamSlot(slot, false) end
        end
    })

    Tabs.Slots:AddSlider("SlotDelay_" .. slot, {
        Title = "Delay Slot " .. slot .. " (Giây)",
        Min = 0.1, Max = 3.0, Default = 0.5, Rounding = 1,
        Callback = function(Value) SlotConfig[slot].Delay = Value end
    })
end

-- TAB 2: KEYBOARD
Tabs.Keyboard:AddSection("Phím Tắt Kích Hoạt (PC)")
for slot = 1, 4 do
    Tabs.Keyboard:AddKeybind("KeybindSlot_" .. slot, {
        Title = "Kích Hoạt Slot " .. slot,
        Mode = "Hold",
        Default = SlotConfig[slot].Key.Name,
        Callback = function(Value)
            if typeof(Value) == "EnumItem" then
                SlotConfig[slot].Key = Value
            elseif type(Value) == "string" and Enum.KeyCode[Value] then
                SlotConfig[slot].Key = Enum.KeyCode[Value]
            end
        end
    })
end

-- ==========================================
-- 5. GIAO DIỆN NÚT MOBILE LITE
-- ==========================================
local function createMobileUI()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    if playerGui:FindFirstChild("MobileSkillGuiLite") then playerGui.MobileSkillGuiLite:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "MobileSkillGuiLite"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui

    local container = Instance.new("Frame")
    container.Size = UDim2.new(0, 280, 0, 110)
    container.Position = UDim2.new(0.5, -140, 0.75, 0)
    container.BackgroundTransparency = 1
    container.Parent = screenGui

    local masterBtn = Instance.new("TextButton")
    masterBtn.Name = "MasterToggleBtn"
    masterBtn.Size = UDim2.new(1, 0, 0, 30)
    masterBtn.Position = UDim2.new(0, 0, 0, 0)
    masterBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 80)
    masterBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    masterBtn.Text = "SKILL: ON"
    masterBtn.Font = Enum.Font.SourceSansBold
    masterBtn.TextSize = 14
    masterBtn.Parent = container

    local masterCorner = Instance.new("UICorner")
    masterCorner.CornerRadius = UDim.new(0, 6)
    masterCorner.Parent = masterBtn

    MobileMasterBtn = masterBtn

    masterBtn.MouseButton1Click:Connect(function()
        local newState = not MasterSkillEnabled
        if Fluent.Options.MasterSkillToggle then
            Fluent.Options.MasterSkillToggle:SetValue(newState)
        else
            setMasterSkillState(newState)
        end
    end)

    for slot = 1, 4 do
        local btn = Instance.new("TextButton")
        btn.Name = "SkillBtn_" .. slot
        btn.Size = UDim2.new(0, 60, 0, 60)
        btn.Position = UDim2.new(0, (slot - 1) * 70, 0, 40)
        btn.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextScaled = true
        btn.Font = Enum.Font.SourceSansBold
        btn.Visible = false
        btn.Parent = container

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = btn

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(0, 170, 255)
        stroke.Thickness = 2
        stroke.Parent = btn

        MobileButtons[slot] = btn
        btn.MouseButton1Click:Connect(function() handleSkillTrigger(slot) end)
    end
end

task.spawn(createMobileUI)

Fluent:Notify({
    Title = "Rune Hub Lite",
    Content = "Đã tải thành công bản Lite chuyên Spam Skill!",
    Duration = 4
})
