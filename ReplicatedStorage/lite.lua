-- ============================================================
-- RUNE HUB | LITE VERSION (CAST SKILL ONLY + AUTO SAVE/LOAD)
-- ============================================================

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local Remote = ReplicatedStorage:WaitForChild("RuneWeaponSkillRemote", 10)

-- ==========================================
-- 0. QUẢN LÝ AUTO SAVE / LOAD WORKSPACE
-- ==========================================
local FolderName = "RuneHub"
local ConfigFile = string.format("%s/SkillConfig_%d.json", FolderName, game.PlaceId)

if isfolder and not isfolder(FolderName) then
    makefolder(FolderName)
end

local SlotConfig = {
    [1] = { Skill = "None", Key = Enum.KeyCode.One },
    [2] = { Skill = "None", Key = Enum.KeyCode.Two },
    [3] = { Skill = "None", Key = Enum.KeyCode.Three },
    [4] = { Skill = "None", Key = Enum.KeyCode.Four }
}
local MasterSkillEnabled = true

local function SaveConfiguration()
    if not writefile then return end
    local saveData = {
        MasterSkillEnabled = MasterSkillEnabled,
        Slots = {}
    }
    for slot = 1, 4 do
        saveData.Slots[tostring(slot)] = {
            Skill = SlotConfig[slot].Skill,
            Key = SlotConfig[slot].Key.Name
        }
    end
    pcall(function()
        writefile(ConfigFile, HttpService:JSONEncode(saveData))
    end)
end

local function LoadConfiguration()
    if not isfile or not readfile or not isfile(ConfigFile) then return nil end
    local success, result = pcall(function()
        return HttpService:JSONDecode(readfile(ConfigFile))
    end)
    if success and type(result) == "table" then
        return result
    end
    return nil
end

local SavedData = LoadConfiguration()
if SavedData then
    if SavedData.MasterSkillEnabled ~= nil then
        MasterSkillEnabled = SavedData.MasterSkillEnabled
    end
    if SavedData.Slots then
        for slot = 1, 4 do
            local slotStr = tostring(slot)
            if SavedData.Slots[slotStr] then
                if SavedData.Slots[slotStr].Skill then
                    SlotConfig[slot].Skill = SavedData.Slots[slotStr].Skill
                end
                if SavedData.Slots[slotStr].Key and Enum.KeyCode[SavedData.Slots[slotStr].Key] then
                    SlotConfig[slot].Key = Enum.KeyCode[SavedData.Slots[slotStr].Key]
                end
            end
        end
    end
end

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
    SubTitle = "v1.1 Cast Skill & Auto Save",
    TabWidth = 140,
    Size = UDim2.fromOffset(520, 380),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Slots    = Window:AddTab({ Title = "Skill Slots", Icon = "zap" }),
    Keyboard = Window:AddTab({ Title = "Keybinds (PC)", Icon = "keyboard" })
}

-- ==========================================
-- 3. LOGIC XỬ LÝ DÙNG SKILL
-- ==========================================
local LoadedSkillPatterns = {}
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

local function setMasterSkillState(state)
    MasterSkillEnabled = state
    if MobileMasterBtn then
        MobileMasterBtn.Text = state and "SKILL: ON" or "SKILL: OFF"
        MobileMasterBtn.BackgroundColor3 = state and Color3.fromRGB(0, 170, 80) or Color3.fromRGB(180, 40, 40)
    end
    SaveConfiguration()
end

-- LẮNG NGHE PHÍM TẮT PC
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or not MasterSkillEnabled then return end
    for slotNum, cfg in pairs(SlotConfig) do
        if input.KeyCode == cfg.Key then
            castSkillBySlot(slotNum)
        end
    end
end)

-- ==========================================
-- 4. DỰNG GIAO DIỆN (UI)
-- ==========================================

-- TAB 1: SKILL SLOTS
local masterToggle = Tabs.Slots:AddToggle("MasterSkillToggle", {
    Title = "Bật / Tắt Hệ Thống Skill",
    Default = MasterSkillEnabled,
    Callback = function(Value) setMasterSkillState(Value) end
})

Tabs.Slots:AddSection("Cài Đặt Slot (1 - 4)")
local DropdownElements = {}

for slot = 1, 4 do
    DropdownElements[slot] = Tabs.Slots:AddDropdown("SlotDropdown_" .. slot, {
        Title = "Slot " .. slot .. " - Chọn Skill",
        Values = SkillDropdownOptions,
        Default = SlotConfig[slot].Skill,
        Callback = function(Value)
            SlotConfig[slot].Skill = Value
            if MobileButtons[slot] then
                MobileButtons[slot].Visible = (Value ~= "None")
                MobileButtons[slot].Text = string.format("[%d]\n%s", slot, Value)
            end
            SaveConfiguration()
        end
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
            SaveConfiguration()
        end
    })
end

-- ==========================================
-- 5. GIAO DIỆN NÚT MOBILE
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
    masterBtn.BackgroundColor3 = MasterSkillEnabled and Color3.fromRGB(0, 170, 80) or Color3.fromRGB(180, 40, 40)
    masterBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    masterBtn.Text = MasterSkillEnabled and "SKILL: ON" or "SKILL: OFF"
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
        local currentSkill = SlotConfig[slot].Skill
        local btn = Instance.new("TextButton")
        btn.Name = "SkillBtn_" .. slot
        btn.Size = UDim2.new(0, 60, 0, 60)
        btn.Position = UDim2.new(0, (slot - 1) * 70, 0, 40)
        btn.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextScaled = true
        btn.Text = string.format("[%d]\n%s", slot, currentSkill)
        btn.Font = Enum.Font.SourceSansBold
        btn.Visible = (currentSkill ~= "None")
        btn.Parent = container

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = btn

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(0, 170, 255)
        stroke.Thickness = 2
        stroke.Parent = btn

        MobileButtons[slot] = btn
        btn.MouseButton1Click:Connect(function() castSkillBySlot(slot) end)
    end
end

task.spawn(createMobileUI)

Fluent:Notify({
    Title = "Rune Hub Lite",
    Content = "Đã tải cấu hình Auto Save / Load thành công!",
    Duration = 4
})
