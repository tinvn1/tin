local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

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
    local success, response = pcall(function()
        return game:HttpGet(API_URL)
    end)

    if success and response then
        local decodeSuccess, fileDataList = pcall(function()
            return HttpService:JSONDecode(response)
        end)

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
for _, name in ipairs(SkillList) do
    table.insert(SkillDropdownOptions, name)
end

-- ==========================================
-- 2. KHỞI TẠO GUI ORION
-- ==========================================
local OrionLib = loadstring(game:HttpGet('https://raw.githubusercontent.com/jensonhirst/Orion/main/source'))()

local Window = OrionLib:MakeWindow({
    Name = "Rune Hub - Auto Skill Mobile & PC", 
    HidePremium = false, 
    SaveConfig = false,
    ConfigFolder = "RuneHubConfig"
})

local Tab1_Slots    = Window:MakeTab({ Name = "1. Gán & Setting Skill", Icon = "rbxassetid://4483345998" })
local Tab2_Keyboard = Window:MakeTab({ Name = "2. Keyboard (PC)", Icon = "rbxassetid://4483345998" })
local Tab3_Settings = Window:MakeTab({ Name = "3. Auto Underground & Config", Icon = "rbxassetid://4483345998" })

-- ==========================================
-- 3. HỆ THỐNG CONFIG & XỬ LÝ SPAM
-- ==========================================
local LoadedSkillPatterns = {}
local SlotConfig = {
    [1] = { Skill = "None", AllowSpam = false, Delay = 0.5, Key = Enum.KeyCode.One, IsSpamming = false },
    [2] = { Skill = "None", AllowSpam = false, Delay = 0.5, Key = Enum.KeyCode.Two, IsSpamming = false },
    [3] = { Skill = "None", AllowSpam = false, Delay = 0.5, Key = Enum.KeyCode.Three, IsSpamming = false },
    [4] = { Skill = "None", AllowSpam = false, Delay = 0.5, Key = Enum.KeyCode.Four, IsSpamming = false }
}

local MobileButtons = {}
local DropdownElements = {}
local ToggleElements = {}
local SliderElements = {}

local function getCharacterCFrame()
    local player = Players.LocalPlayer
    if player and player.Character then
        local hrp = player.Character:FindFirstChild("HumanoidRootPart")
        if hrp then return hrp.CFrame end
    end
    if workspace.CurrentCamera then
        return workspace.CurrentCamera.CFrame
    end
    return CFrame.new()
end

local function getOrFetchSkillPattern(skillName)
    if skillName == "None" or skillName == "" then return nil end
    if LoadedSkillPatterns[skillName] then return LoadedSkillPatterns[skillName] end

    local rawUrl = SkillDownloadUrls[skillName]
    if not rawUrl then return nil end

    local success, result = pcall(function()
        local rawCode = game:HttpGet(rawUrl)
        return loadstring(rawCode)()
    end)

    if success and type(result) == "table" then
        LoadedSkillPatterns[skillName] = result
        return result
    end
    return nil
end

local function castSkillBySlot(slotNum)
    local cfg = SlotConfig[slotNum]
    if not cfg or cfg.Skill == "None" then return end

    local pattern = getOrFetchSkillPattern(cfg.Skill)
    if pattern and Remote then
        local currentCFrame = getCharacterCFrame()
        pcall(function()
            Remote:InvokeServer("TryCast", cfg.Skill, pattern, currentCFrame)
        end)
    end
end

local slotThreads = {}
local function toggleSpamSlot(slotNum, state)
    local cfg = SlotConfig[slotNum]
    if not cfg or cfg.Skill == "None" then return end

    if state == nil then
        cfg.IsSpamming = not cfg.IsSpamming
    else
        cfg.IsSpamming = state
    end

    if cfg.IsSpamming then
        if not slotThreads[slotNum] then
            slotThreads[slotNum] = task.spawn(function()
                while cfg.IsSpamming and cfg.Skill ~= "None" do
                    castSkillBySlot(slotNum)
                    task.wait(cfg.Delay)
                end
                slotThreads[slotNum] = nil
            end)
        end
    end

    if MobileButtons[slotNum] then
        if cfg.IsSpamming then
            MobileButtons[slotNum].BackgroundColor3 = Color3.fromRGB(0, 180, 80)
        else
            MobileButtons[slotNum].BackgroundColor3 = Color3.fromRGB(25, 25, 35)
        end
    end
