-- SCRIPT INSPECT ITEMDROP TRONG WORKSPACE
local itemDropFolder = workspace:FindFirstChild("itemdrop") or workspace

print("================ [ ITEM DROP INSPECTOR ] ================")

local count = 0
for _, item in pairs(itemDropFolder:GetChildren()) do
    count = count + 1
    print(string.format("\n--- [%d] ITEM: %s (Class: %s) ---", count, item.Name, item.ClassName))
    
    -- 1. In toàn bộ Attributes
    local attributes = item:GetAttributes()
    print(">> ATTRIBUTES:")
    if next(attributes) == nil then
        print("   (Không có Attribute nào)")
    else
        for attrName, attrValue in pairs(attributes) do
            print(string.format("   - %s = %s (%s)", tostring(attrName), tostring(attrValue), type(attrValue)))
        end
    end

    -- 2. In ProximityPrompt (nếu có)
    local prompt = item:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt then
        print(string.format(">> PROXIMITY PROMPT: ObjectText='%s', ActionText='%s'", prompt.ObjectText, prompt.ActionText))
    else
        print(">> PROXIMITY PROMPT: Không tìm thấy")
    end
end

if count == 0 then
    print("Không tìm thấy món đồ nào trong folder itemdrop!")
end

print("==========================================================")
