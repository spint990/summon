if not game:IsLoaded() then game.Loaded:Wait() end

local queueteleport = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
local fireproximityprompt = fireproximityprompt

local ScriptURL = "https://raw.githubusercontent.com/spint990/summon/refs/heads/main/summon.lua"

local ScriptId = "SummonHub_" .. tostring(game.PlaceId)
if getgenv()[ScriptId] then return end
getgenv()[ScriptId] = true

local TeleportCheck = false
local KeepScript = true
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/spint990/ParadiseEnhancer/refs/heads/main/Rayfield.lua"))()

local Window = Rayfield:CreateWindow({
    Name = "Summon Hub",
    LoadingTitle = "Summon Hub",
    LoadingSubtitle = "by Summon",
    ConfigurationSaving = {Enabled = true, FolderName = "SummonHub", FileName = "SummonConfig"},
    KeySystem = false
})

local DungeonTab = Window:CreateTab("Dungeon", "box")
DungeonTab:CreateSection("Chest Auto-Farm")

local ChestFarmToggle = true
local FarmRunning = false

local function GetUnopenedChests()
    local chests = {}
    for _, chest in CollectionService:GetTagged("BonusChestPart") do
        if chest and chest.Parent then
            local prompt = chest:FindFirstChild("ProximityPrompt", true)
            if prompt and prompt.Enabled then
                table.insert(chests, chest)
            end
        end
    end
    return chests
end

local function GetChestPosition(chest)
    if chest:IsA("BasePart") then return chest.Position end
    if chest.PrimaryPart then return chest.PrimaryPart.Position end
    for _, part in chest:GetDescendants() do
        if part:IsA("BasePart") then return part.Position end
    end
    return nil
end

local function TeleportTo(position)
    local char = Players.LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.CFrame = CFrame.new(position + Vector3.new(0, 3, 0))
    end
end

local function OpenChest(chest)
    local prompt = chest:FindFirstChild("ProximityPrompt", true)
    if not prompt or not prompt.Enabled then return false end
    local pos = GetChestPosition(chest)
    if not pos then return false end
    TeleportTo(pos)
    task.wait(0.3)
    prompt = chest:FindFirstChild("ProximityPrompt", true)
    if prompt and prompt.Enabled then
        fireproximityprompt(prompt)
        return true
    end
    return false
end

local function StartChestFarm()
    if FarmRunning then return end
    FarmRunning = true
    task.spawn(function()
        while ChestFarmToggle do
            local chests = GetUnopenedChests()
            if #chests == 0 then
                task.wait(3)
                continue
            end
            for _, chest in chests do
                if not ChestFarmToggle then break end
                if OpenChest(chest) then
                    task.wait(math.random(8.0, 15.0))
                end
            end
            task.wait(2)
        end
        FarmRunning = false
    end)
end

DungeonTab:CreateToggle({
    Name = "Auto Farm Chests",
    Description = "Teleports to and opens all chests",
    CurrentValue = true,
    Flag = "AutoFarmChests",
    Callback = function(Value)
        ChestFarmToggle = Value
        if Value then StartChestFarm() end
    end
})

StartChestFarm()

local SettingsTab = Window:CreateTab("Settings", "settings")
SettingsTab:CreateSection("Persistence")

SettingsTab:CreateToggle({
    Name = "Auto-Reload on Teleport",
    Description = "Reloads script after instance change",
    CurrentValue = true,
    Flag = "AutoReload",
    Callback = function(Value)
        KeepScript = Value
        Rayfield:Notify({Title = "Persistence", Content = Value and "Enabled" or "Disabled", Duration = 2})
    end
})

Rayfield:Notify({
    Title = "Summon Hub",
    Content = queueteleport and "Loaded! Persistence enabled." or "Loaded! Persistence NOT supported.",
    Duration = 3
})

Players.LocalPlayer.OnTeleport:Connect(function(State)
    if KeepScript and not TeleportCheck and queueteleport then
        TeleportCheck = true
        queueteleport("loadstring(game:HttpGet('" .. ScriptURL .. "'))()")
    end
end)

local WaveDataRef = nil
local SortedMaps = nil
local CurrentRunTarget = nil