end

local function handleSkillTrigger(slotNum)
    local cfg = SlotConfig[slotNum]
    if not cfg or cfg.Skill == "None" then return end

    if cfg.AllowSpam then
        toggleSpamSlot(slotNum)
    else
        castSkillBySlot(slotNum)
    end
end

-- ==========================================
-- 4. LOGIC ĐỘN THỔ & BỆ ĐỨNG ĐI THEO
-- ==========================================
local AutoUndergroundEnabled = false
local UndergroundOffset = -10
local currentPlatform = nil
local followConnection = nil

local function removeUndergroundPlatform()
    if followConnection then
        followConnection:Disconnect()
        followConnection = nil
    end
    if currentPlatform then
        currentPlatform:Destroy()
        currentPlatform = nil
    end
end

local function applyAutoUnderground(character)
    removeUndergroundPlatform()

    if not AutoUndergroundEnabled or not character then return end

    local hrp = character:WaitForChild("HumanoidRootPart", 5)
    if not hrp then return end

    task.wait(0.5)

    hrp.CFrame = hrp.CFrame * CFrame.new(0, UndergroundOffset, 0)

    local platform = Instance.new("Part")
    platform.Name = "UndergroundPlatform"
    platform.Size = Vector3.new(6, 1, 6)
    platform.Anchored = true
    platform.CanCollide = true
    platform.Material = Enum.Material.SmoothPlastic
    platform.Transparency = 0.4
    platform.Color = Color3.fromRGB(0, 170, 255)
    platform.Parent = workspace

    currentPlatform = platform

    followConnection = RunService.RenderStepped:Connect(function()
        if character and character.Parent and hrp and hrp.Parent and currentPlatform then
            currentPlatform.CFrame = hrp.CFrame * CFrame.new(0, -3.5, 0)
        else
            removeUndergroundPlatform()
        end
    end)
end

Players.LocalPlayer.CharacterAdded:Connect(function(char)
    if AutoUndergroundEnabled then
        task.spawn(function() applyAutoUnderground(char) end)
    end
end)

-- ==========================================
-- 5. CƠ CHẾ DÒ & KẾT NỐI SERVER
-- ==========================================
local CustomVipCode = ""

local function findAndJoinMyServer()
    local placeId = game.PlaceId

    if CustomVipCode ~= "" then
        OrionLib:MakeNotification({
            Name = "VIP Server System",
            Content = "Đang kết nối bằng VIP Link / Code...",
            Image = "rbxassetid://4483345998",
            Time = 3
        })

        local linkCode = CustomVipCode:match("privateServerLinkCode=([%d%a%-]+)") 
                      or CustomVipCode:match("code=([%d%a%-]+)") 
                      or CustomVipCode

        local launchUrl = string.format("roblox://placeId=%d&linkCode=%s", placeId, linkCode)
        
        local success = pcall(function()
            if setclipboard then setclipboard(launchUrl) end
            game:GetService("GuiService"):OpenBrowserWindow(launchUrl)
        end)

        if not success then
            pcall(function()
                TeleportService:TeleportToPlaceInstance(placeId, linkCode, Players.LocalPlayer)
            end)
        end
        return
    end

    OrionLib:MakeNotification({
        Name = "VIP Server System",
        Content = "Đang quét danh sách Server...",
        Image = "rbxassetid://4483345998",
        Time = 3
    })

    local cursor = ""
    local validServerId = nil

    for i = 1, 5 do
        local serverUrl = string.format("https://games.roblox.com/v1/games/%d/servers/0?sortOrder=Asc&limit=100&cursor=%s", placeId, cursor)
        local success, response = pcall(function() return game:HttpGet(serverUrl) end)

        if success and response then
            local decSuccess, data = pcall(function() return HttpService:JSONDecode(response) end)
            if decSuccess and data and data.data then
                for _, server in ipairs(data.data) do
                    if server.playing and server.playing > 0 and server.playing < server.maxPlayers and server.id ~= game.JobId then
                        validServerId = server.id
                        break
                    end
                end
                if validServerId then break end
                cursor = data.nextPageCursor or ""
                if cursor == "" or cursor == nil then break end
            end
        end
    end

    if validServerId then
        OrionLib:MakeNotification({
            Name = "VIP Server System",
            Content = "Đã tìm thấy Server hợp lệ! Đang kết nối...",
            Image = "rbxassetid://4483345998",
            Time = 3
        })
        TeleportService:TeleportToPlaceInstance(placeId, validServerId, Players.LocalPlayer)
    else
        OrionLib:MakeNotification({
            Name = "VIP Server System",
            Content = "Hãy dán Link / Code VIP Server vào ô để chuyển vùng!",
            Image = "rbxassetid://4483345998",
            Time = 5
        })
    end
