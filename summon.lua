-- Summon Script with Rayfield UI
-- Wait for game to load
if not game:IsLoaded() then game.Loaded:Wait() end

-- Executor function fallbacks
local queueteleport = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
local fireproximityprompt = fireproximityprompt

-- Script URL for persistence (CHANGE THIS TO YOUR GITHUB RAW URL)
local ScriptURL = "https://raw.githubusercontent.com/spint990/summon/refs/heads/main/summon.lua"

-- Persistence variables
local TeleportCheck = false
local KeepScript = true
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Load WaveData for maps/stages
local WaveData = nil
local success, err = pcall(function()
    WaveData = require(ReplicatedStorage.Systems.Waves.WaveData)
end)
if not success then
    warn("Failed to load WaveData: " .. tostring(err))
end

-- Get available maps dynamically
local function GetAvailableMaps()
    local maps = {}
    if not WaveData then return maps end
    
    for mapName, mapData in pairs(WaveData) do
        if type(mapData) == "table" and mapData.Stages and not mapData.Hidden then
            local stageCount = 0
            for _ in pairs(mapData.Stages) do
                stageCount = stageCount + 1
            end
            table.insert(maps, {
                Name = mapName,
                Title = mapData.Title or mapName,
                Order = mapData.Order or 999,
                StageCount = stageCount,
                IsRaid = mapData.IsRaid or false,
                ChallengeWave = mapData.ChallengeWave or false
            })
        end
    end
    
    -- Sort by order
    table.sort(maps, function(a, b)
        return a.Order < b.Order
    end)
    
    return maps
end

-- Get stages for a specific map
local function GetStagesForMap(mapName)
    local stages = {}
    if not WaveData or not WaveData[mapName] then return stages end
    
    local mapData = WaveData[mapName]
    if not mapData.Stages then return stages end
    
    for stageNum, stageData in pairs(mapData.Stages) do
        if type(stageData) == "table" then
            table.insert(stages, {
                Number = stageNum,
                Name = stageData.Name or ("Stage " .. tostring(stageNum)),
                Level = stageData.Level or 1
            })
        end
    end
    
    -- Sort by stage number
    table.sort(stages, function(a, b)
        return a.Number < b.Number
    end)
    
    return stages
end

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
DungeonTab:CreateSection("Dungeon Launcher")

-- Variables for dungeon selection
local SelectedMap = nil
local SelectedStage = 1
local AvailableMaps = GetAvailableMaps()

-- Create map dropdown options
local MapOptions = {}
for _, mapInfo in ipairs(AvailableMaps) do
    table.insert(MapOptions, mapInfo.Title .. " (" .. mapInfo.StageCount .. " stages)")
end

-- Map Selection Dropdown
DungeonTab:CreateDropdown({
    Name = "Select Map",
    Options = MapOptions,
    CurrentOption = MapOptions[1] or "No maps found",
    Flag = "MapSelector",
    Callback = function(Value)
        local mapTitle = Value:match("^(.+) %(.+%)$")
        for _, mapInfo in ipairs(AvailableMaps) do
            if mapInfo.Title == mapTitle then
                SelectedMap = mapInfo.Name
                -- Update stage dropdown
                local stages = GetStagesForMap(SelectedMap)
                if stages[1] then
                    SelectedStage = stages[1].Number
                end
                Rayfield:Notify({
                    Title = "Map Selected",
                    Content = mapInfo.Title .. " - " .. mapInfo.StageCount .. " stages available",
                    Duration = 2
                })
                break
            end
        end
    end
})

-- Stage Selection Slider
DungeonTab:CreateSlider({
    Name = "Select Stage",
    Range = {1, 10},
    Increment = 1,
    Suffix = "Stage",
    CurrentValue = 1,
    Flag = "StageSelector",
    Callback = function(Value)
        SelectedStage = math.floor(Value)
    end
})

-- Launch Dungeon Button
DungeonTab:CreateButton({
    Name = "Launch Dungeon",
    Callback = function()
        if not SelectedMap then
            Rayfield:Notify({
                Title = "Error",
                Content = "Please select a map first!",
                Duration = 3
            })
            return
        end
        
        -- Find an available queue
        local queueFound = false
        for _, queue in pairs(game.CollectionService:GetTagged("LobbyQueue")) do
            -- Set the queue attributes
            queue:SetAttribute("Map", SelectedMap)
            queue:SetAttribute("Stage", SelectedStage)
            queueFound = true
            
            Rayfield:Notify({
                Title = "Launching",
                Content = "Starting " .. SelectedMap .. " Stage " .. SelectedStage,
                Duration = 3
            })
            
            -- Try to launch via remote
            local QueueRemote = ReplicatedStorage:FindFirstChild("Queue")
            if QueueRemote then
                local SetQueue = QueueRemote:FindFirstChild("SetQueue")
                local LaunchQueue = QueueRemote:FindFirstChild("LaunchQueue")
                
                if SetQueue then
                    SetQueue:FireServer(queue, SelectedMap, SelectedStage)
                end
                
                task.wait(0.5)
                
                if LaunchQueue then
                    LaunchQueue:FireServer(queue)
                end
            end
            break
        end
        
        if not queueFound then
            Rayfield:Notify({
                Title = "Error",
                Content = "No queue found! Go to a queue door first.",
                Duration = 4
            })
        end
    end
})

-- Refresh Maps Button
DungeonTab:CreateButton({
    Name = "Refresh Maps List",
    Callback = function()
        AvailableMaps = GetAvailableMaps()
        Rayfield:Notify({
            Title = "Maps Refreshed",
            Content = "Found " .. #AvailableMaps .. " maps",
            Duration = 2
        })
    end
})

-- Show available maps info
DungeonTab:CreateButton({
    Name = "Show Maps Info",
    Callback = function()
        local info = "Available Maps:\n"
        for _, mapInfo in ipairs(AvailableMaps) do
            info = info .. mapInfo.Title .. " (" .. mapInfo.StageCount .. " stages)\n"
        end
        Rayfield:Notify({
            Title = "Maps Info",
            Content = info,
            Duration = 5
        })
    end
})

DungeonTab:CreateSection("Chest Auto-Farm")

-- Variables
local ChestFarmToggle = false
local OpenedChests = {}

-- Get unopened chests
local function GetUnopenedChests()
    local chests = {}
    local CollectionService = game:GetService("CollectionService")
    
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
    local hrp = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.CFrame = CFrame.new(position + Vector3.new(0, 3, 0))
    end
end

-- Auto Farm Toggle
DungeonTab:CreateToggle({
    Name = "Auto Farm Chests",
    Description = "Teleports to and opens all chests",
    CurrentValue = false,
    Flag = "AutoFarmChests",
    Callback = function(Value)
        ChestFarmToggle = Value
        if Value then
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
                            task.wait(1)
                        end
                    end
                    
                    if #OpenedChests >= 5 then
                        task.wait(10)
                        OpenedChests = {}
                    end
                    task.wait(2)
                end
            end)
        end
    end
})

-- Scan Button
DungeonTab:CreateButton({
    Name = "Scan for Chests",
    Callback = function()
        Rayfield:Notify({Title = "Scanner", Content = "Found " .. #GetUnopenedChests() .. " chests", Duration = 3})
    end
})

-- Reset Button
DungeonTab:CreateButton({
    Name = "Reset Counter",
    Callback = function()
        OpenedChests = {}
        Rayfield:Notify({Title = "Reset", Content = "Counter reset!", Duration = 2})
    end
})

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