local function BuildSortedMaps(WaveData)
    local sorted = {}
    for key, map in pairs(WaveData) do
        if type(map) == "table" and map.Stages and not map.Hidden then
            table.insert(sorted, {Key = key, Order = map.Order or 999, StageCount = #map.Stages})
        end
    end
    table.sort(sorted, function(a, b) return a.Order < b.Order end)
    return sorted
end

local function GetNextStage(mapKey, stageNum)
    if not SortedMaps then return nil end
    for m, map in ipairs(SortedMaps) do
        if map.Key == mapKey then
            if stageNum < map.StageCount then
                return {Map = mapKey, Stage = stageNum + 1}
            end
            if m < #SortedMaps then
                local nextMap = SortedMaps[m + 1]
                return {Map = nextMap.Key, Stage = 1}
            end
            return nil
        end
    end
    return nil
end

local function FindFirstUnclearedStage(mapsFolder)
    if not SortedMaps then return nil end
    for _, map in ipairs(SortedMaps) do
        for i = 1, map.StageCount do
            local mapFolder = mapsFolder:FindFirstChild(map.Key)
            local clears = mapFolder and mapFolder:GetAttribute(tostring(i)) or 0
            if not clears or clears == 0 then
                return {Map = map.Key, Stage = i}
            end
        end
    end
    return nil
end

task.spawn(function()
    local player = Players.LocalPlayer
    local profile = player:WaitForChild("PlayerGui"):WaitForChild("Profile", 30)
    if not profile then return end
    local mapsFolder = profile:WaitForChild("Maps", 10)
    if not mapsFolder then return end

    local ok, WaveData = pcall(function()
        return require(ReplicatedStorage.Systems.Waves.WaveData)
    end)
    if not ok or not WaveData then return end
    WaveDataRef = WaveData
    SortedMaps = BuildSortedMaps(WaveData)

    local target = FindFirstUnclearedStage(mapsFolder)
    if target then
        CurrentRunTarget = target
        print("[Stage] First uncleared: " .. target.Map .. " Stage " .. target.Stage)
    else
        print("[Stage] All stages cleared!")
    end
end)

local AutoProgress = true

DungeonTab:CreateSection("Auto Progress")
DungeonTab:CreateToggle({
    Name = "Auto Next/Retry",
    Description = "Auto retry on fail, auto next stage on win",
    CurrentValue = true,
    Flag = "AutoProgress",
    Callback = function(Value)
        AutoProgress = Value
        Rayfield:Notify({Title = "Auto Progress", Content = Value and "Enabled" or "Disabled", Duration = 2})
    end
})

task.spawn(function()
    local systemsFolder = ReplicatedStorage:WaitForChild("Systems", 10)
    if not systemsFolder then return end

    local wavesFolder = systemsFolder:WaitForChild("Waves", 5)
    if not wavesFolder then return end
    local gameOverRemote = wavesFolder:WaitForChild("GameOver", 5)
    if not gameOverRemote then return end

    local challengesScript = systemsFolder:WaitForChild("Challenges", 5)
    if not challengesScript then return end
    local startRoundRemote = challengesScript:WaitForChild("StartRound", 5)
    if not startRoundRemote then return end

    gameOverRemote.OnClientEvent:Connect(function(cleared, xp, wave, totalWaves, rewards)
        if not AutoProgress then return end

        task.wait(math.random(8.0, 12.0))
        if not AutoProgress then return end

        local currentMap = ReplicatedStorage:GetAttribute("MapName")
        local currentStage = ReplicatedStorage:GetAttribute("StageNumber")
        if not currentMap or not currentStage then return end
        currentStage = tonumber(currentStage) or 1

        if cleared then
            local nextStage = GetNextStage(currentMap, currentStage)
            if nextStage then
                CurrentRunTarget = nextStage
                print("[AutoProgress] Cleared -> Next: " .. nextStage.Map .. " Stage " .. nextStage.Stage)
                startRoundRemote:FireServer(nextStage.Map, nextStage.Stage)
            else
                print("[AutoProgress] Cleared -> Last stage reached, retry: " .. currentMap .. " Stage " .. currentStage)
                startRoundRemote:FireServer(currentMap, currentStage)
            end
        else
            print("[AutoProgress] Retry -> " .. currentMap .. " Stage " .. currentStage)
            startRoundRemote:FireServer(currentMap, currentStage)
        end
    end)
end)
