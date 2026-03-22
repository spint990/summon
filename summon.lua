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

-- Auto Farm Toggle
DungeonTab:CreateToggle({
    Name = "Auto Farm Chests",
    Description = "Teleports to and opens all chests",
    CurrentValue = true,
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