end

-- ==========================================
-- 6. WORKSPACE FILE CONFIG SYSTEM
-- ==========================================
local CONFIG_FILE_PATH = "RuneHub_Config.json"

local function updateMobileButtonVisibility(slotNum)
    if MobileButtons[slotNum] then
        local cfg = SlotConfig[slotNum]
        if cfg and cfg.Skill ~= "None" then
            MobileButtons[slotNum].Visible = true
            MobileButtons[slotNum].Text = string.format("[%d]\n%s", slotNum, cfg.Skill)
        else
            MobileButtons[slotNum].Visible = false
        end
    end
end

local function saveWorkspaceConfig()
    if writefile then
        local dataToSave = {
            Slots = {},
            UndergroundOffset = UndergroundOffset
        }
        for slot = 1, 4 do
            dataToSave.Slots[tostring(slot)] = {
                Skill = SlotConfig[slot].Skill,
                AllowSpam = SlotConfig[slot].AllowSpam,
                Delay = SlotConfig[slot].Delay
            }
        end
        local success, jsonStr = pcall(function()
            return HttpService:JSONEncode(dataToSave)
        end)
        if success then
            writefile(CONFIG_FILE_PATH, jsonStr)
            OrionLib:MakeNotification({
                Name = "Config System",
                Content = "Đã lưu cài đặt vào Workspace thành công!",
                Image = "rbxassetid://4483345998",
                Time = 3
            })
        end
    end
end

local function loadWorkspaceConfig()
    if isfile and readfile and isfile(CONFIG_FILE_PATH) then
        local success, content = pcall(function()
            return readfile(CONFIG_FILE_PATH)
        end)
        if success and content then
            local decodeSuccess, decodedData = pcall(function()
                return HttpService:JSONDecode(content)
            end)
            if decodeSuccess and type(decodedData) == "table" then
                if decodedData.Slots then
                    for slot = 1, 4 do
                        local sData = decodedData.Slots[tostring(slot)]
                        if sData then
                            SlotConfig[slot].Skill = sData.Skill or "None"
                            SlotConfig[slot].AllowSpam = sData.AllowSpam or false
                            SlotConfig[slot].Delay = sData.Delay or 0.5

                            if DropdownElements[slot] then DropdownElements[slot]:Set(SlotConfig[slot].Skill) end
                            if ToggleElements[slot] then ToggleElements[slot]:Set(SlotConfig[slot].AllowSpam) end
                            if SliderElements[slot] then SliderElements[slot]:Set(SlotConfig[slot].Delay) end

                            updateMobileButtonVisibility(slot)
                        end
                    end
                end
                if decodedData.UndergroundOffset then
                    UndergroundOffset = decodedData.UndergroundOffset
                    if SliderElements["Offset"] then SliderElements["Offset"]:Set(UndergroundOffset) end
                end
                OrionLib:MakeNotification({
                    Name = "Config System",
                    Content = "Đã tải cài đặt từ Workspace thành công!",
                    Image = "rbxassetid://4483345998",
                    Time = 3
                })
            end
        end
    end
end

-- ==========================================
-- 7. DỰNG GIAO DIỆN CÁC TAB
-- ==========================================

-- TAB 1: GÁN SKILL
Tab1_Slots:AddSection({ Name = "Cài Đặt Chế Độ Spam Cho Từng Slot (1-4)" })

