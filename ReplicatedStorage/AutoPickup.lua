return function(Window, Fluent)
    local PickupTab = Window:AddTab({ Title = "Auto Pickup", Icon = "shopping-bag" })

    local Rarities = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical" }
    local StatOptions = { 
        "Crit Chance", "Crit Damage", "Damage", 
        "Mana Regen", "Gold Bonus", "Luck", 
        "Health", "ReflectDamage", "Slash", "Immunity"
    }
    local SkillOptions = {
        "Star Fire", "Whirl Pool", "Summon", "Meteo",
        "Prime Ice Sword", "Ice Sword", "Lighting Staff",
        "Pistol", "Rock Dragon", "Immunity", "Fire Sword",
        "Health", "Ring Water", "Armor Water", "Slash"
    }

    local SelectedRarities = {}
    local SelectedSkills = {}
    local SelectedStats = {}
    local StatMinValues = {}
    local PickupRadius = 40

    if not _G.DunkHubState then _G.DunkHubState = {} end
    _G.DunkHubState.AutoPickup = false

    PickupTab:AddToggle("ToggleAutoPickup", {
        Title = "Enable Auto Pickup",
        Default = false,
        Callback = function(Value)
            _G.DunkHubState.AutoPickup = Value
        end
    })

    PickupTab:AddSlider("PickupDistance", {
        Title = "Khoảng cách nhặt (Studs)",
        Min = 10, Max = 100, Default = 40, Rounding = 0,
        Callback = function(Value) PickupRadius = Value end
    })

    Rarity (độ hiếm) và Chỉ số (Stats/Lines) trong game có mối quan hệ chặt chẽ với nhau theo các quy tắc chính sau:

* **Mức trần chỉ số (Stat Cap):** Rarity càng cao thì giới hạn chỉ số tối đa (chỉ số cơ bản hoặc dòng chỉ số cộng thêm) đạt được càng lớn.
* **Số lượng dòng dòng chỉ số (Line Count):** Trang bị hoặc vật phẩm thuộc Rarity cao hơn thường có nhiều dòng chỉ số phụ (sub-stats) hơn.
* **Tỷ lệ và Phẩm chất dòng (Tier/Quality):** Rarity cao cho phép xuất hiện các dòng chỉ số bậc cao (Tier cao), cho % hoặc chỉ số cộng thêm vượt trội so với các bậc Rarity thấp.
* **Gia tăng khi Nâng cấp (Upgrade Scaling):** Khi cường hóa hoặc đập đồ, trang bị Rarity cao sẽ nhận được lượng chỉ số cộng thêm trên mỗi cấp nhiều hơn hẳn.

Nếu bạn đang chơi một tựa game cụ thể (như Roblox, game RPG, hay game gacha) và muốn tối ưu việc lọc/chọn trang bị giữa **Rarity** và **Dòng chỉ số**, hãy áp dụng chiến thuật sau:

1. **Giai đoạn đầu/giữa game:** Ưu tiên **Dòng chỉ số phù hợp** (đúng dòng build) hơn là Rarity. Một món đồ Rarity thấp hơn nhưng có dòng chỉ số chuẩn (ví dụ: % Tấn công, % Sát thương chí mạng) vẫn mạnh hơn món Rarity cao mà dòng bị rác.
2. **Giai đoạn cuối game (End-game):** Bắt buộc phải chọn **Rarity cao nhất** kết hợp với **Dòng chỉ số chuẩn** để tối đa hóa sức mạnh nhân vật.
