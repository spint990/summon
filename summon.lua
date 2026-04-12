-- Summon Script with Rayfield UI
-- Wait for game to load
if not game:IsLoaded() then game.Loaded:Wait() end

-- Executor function fallbacks
local queueteleport = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
local fireproximityprompt = fireproximityprompt

-- Script URL for persistence (CHANGE THIS TO YOUR GITHUB RAW URL)
local ScriptURL = "https://raw.githubusercontent.com/spint990/summon/refs/heads/main/summon.lua"

-- Anti-duplicate execution check using global environment
local ScriptId = "SummonHub_" .. tostring(game.PlaceId)
if getgenv()[ScriptId] then
    return -- Script already running, exit
end
getgenv()[ScriptId] = true

-- Persistence variables
local TeleportCheck = false
local KeepScript = true
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

-- Load Rayfield UI
local Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/spint990/ParadiseEnhancer/refs/heads/main/Rayfield.lua"))()

local Window = Rayfield:CreateWindow({
    Name = "Summon Hub",
    LoadingTitle = "Summon Hub",
    LoadingSubtitle = "by Summon",
    ConfigurationSaving = {Enabled = true, FolderName = "SummonHub", FileName = "SummonConfig"},
    KeySystem = false
})

-- Dungeon Tab
local DungeonTab = Window:CreateTab("Dungeon", "box")
DungeonTab:CreateSection("Chest Auto-Farm")

-- Variables
local ChestFarmToggle = true
local OpenedChests = {}
local FarmRunning = false

-- Get unopened chests
local function GetUnopenedChests()
    local chests = {}
    
    for _, chest in pairs(CollectionService:GetTagged("BonusChestPart")) do
        if chest and chest.Parent then
            local prompt = chest:FindFirstChild("ProximityPrompt", true)
            if prompt and prompt.Enabled then
                table.insert(chests, chest)
            end
        end
    end
    
    for _, obj in pairs(workspace:GetChildren()) do
        if obj.Name:lower():find("chest") then
            local prompt = obj:FindFirstChild("ProximityPrompt", true)
            if prompt and prompt.Enabled then
                table.insert(chests, obj)
            end
        end
    end
    
    return chests
end

-- Teleport function
local function TeleportTo(position)
    local hrp = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.CFrame = CFrame.new(position + Vector3.new(0, 3, 0))
    end
end

-- Auto Farm Loop
local function StartChestFarm()
    if FarmRunning then return end
    task.wait(15)
    FarmRunning = true
    OpenedChests = {}
    task.spawn(function()
        while ChestFarmToggle do
            local chests = GetUnopenedChests()
            for _, chest in ipairs(chests) do
                if not ChestFarmToggle then break end
                
                local pos = chest:IsA("BasePart") and chest.Position or chest:FindFirstChild("PrimaryPart") and chest.PrimaryPart.Position
                if not pos then
                    for _, part in pairs(chest:GetDescendants()) do
                        if part:IsA("BasePart") then pos = part.Position break end
                    end
                end
                
                if pos then
                    TeleportTo(pos)
                    task.wait(0.5)
                    local prompt = chest:FindFirstChild("ProximityPrompt", true)
                    if prompt and prompt.Enabled then
                        fireproximityprompt(prompt)
                        table.insert(OpenedChests, chest)
                    end
task.wait(15)
                end
            end
            
            if #OpenedChests >= 5 then
                task.wait(10)
                OpenedChests = {}
            end
            task.wait(2)
        end
        FarmRunning = false
    end)
end

-- Auto Farm Toggle
DungeonTab:CreateToggle({
    Name = "Auto Farm Chests",
    Description = "Teleports to and opens all chests",
    CurrentValue = true,
    Flag = "AutoFarmChests",
    Callback = function(Value)
        ChestFarmToggle = Value
        if Value then
            StartChestFarm()
        end
    end
})

StartChestFarm()

-- Settings Tab
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

-- Notify on load
Rayfield:Notify({
    Title = "Summon Hub",
    Content = queueteleport and "Loaded! Persistence enabled." or "Loaded! Persistence NOT supported.",
    Duration = 3
})

-- Persistence System
Players.LocalPlayer.OnTeleport:Connect(function(State)
    if KeepScript and not TeleportCheck and queueteleport then
        TeleportCheck = true
        queueteleport("loadstring(game:HttpGet('" .. ScriptURL .. "'))()")
    end
end)

-- Stage Detection System
local WaveDataRef = nil
do
    task.spawn(function()
        local player = Players.LocalPlayer
        local profile = player:WaitForChild("PlayerGui"):WaitForChild("Profile", 30)
        if not profile then return end
        local mapsFolder = profile:WaitForChild("Maps", 10)
        if not mapsFolder then return end

        local ok, WaveData = pcall(function()
            return require(game.ReplicatedStorage.Systems.Waves.WaveData)
        end)
        if not ok or not WaveData then return end
        WaveDataRef = WaveData

        local sorted = {}
        for key, map in pairs(WaveData) do
            if type(map) == "table" and map.Stages and not map.Hidden then
                table.insert(sorted, {Key = key, Title = map.Title or key, Order = map.Order or 999, Stages = map.Stages})
            end
        end
        table.sort(sorted, function(a, b) return a.Order < b.Order end)

        for _, map in ipairs(sorted) do
            for i = 1, #map.Stages do
                local mapFolder = mapsFolder:FindFirstChild(map.Key)
                local clears = mapFolder and mapFolder:GetAttribute(tostring(i)) or 0
                if not clears or clears == 0 then
                    print("Next: " .. map.Title .. " - Stage " .. i)
                    return
                end
            end
        end
        print("All stages cleared!")
    end)
end

-- Auto Progress System
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
    local wavesScript = game.ReplicatedStorage:FindFirstChild("Systems") and game.ReplicatedStorage.Systems:FindFirstChild("Waves")
    if not wavesScript then return end
    local gameOverRemote = wavesScript:FindFirstChild("GameOver")
    if not gameOverRemote then return end
    local challengesScript = game.ReplicatedStorage.Systems:FindFirstChild("Challenges")
    if not challengesScript then return end
    local startRoundRemote = challengesScript:FindFirstChild("StartRound")
    if not startRoundRemote then return end

    gameOverRemote.OnClientEvent:Connect(function(cleared, xp, wave, totalWaves, rewards)
        if not AutoProgress then return end

        local currentMap = game.ReplicatedStorage:GetAttribute("MapName")
        local currentStage = game.ReplicatedStorage:GetAttribute("StageNumber")
        if not currentMap or not currentStage then return end

        task.wait(math.random(2.0, 10.0))

        if not AutoProgress then return end

        local targetMap = currentMap
        local targetStage = currentStage

        if cleared then
            local mapData = WaveDataRef and WaveDataRef[currentMap]
            if mapData then
                if currentStage < #mapData.Stages then
                    targetStage = currentStage + 1
                else
                    local nextMap = nil
                    for key, data in pairs(WaveDataRef) do
                        if type(data) == "table" and data.Stages and not data.Hidden and data.Order == mapData.Order + 1 then
                            nextMap = key
                            break
                        end
                    end
                    if nextMap then
                        targetMap = nextMap
                        targetStage = 1
                    end
                end
            end
        end

        print("Auto: " .. (cleared and "Next" or "Retry") .. " -> " .. targetMap .. " Stage " .. targetStage)
        Rayfield:Notify({Title = "Auto Progress", Content = (cleared and "Next" or "Retry") .. ": Stage " .. targetStage, Duration = 3})
        startRoundRemote:FireServer(targetMap, targetStage)
    end)
end)
