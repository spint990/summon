-- Summon Script with Rayfield UI
-- Loading Rayfield from GitHub

-- Wait for game to be fully loaded (same as Infinite Yield)
if not game:IsLoaded() then
	game.Loaded:Wait()
end

-- Define missing function helper (same as Infinite Yield)
local function missing(t, f, fallback)
	if type(f) == t then return f end
	return fallback
end

-- Define executor functions with fallbacks (same pattern as Infinite Yield)
local queueteleport = missing("function", queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport))
local fireproximityprompt = missing("function", fireproximityprompt)

-- The script URL for reloading
local ScriptURL = "https://raw.githubusercontent.com/spint990/ParadiseEnhancer/refs/heads/main/summon.lua"

-- Persistence variables (must be defined early for toggle callback)
local TeleportCheck = false
local KeepScript = true -- Set to true by default for auto-reload
local Players = game:GetService("Players")

local Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/spint990/ParadiseEnhancer/refs/heads/main/Rayfield.lua"))()

-- Create the main window
local Window = Rayfield:CreateWindow({
    Name = "Summon Hub",
    LoadingTitle = "Summon Hub",
    LoadingSubtitle = "by Summon",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "SummonHub",
        FileName = "SummonConfig"
    },
    Discord = {
        Enabled = false,
        Invite = "",
        RememberJoins = true
    },
    KeySystem = false,
    KeySettings = {
        Title = "Summon Hub",
        Subtitle = "Key System",
        Note = "No key required",
        FileName = "SummonKey",
        SaveKey = true,
        GrabKeyFromSite = false,
        Key = {"SUMMON"}
    }
})

-- Create Tab
local DungeonTab = Window:CreateTab("Dungeon", "box")
local DungeonSection = DungeonTab:CreateSection("Chest Auto-Farm")

-- Chest Auto-Farm Variables
local ChestFarmToggle = false
local ChestFarmConnection = nil
local OpenedChests = {} -- Track opened chests

-- Function to check if chest was already opened
local function IsChestOpened(chest)
    for _, openedChest in pairs(OpenedChests) do
        if openedChest == chest then
            return true
        end
    end
    return false
end

-- Function to get all chests in workspace (only unopened ones)
local function GetUnopenedChests()
    local chests = {}
    local CollectionService = game:GetService("CollectionService")
    
    -- Get chests by tag (BonusChestPart)
    for _, chestPart in pairs(CollectionService:GetTagged("BonusChestPart")) do
        if chestPart and chestPart.Parent and not IsChestOpened(chestPart) then
            -- Check if ProximityPrompt is still enabled (not opened yet)
            local prompt = chestPart:FindFirstChild("ProximityPrompt", true)
            if prompt and prompt.Enabled then
                table.insert(chests, chestPart)
            end
        end
    end
    
    -- Also check for chest models named "Chest" in Workspace
    for _, obj in pairs(workspace:GetChildren()) do
        if not IsChestOpened(obj) then
            if obj.Name == "Chest" or obj.Name:lower():find("chest") then
                -- Check if it has a ProximityPrompt that is enabled
                local prompt = obj:FindFirstChild("ProximityPrompt", true)
                if prompt and prompt.Enabled then
                    table.insert(chests, obj)
                end
            end
        end
    end
    
    return chests
end

-- Function to teleport to a position
local function TeleportTo(position)
    local player = game.Players.LocalPlayer
    local character = player.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        character.HumanoidRootPart.CFrame = CFrame.new(position + Vector3.new(0, 3, 0))
    end
end

-- Function to trigger chest proximity prompt
local function TriggerChestPrompt(chest)
    -- Find ProximityPrompt in chest or its descendants
    local prompt = chest:FindFirstChild("ProximityPrompt", true)
    if prompt then
        -- Fire the proximity prompt
        fireproximityprompt(prompt)
        return true
    end
    return false
end