for slot = 1, 4 do
    DropdownElements[slot] = Tab1_Slots:AddDropdown({
        Name = "Slot " .. slot .. " - Chọn Skill",
        Default = "None",
        Options = SkillDropdownOptions,
        Callback = function(Value)
            SlotConfig[slot].Skill = Value
            if Value == "None" then
                toggleSpamSlot(slot, false)
            end
            updateMobileButtonVisibility(slot)
        end
    })

    ToggleElements[slot] = Tab1_Slots:AddToggle({
        Name = "Bật Chế Độ Spam Cho Slot " .. slot,
        Default = false,
        Callback = function(Value)
            SlotConfig[slot].AllowSpam = Value
            if not Value then
                toggleSpamSlot(slot, false)
            end
        end
    })

    SliderElements[slot] = Tab1_Slots:AddSlider({
        Name = "Tốc Độ Delay Slot " .. slot,
        Min = 0.1, Max = 3.0, Default = 0.5, Increment = 0.1, ValueName = "s",
        Callback = function(Value)
            SlotConfig[slot].Delay = Value
        end
    })

    Tab1_Slots:AddSection({ Name = "----------------------------------" })
end

-- TAB 2: SETUP PHÍM PC
Tab2_Keyboard:AddSection({ Name = "Cài Đặt Phím Bấm Cho PC" })

for slot = 1, 4 do
    Tab2_Keyboard:AddBind({
        Name = "Gán Phím Cho Slot " .. slot,
        Default = SlotConfig[slot].Key,
        Hold = false,
        Callback = function()
            handleSkillTrigger(slot)
        end
    })
end

-- TAB 3: AUTO UNDERGROUND VÀ QUẢN LÝ CONFIG
Tab3_Settings:AddSection({ Name = "Auto Underground & Bệ ĐỨng Đi Theo" })

Tab3_Settings:AddToggle({
    Name = "Bật Độn Thổ (Thủ Công)",
    Default = false,
    Callback = function(Value)
        AutoUndergroundEnabled = Value
        if Value then
            if Players.LocalPlayer.Character then
                applyAutoUnderground(Players.LocalPlayer.Character)
            end
        else
            removeUndergroundPlatform()
        end
    end
})

SliderElements["Offset"] = Tab3_Settings:AddSlider({
    Name = "Độ Sâu Độn Thổ",
    Min = -30, Max = -5, Default = -10, Increment = 1, ValueName = "m",
    Callback = function(Value)
        UndergroundOffset = Value
        if AutoUndergroundEnabled and Players.LocalPlayer.Character then
            applyAutoUnderground(Players.LocalPlayer.Character)
        end
    end
})

Tab3_Settings:AddSection({ Name = "Quản Lý Server VIP" })

Tab3_Settings:AddTextbox({
    Name = "Nhập Link / Code VIP Server",
    Default = "",
    TextDisappear = false,
    Callback = function(Value)
        CustomVipCode = Value
    end
})

Tab3_Settings:AddButton({
    Name = "Vào VIP Server / Chuyển Server",
    Callback = function()
        findAndJoinMyServer()
    end
})

Tab3_Settings:AddSection({ Name = "Quản Lý Cấu Hình (Workspace)" })

Tab3_Settings:AddButton({
    Name = "Lưu Cài Đặt (Save)",
    Callback = function()
        saveWorkspaceConfig()
    end
})

Tab3_Settings:AddButton({
    Name = "Tải Cài Đặt (Load)",
    Callback = function()
        loadWorkspaceConfig()
    end
})

-- ==========================================
-- 8. GIAO DIỆN NÚT MOBILE (1, 2, 3, 4)
-- ==========================================
local function createMobileUI()
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    if playerGui:FindFirstChild("MobileSkillGui") then
        playerGui.MobileSkillGui:Destroy()
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "MobileSkillGui"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui

    local container = Instance.new("Frame")
    container.Size = UDim2.new(0, 280, 0, 70)
    container.Position = UDim2.new(0.5, -140, 0.82, 0)
    container.BackgroundTransparency = 1
    container.Parent = screenGui

    for slot = 1, 4 do
        local btn = Instance.new("TextButton")
        btn.Name = "SkillBtn_" .. slot
        btn.Size = UDim2.new(0, 60, 0, 60)
        btn.Position = UDim2.new(0, (slot - 1) * 70, 0, 0)
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

        btn.MouseButton1Click:Connect(function()
            handleSkillTrigger(slot)
        end)

        updateMobileButtonVisibility(slot)
    end
end

task.spawn(createMobileUI)

OrionLib:Init()

task.spawn(function()
    task.wait(0.5)
    loadWorkspaceConfig()
end)
