-- ============================================================
-- RUNE HUB | ULTRA LITE (CHỈ CHỌN SKILL & BẤM NÚT XẢ SKILL)
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local Remote = ReplicatedStorage:WaitForChild("RuneWeaponSkillRemote", 10)

-- ==========================================
-- 1. QUÉT DANH SÁCH SKILL TỪ GITHUB
-- ==========================================
local REPO_OWNER = "tinvn1"
local REPO_NAME = "tin"
local FOLDER_PATH = "ReplicatedStorage/SkillPatterns"
local API_URL = string.format("https://api.github.com/repos/%s/%s/contents/%s", REPO_OWNER, REPO_NAME, FOLDER_PATH)

local SkillList = {"None"}
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

-- ==========================================
-- 2. LOGIC TẢI & TUNG SKILL
-- ==========================================
local LoadedSkillPatterns = {}
local SelectedSkills = { [1] = "None", [2] = "None", [3] = "None", [4] = "None" }

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

local function castSkill(slotNum)
    local skillName = SelectedSkills[slotNum]
    if not skillName or skillName == "None" then return end
    
    local pattern = getOrFetchSkillPattern(skillName)
    if pattern and Remote then
        pcall(function()
            Remote:InvokeServer("TryCast", skillName, pattern, getCharacterCFrame())
        end)
    end
end

-- ==========================================
-- 3. TẠO GIAO DIỆN NÚT BẤM & CHỌN SKILL
-- ==========================================
local function buildSimpleUI()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    if playerGui:FindFirstChild("UltraLiteSkillGui") then
        playerGui.UltraLiteSkillGui:Destroy()
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "UltraLiteSkillGui"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui

    -- Khung chứa chính
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 320, 0, 130)
    mainFrame.Position = UDim2.new(0.5, -160, 0.75, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    mainFrame.BackgroundTransparency = 0.2
    mainFrame.Active = true
    mainFrame.Draggable = true -- Cho phép kéo thả vị trí trên màn hình
    mainFrame.Parent = screenGui

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 10)
    mainCorner.Parent = mainFrame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 20)
    title.Position = UDim2.new(0, 0, 0, 5)
    title.BackgroundTransparency = 1
    title.Text = "RUNE HUB ULTRA LITE"
    title.TextColor3 = Color3.fromRGB(0, 200, 255)
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 14
    title.Parent = mainFrame

    -- Tạo 4 Slot
    for slot = 1, 4 do
        local xOffset = (slot - 1) * 75 + 10

        -- Nút bấm tung Skill (Phía dưới)
        local btn = Instance.new("TextButton")
        btn.Name = "CastBtn_" .. slot
        btn.Size = UDim2.new(0, 70, 0, 50)
        btn.Position = UDim2.new(0, xOffset, 0, 65)
        btn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Text = "Slot " .. slot
        btn.Font = Enum.Font.SourceSansBold
        btn.TextSize = 13
        btn.Parent = mainFrame

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 8)
        btnCorner.Parent = btn

        local btnStroke = Instance.new("UIStroke")
        btnStroke.Color = Color3.fromRGB(0, 170, 255)
        btnStroke.Thickness = 1.5
        btnStroke.Parent = btn

        -- Khi bấm nút -> Xả skill 1 lần
        btn.MouseButton1Click:Connect(function()
            castSkill(slot)
        end)

        -- Nút chuyển đổi Skill (Phía trên nút tung skill)
        local selectBtn = Instance.new("TextButton")
        selectBtn.Name = "SelectBtn_" .. slot
        selectBtn.Size = UDim2.new(0, 70, 0, 25)
        selectBtn.Position = UDim2.new(0, xOffset, 0, 32)
        selectBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
        selectBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        selectBtn.Text = "Skill: None"
        selectBtn.Font = Enum.Font.SourceSans
        selectBtn.TextScaled = true
        selectBtn.Parent = mainFrame

        local selCorner = Instance.new("UICorner")
        selCorner.CornerRadius = UDim.new(0, 6)
        selCorner.Parent = selectBtn

        -- Tự động đổi skill tiếp theo trong danh sách mỗi khi bấm vào nút "Skill: ..."
        local currentIndex = 1
        selectBtn.MouseButton1Click:Connect(function()
            currentIndex = currentIndex + 1
            if currentIndex > #SkillList then
                currentIndex = 1
            end
            
            local chosenSkill = SkillList[currentIndex]
            SelectedSkills[slot] = chosenSkill
            selectBtn.Text = chosenSkill
            btn.Text = "S" .. slot .. ":\n" .. chosenSkill
        end)
    end
end

buildSimpleUI()