-- Chest Auto-Farm Toggle
local AutoFarmChestToggle = DungeonTab:CreateToggle({
    Name = "Auto Farm Chests",
    Description = "Automatically teleports to and opens all 5 chests in the dungeon",
    CurrentValue = false,
    Flag = "AutoFarmChests",
    Callback = function(Value)
        ChestFarmToggle = Value
        
        if Value then
            -- Reset opened chests when starting
            OpenedChests = {}
            
            -- Start chest farming
            task.spawn(function()
                while ChestFarmToggle do
                    local chests = GetUnopenedChests()
                    
                    if #chests > 0 then
                        Rayfield:Notify({
                            Title = "Chest Auto-Farm",
                            Content = "Found " .. #chests .. " unopened chests. Starting farm...",
                            Duration = 2,
                            Image = "info"
                        })
                        
                        for i, chest in ipairs(chests) do
                            if not ChestFarmToggle then break end
                            
                            -- Skip if already opened
                            if IsChestOpened(chest) then continue end
                            
                            -- Get chest position
                            local chestPosition
                            if chest:IsA("BasePart") then
                                chestPosition = chest.Position
                            elseif chest:FindFirstChild("PrimaryPart") then
                                chestPosition = chest.PrimaryPart.Position
                            elseif chest:FindFirstChild("HumanoidRootPart") then
                                chestPosition = chest.HumanoidRootPart.Position
                            else
                                -- Try to find any part in the chest
                                for _, part in pairs(chest:GetDescendants()) do
                                    if part:IsA("BasePart") then
                                        chestPosition = part.Position
                                        break
                                    end
                                end
                            end
                            
                            if chestPosition then
                                -- Teleport to chest
                                TeleportTo(chestPosition)
                                task.wait(0.5)
                                
                                -- Check if prompt is still enabled before triggering
                                local prompt = chest:FindFirstChild("ProximityPrompt", true)
                                if prompt and prompt.Enabled then
                                    -- Trigger the proximity prompt (press E)
                                    local success = TriggerChestPrompt(chest)
                                    
                                    if success then
                                        -- Mark chest as opened
                                        table.insert(OpenedChests, chest)
                                        
                                        Rayfield:Notify({
                                            Title = "Chest Auto-Farm",
                                            Content = "Opened chest " .. #OpenedChests .. "/5",
                                            Duration = 1.5,
                                            Image = "checkmark"
                                        })
                                    end
                                else
                                    -- Prompt disabled means already opened
                                    table.insert(OpenedChests, chest)
                                end
                                
                                -- Wait before moving to next chest
                                task.wait(1.5)
                            end
                        end
                        
                        -- Check if all 5 chests are opened
                        if #OpenedChests >= 5 then
                            Rayfield:Notify({
                                Title = "Chest Auto-Farm",
                                Content = "All 5 chests opened! Waiting for next dungeon...",
                                Duration = 3,
                                Image = "checkmark"
                            })
                            
                            -- Wait longer for next dungeon and reset
                            task.wait(10)
                            OpenedChests = {}
                        end
                    end
                    
                    -- Wait before checking again
                    task.wait(2)
                end
            end)
        else
            -- Stop chest farming and reset
            OpenedChests = {}
            Rayfield:Notify({
                Title = "Chest Auto-Farm",
                Content = "Auto-farm stopped",
                Duration = 2,
                Image = "info"
            })
        end
    end,
})

-- Manual chest scan button
local ScanChestsButton = DungeonTab:CreateButton({
    Name = "Scan for Chests",
    Description = "Manually scan for chests in the current dungeon",
    Callback = function()
        local unopened = GetUnopenedChests()
        Rayfield:Notify({
            Title = "Chest Scanner",
            Content = "Found " .. #unopened .. " unopened chests (" .. #OpenedChests .. " already opened)",
            Duration = 3,
            Image = "info"
        })
    end,
})

-- Reset chest counter button
local ResetChestsButton = DungeonTab:CreateButton({
    Name = "Reset Chest Counter",
    Description = "Reset the opened chests counter for a new dungeon",
    Callback = function()
        OpenedChests = {}
        Rayfield:Notify({
            Title = "Chest Scanner",
            Content = "Chest counter reset! Ready for new dungeon.",
            Duration = 2,
            Image = "checkmark"
        })
    end,
})

-- Settings Tab for Persistence
local SettingsTab = Window:CreateTab("Settings", "settings")
local SettingsSection = SettingsTab:CreateSection("Persistence Settings")

-- Persistence Toggle
local PersistenceToggle = SettingsTab:CreateToggle({
    Name = "Auto-Reload on Teleport",
    Description = "Automatically reloads the script when you change instances (enter/exit dungeons)",
    CurrentValue = true,
    Flag = "AutoReloadOnTeleport",
    Callback = function(Value)
        KeepScript = Value
        if Value then
            if queueteleport then
                Rayfield:Notify({
                    Title = "Persistence",
                    Content = "Script will auto-reload after teleport/instance change",
                    Duration = 3,
                    Image = "checkmark"
                })
            else
                Rayfield:Notify({
                    Title = "Warning",
                    Content = "Your executor doesn't support persistence (queueteleport)",
                    Duration = 5,
                    Image = "alert"
                })
            end
        else
            Rayfield:Notify({
                Title = "Persistence",
                Content = "Script will NOT reload after teleport",
                Duration = 3,
                Image = "info"
            })
        end
    end,
})

-- Notify about persistence status
if queueteleport then
    Rayfield:Notify({
        Title = "Summon Hub",
        Content = "Script loaded successfully! Persistence enabled.",
        Duration = 3,
        Image = "checkmark"
    })
else
    Rayfield:Notify({
        Title = "Summon Hub",
        Content = "Script loaded! Warning: Persistence NOT supported by your executor.",
        Duration = 5,
        Image = "alert"
    })
end

-- Persistence System - MUST be at the end like Infinite Yield
Players.LocalPlayer.OnTeleport:Connect(function(State)
	if KeepScript and (not TeleportCheck) and queueteleport then
		TeleportCheck = true
		queueteleport("loadstring(game:HttpGet('https://raw.githubusercontent.com/spint990/ParadiseEnhancer/refs/heads/main/summon.lua'))()")
	end
end)
