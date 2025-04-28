-- Optimized ESP Library
local ESP = {
    Players = {},
    Instances = {},
    DrawingObjects = {},
    Connections = {},
    TrackCivilians = true
}

-- Settings
ESP.Settings = {
    MasterToggle = false,
    playerBoxes = true,
    playerNameTags = true,
    playerHeadDots = false,
    playerDistances = true,
    instanceBoxes = true,
    instanceNameTags = true,
    instanceHeadDots = false,
    instanceDistances = true,
    Thickness = 1.5
}

-- Cache services and frequently used variables
local camera = workspace.CurrentCamera
local runService = game:GetService("RunService")
local players = game:GetService("Players")
local localPlayer = players.LocalPlayer
local teams = game:GetService("Teams")
local Vector2New = Vector2.new
local Vector3New = Vector3.new
local mathFloor = math.floor
local mathMin = math.min
local mathMax = math.max
local mathHuge = math.huge
local tableInsert = table.insert
local tableClear = table.clear
local drawingNew = Drawing.new

-- Cached drawing creation functions
local function createDrawingObject(objectType, properties)
    local object = drawingNew(objectType)
    for prop, value in pairs(properties) do
        object[prop] = value
    end
    return object
end

local function createBox(color)
    return createDrawingObject("Square", {
        Color = color,
        Thickness = ESP.Settings.Thickness,
        Filled = false,
        Visible = false
    })
end

local function createNameTag(color)
    return createDrawingObject("Text", {
        Visible = false,
        Transparency = 1,
        Color = color,
        Size = 14,
        Font = Drawing.Fonts["Plex"],
        Center = true,
        Outline = true,
        OutlineColor = Color3.fromRGB(0,0,0)
    })
end

local function createDistance(color)
    return createDrawingObject("Text", {
        Visible = false,
        Transparency = 1,
        Color = color,
        Size = 14,
        Font = Drawing.Fonts["Plex"],
        Center = true,
        Outline = true,
        OutlineColor = Color3.fromRGB(0,0,0)
    })
end

local function createHeadDot(color)
    return createDrawingObject("Circle", {
        Visible = false,
        Transparency = 1,
        Color = color,
        NumSides = 32,
        Radius = 4,
        Thickness = 1
    })
end

-- Helper function to clean up drawings
local function cleanupDrawings(target)
    local drawings = ESP.DrawingObjects[target]
    if drawings then
        if drawings.Box then drawings.Box:Destroy() end
        if drawings.NameTag then drawings.NameTag:Destroy() end
        if drawings.Distance then drawings.Distance:Destroy() end
        if drawings.HeadDot then drawings.HeadDot:Destroy() end
        ESP.DrawingObjects[target] = nil
    end
end

-- Helper function to clean up connections
local function cleanupConnections(target)
    if ESP.Connections[target] then
        if typeof(ESP.Connections[target]) == "table" then
            for _, conn in pairs(ESP.Connections[target]) do
                conn:Disconnect()
            end
        else
            ESP.Connections[target]:Disconnect()
        end
        ESP.Connections[target] = nil
    end
end

-- Optimized method to calculate box boundaries from a list of parts
local function calculateBoxBoundaries(parts, character)
    local minX, minY, maxX, maxY = mathHuge, mathHuge, -mathHuge, -mathHuge
    local visiblePoints = false
    
    -- Reuse vectors for each part to reduce memory allocations
    local corners = {}
    for i = 1, 8 do corners[i] = Vector3New(0, 0, 0) end
    
    -- Vector cache for WorldToViewportPoint calls
    local screenPoints = {}
    
    for _, part in ipairs(parts) do
        if part:IsA("BasePart") then
            local size = part.Size
            local cf = part.CFrame
            local halfSizeX, halfSizeY, halfSizeZ = size.X/2, size.Y/2, size.Z/2
            
            -- Calculate the 8 corners of the part
            corners[1] = cf:PointToWorldSpace(Vector3New(-halfSizeX, -halfSizeY, -halfSizeZ))
            corners[2] = cf:PointToWorldSpace(Vector3New(halfSizeX, -halfSizeY, -halfSizeZ))
            corners[3] = cf:PointToWorldSpace(Vector3New(-halfSizeX, halfSizeY, -halfSizeZ))
            corners[4] = cf:PointToWorldSpace(Vector3New(halfSizeX, halfSizeY, -halfSizeZ))
            corners[5] = cf:PointToWorldSpace(Vector3New(-halfSizeX, -halfSizeY, halfSizeZ))
            corners[6] = cf:PointToWorldSpace(Vector3New(halfSizeX, -halfSizeY, halfSizeZ))
            corners[7] = cf:PointToWorldSpace(Vector3New(-halfSizeX, halfSizeY, halfSizeZ))
            corners[8] = cf:PointToWorldSpace(Vector3New(halfSizeX, halfSizeY, halfSizeZ))
            
            -- Convert all corners to screen space at once
            for i = 1, 8 do
                local screenPoint, visible = camera:WorldToViewportPoint(corners[i])
                if visible then
                    visiblePoints = true
                    screenPoints[i] = screenPoint
                    minX = mathMin(minX, screenPoint.X)
                    minY = mathMin(minY, screenPoint.Y)
                    maxX = mathMax(maxX, screenPoint.X)
                    maxY = mathMax(maxY, screenPoint.Y)
                end
            end
        end
    end
    
    if visiblePoints then
        local padding = 2
        return minX - padding, minY - padding, maxX + padding, maxY + padding, true
    end
    
    return 0, 0, 0, 0, false
end

-- Player ESP handling
function ESP:AddPlayer(player, color)
    if not ESP.Settings.MasterToggle then return end
    if not player then return end
    if self.Players[player] then return end
    if player == localPlayer then return end

    color = color or Color3.new(1,1,1)

    local drawings = {
        Box = createBox(color),
        NameTag = createNameTag(Color3.new(1,1,1)),
        Distance = createDistance(Color3.new(1,1,1)),
        HeadDot = createHeadDot(color)
    }

    self.DrawingObjects[player] = drawings
    self.Players[player] = true

    self.Connections[player] = self.Connections[player] or {}

    -- Handle player leaving
    local playerAncestryChangedConnection = player.AncestryChanged:Connect(function(_, parent)
        if not parent then
            cleanupDrawings(player)
            cleanupConnections(player)
            self.Players[player] = nil
        end
    end)
    tableInsert(self.Connections[player], playerAncestryChangedConnection)
    
    -- Handle player respawns
    local characterAddedConnection = player.CharacterAdded:Connect(function(character)
        -- Make character streaming persistent if possible
        if character and character.ModelStreamingMode ~= Enum.ModelStreamingMode.Persistent then
            character.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
        end
    end)
    
    local characterRemovedConnection = player.CharacterRemoving:Connect(function()
        -- Hide ESP temporarily when character is removed
        local drawing = self.DrawingObjects[player]
        if drawing then
            drawing.Box.Visible = false
            drawing.NameTag.Visible = false
            drawing.Distance.Visible = false
            drawing.HeadDot.Visible = false
        end
    end)
    
    tableInsert(self.Connections[player], characterAddedConnection)
    tableInsert(self.Connections[player], characterRemovedConnection)
end

function ESP:RemovePlayer(player)
    if self.Players[player] then
        cleanupDrawings(player)
        cleanupConnections(player)
        self.Players[player] = nil
    end
end

function ESP:AddTeam(teamName, color, useTeamColor)
    if not ESP.Settings.MasterToggle then return end
    if not teamName then return end

    color = color or Color3.new(1,1,1)
    local teamObject

    -- Try to find the team object, except for Criminal (special case)
    if teamName ~= "Criminal" then
        for _, t in pairs(game:GetService("Teams"):GetChildren()) do
            if t.Name == teamName then
                teamObject = t
                break
            end
        end
        if not teamObject then
            warn("[ESP] AddTeam failed: Team not found:", teamName)
            return
        end
        if useTeamColor then
            color = teamObject.TeamColor.Color
        end
    end

    -- Track special cases
    if teamName == "Criminal" then
        -- Setup Criminal ESP
        for _, player in ipairs(game.Players:GetPlayers()) do
            if player ~= localPlayer and player:FindFirstChild("Is_Wanted") then
                self:AddPlayer(player, Color3.new(1,0,0)) -- Red color for criminals
            end

            if not self.Connections[player] then
                self.Connections[player] = {}
            end

            -- Handle Criminal detection
            local childAddedConn = player.ChildAdded:Connect(function(child)
                if child.Name == "Is_Wanted" then
                    self:AddPlayer(player, Color3.new(1,0,0))
                end
            end)

            local childRemovedConn = player.ChildRemoved:Connect(function(child)
                if child.Name == "Is_Wanted" then
                    self:RemovePlayer(player)
                end
            end)

            table.insert(self.Connections[player], childAddedConn)
            table.insert(self.Connections[player], childRemovedConn)
        end

    elseif teamName == "Civilian" then
        -- Setup Civilian ESP
        for _, player in ipairs(game.Players:GetPlayers()) do
            if player ~= localPlayer and player.Team and player.Team.Name == "Civilian" and not player:FindFirstChild("Is_Wanted") then
                self:AddPlayer(player, color)
            end

            if not self.Connections[player] then
                self.Connections[player] = {}
            end

            -- Handle Civilian team changes
            local teamChangedConn = player:GetPropertyChangedSignal("Team"):Connect(function()
                if player.Team and player.Team.Name == "Civilian" and not player:FindFirstChild("Is_Wanted") then
                    self:AddPlayer(player, color)
                else
                    self:RemovePlayer(player)
                end
            end)

            table.insert(self.Connections[player], teamChangedConn)
        end

    else
        -- Setup Generic Team ESP
        for _, player in ipairs(game.Players:GetPlayers()) do
            if player ~= localPlayer and player.Team and player.Team.Name == teamName then
                self:AddPlayer(player, color)
            end

            if not self.Connections[player] then
                self.Connections[player] = {}
            end

            local teamChangedConn = player:GetPropertyChangedSignal("Team"):Connect(function()
                if player.Team and player.Team.Name == teamName then
                    self:AddPlayer(player, color)
                else
                    self:RemovePlayer(player)
                end
            end)

            table.insert(self.Connections[player], teamChangedConn)
        end
    end
end


function ESP:RemoveTeam(team)
    if not team then return end

    -- Clean up the team tracking connection
    if self.Connections["TeamTracker_" .. team] then
        self.Connections["TeamTracker_" .. team]:Disconnect()
        self.Connections["TeamTracker_" .. team] = nil
    end

    if team == "Criminal" then
        for _, player in pairs(players:GetPlayers()) do
            if player and player ~= localPlayer and player:FindFirstChild("Is_Wanted") then
                if ESP.Players[player] then
                    ESP:RemovePlayer(player)
                end
            end
        end
    elseif team == "Civilian" then
        for _, player in pairs(players:GetPlayers()) do
            if player and player ~= localPlayer and player.Team and player.Team.Name == team and not player:FindFirstChild("Is_Wanted") then
                if ESP.Players[player] then
                    ESP:RemovePlayer(player)
                end
            end
        end
    else
        for _, player in pairs(players:GetPlayers()) do
            if player and player ~= localPlayer and player.Team and player.Team.Name == team then
                if ESP.Players[player] then
                    ESP:RemovePlayer(player)
                end
            end
        end
    end
end

-- Instance ESP handling
function ESP:AddInstance(instance, color)
    if self.Instances[instance] then return end

    if instance:IsA("Model") then
        if not instance.PrimaryPart then
            warn("[ESP] Skipped model because it has no PrimaryPart:", instance:GetFullName())
            return
        end
        if not instance.PrimaryPart.Position then
            warn("[ESP] Skipped model because couldn't find position:", instance.PrimaryPart:GetFullName())
            return
        end
        instance = instance.PrimaryPart
    end

    if instance:IsA("BasePart") then
        if not instance.Position then
            warn("[ESP] Skipped part because couldn't find position:", instance:GetFullName())
            return
        end
    end

    color = color or Color3.new(1,1,1)

    local drawings = {
        Box = createBox(color),
        NameTag = createNameTag(color),
        Distance = createDistance(Color3.new(1,1,1)),
        HeadDot = createHeadDot(color)
    }

    self.DrawingObjects[instance] = drawings
    self.Instances[instance] = true

    local conn = instance.Destroying:Connect(function()
        cleanupDrawings(instance)
        cleanupConnections(instance)
        self.Instances[instance] = nil
    end)
    self.Connections[instance] = conn
end

function ESP:RemoveInstance(instance)
    if instance:IsA("Model") and instance.PrimaryPart then
        instance = instance.PrimaryPart
    end

    if self.Instances[instance] then
        cleanupDrawings(instance)
        cleanupConnections(instance)
        self.Instances[instance] = nil
    end
end

-- Clear methods
function ESP:ClearPlayers()
    for player, _ in pairs(self.Players) do
        cleanupDrawings(player)
        cleanupConnections(player)
    end
    tableClear(self.Players)
end

function ESP:ClearInstances()
    for instance, _ in pairs(self.Instances) do
        cleanupDrawings(instance)
        cleanupConnections(instance)
    end
    tableClear(self.Instances)
end

function ESP:Clear()
    -- Clear players
    for player, _ in pairs(self.Players) do
        cleanupDrawings(player)
        cleanupConnections(player)
    end
    tableClear(self.Players)
    
    -- Clear instances
    for instance, _ in pairs(self.Instances) do
        cleanupDrawings(instance)
        cleanupConnections(instance)
    end
    tableClear(self.Instances)
    
    -- Clear global connections
    for key, connection in pairs(self.Connections) do
        if typeof(key) ~= "Instance" then  -- Skip player/instance connections (already handled above)
            if typeof(connection) == "table" then
                for _, conn in pairs(connection) do
                    conn:Disconnect()
                end
            else
                connection:Disconnect()
            end
        end
    end
    
    -- Clear team tracking if it exists
    if self.TeamTracking then
        tableClear(self.TeamTracking)
    end
    
    -- Clear remaining tables
    tableClear(self.Connections)
    tableClear(self.DrawingObjects)
end
-- Character persistence function
local function makeCharacterPersistent(character)
    if character and character.ModelStreamingMode ~= Enum.ModelStreamingMode.Persistent then
        character.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
    end
end

local function handlePlayer(player)
    if player.Character then
        makeCharacterPersistent(player.Character)
    end
    
    player.CharacterAdded:Connect(makeCharacterPersistent)
end

-- Cache for player character checks to reduce property lookups
local characterCache = {}
local function getPlayerCharacterParts(player)
    local character = player.Character
    
    if not character then 
        return nil 
    end
    
    local cachedData = characterCache[player]
    if not cachedData then
        cachedData = {
            lastCheck = 0,
            hasRequiredParts = false,
            parts = {}
        }
        characterCache[player] = cachedData
    end
    
    -- Only check every 30 frames (approx 0.5 seconds) if character has required parts
    local currentTime = os.clock()
    if currentTime - cachedData.lastCheck > 0.5 then
        cachedData.lastCheck = currentTime
        
        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        local humanoid = character:FindFirstChild("Humanoid")
        local head = character:FindFirstChild("Head")
        
        cachedData.hasRequiredParts = humanoidRootPart and humanoid and head and 
                                      humanoid.Health > 0.2 and
                                      localPlayer and localPlayer.Character and 
                                      localPlayer.Character:FindFirstChild("HumanoidRootPart")
        
        if cachedData.hasRequiredParts then
            -- Cache all character parts
            cachedData.parts = {}
            for _, part in ipairs(character:GetChildren()) do
                if part:IsA("BasePart") then
                    tableInsert(cachedData.parts, part)
                end
            end
            
            cachedData.humanoidRootPart = humanoidRootPart
            cachedData.head = head
        end
    end
    
    return cachedData.hasRequiredParts and cachedData or nil
end

-- Initialize players
for _, player in pairs(players:GetPlayers()) do
    if player ~= localPlayer then
        handlePlayer(player)
    end
end
players.PlayerAdded:Connect(handlePlayer)

-- Main rendering loop with optimizations
local lastUpdateTime = 0
local updateInterval = 1/60  -- 60 updates per second max

runService.RenderStepped:Connect(function()
    if not ESP.Settings.MasterToggle then return end
    
    local currentTime = os.clock()
    if currentTime - lastUpdateTime < updateInterval then return end
    lastUpdateTime = currentTime
    
    local playerBoxSettings = ESP.Settings.playerBoxes
    local playerNameTagSettings = ESP.Settings.playerNameTags
    local playerDistanceSettings = ESP.Settings.playerDistances
    local playerHeadDotSettings = ESP.Settings.playerHeadDots
    
    local instanceBoxSettings = ESP.Settings.instanceBoxes
    local instanceNameTagSettings = ESP.Settings.instanceNameTags
    local instanceDistanceSettings = ESP.Settings.instanceDistances
    local instanceHeadDotSettings = ESP.Settings.instanceHeadDots
    
    local localRootPart = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
    
    -- Process players in batches to distribute load
    for target, _ in pairs(ESP.Players) do
        local cachedCharacter = getPlayerCharacterParts(target)
        local drawing = ESP.DrawingObjects[target]
        
        if drawing then
            if cachedCharacter and cachedCharacter.hasRequiredParts and localRootPart then
                local minX, minY, maxX, maxY, visible = calculateBoxBoundaries(cachedCharacter.parts, cachedCharacter)
                
                if visible then
                    -- Box
                    drawing.Box.Size = Vector2New(maxX - minX, maxY - minY)
                    drawing.Box.Position = Vector2New(minX, minY)
                    drawing.Box.Visible = playerBoxSettings
                    
                    -- Name tag
                    drawing.NameTag.Text = target.Name
                    drawing.NameTag.Position = Vector2New((minX + maxX) / 2, minY - 20)
                    drawing.NameTag.Visible = playerNameTagSettings
                    
                    -- Distance
                    local distance = mathFloor((cachedCharacter.humanoidRootPart.Position - localRootPart.Position).Magnitude)
                    drawing.Distance.Text = "[" .. tostring(distance) .. "m]"
                    drawing.Distance.Position = Vector2New((minX + maxX) / 2, maxY + 5)
                    drawing.Distance.Visible = playerDistanceSettings
                    
                    -- Head dot
                    local headScreen, headVisible = camera:WorldToViewportPoint(cachedCharacter.head.Position)
                    if headVisible then
                        drawing.HeadDot.Position = Vector2New(headScreen.X, headScreen.Y)
                        drawing.HeadDot.Visible = playerHeadDotSettings
                    else
                        drawing.HeadDot.Visible = false
                    end
                else
                    drawing.Box.Visible = false
                    drawing.NameTag.Visible = false
                    drawing.Distance.Visible = false
                    drawing.HeadDot.Visible = false
                end
            else
                drawing.Box.Visible = false
                drawing.NameTag.Visible = false
                drawing.Distance.Visible = false
                drawing.HeadDot.Visible = false
            end
        end
    end
    
    -- Process instances in batches to distribute load
    for instance, _ in pairs(ESP.Instances) do
        if instance and instance:IsA("BasePart") then
            local drawing = ESP.DrawingObjects[instance]
            if drawing and localRootPart then
                local size = instance.Size
                local cf = instance.CFrame
                local halfSizeX, halfSizeY, halfSizeZ = size.X/2, size.Y/2, size.Z/2
                
                -- Calculate the 8 corners of the part
                local corners = {
                    cf:PointToWorldSpace(Vector3New(-halfSizeX, -halfSizeY, -halfSizeZ)),
                    cf:PointToWorldSpace(Vector3New(halfSizeX, -halfSizeY, -halfSizeZ)),
                    cf:PointToWorldSpace(Vector3New(-halfSizeX, halfSizeY, -halfSizeZ)),
                    cf:PointToWorldSpace(Vector3New(halfSizeX, halfSizeY, -halfSizeZ)),
                    cf:PointToWorldSpace(Vector3New(-halfSizeX, -halfSizeY, halfSizeZ)),
                    cf:PointToWorldSpace(Vector3New(halfSizeX, -halfSizeY, halfSizeZ)),
                    cf:PointToWorldSpace(Vector3New(-halfSizeX, halfSizeY, halfSizeZ)),
                    cf:PointToWorldSpace(Vector3New(halfSizeX, halfSizeY, halfSizeZ))
                }
                
                local minX, minY, maxX, maxY = mathHuge, mathHuge, -mathHuge, -mathHuge
                local visiblePoints = false
                
                for _, corner in ipairs(corners) do
                    local screenPoint, visible = camera:WorldToViewportPoint(corner)
                    if visible then
                        visiblePoints = true
                        minX = mathMin(minX, screenPoint.X)
                        minY = mathMin(minY, screenPoint.Y)
                        maxX = mathMax(maxX, screenPoint.X)
                        maxY = mathMax(maxY, screenPoint.Y)
                    end
                end
                
                if visiblePoints then
                    local padding = 2
                    minX, minY = minX - padding, minY - padding
                    maxX, maxY = maxX + padding, maxY + padding
                    
                    -- Box
                    drawing.Box.Size = Vector2New(maxX - minX, maxY - minY)
                    drawing.Box.Position = Vector2New(minX, minY)
                    drawing.Box.Visible = instanceBoxSettings
                    
                    -- Name tag
                    drawing.NameTag.Text = instance:GetAttribute("ESPDisplayName") or instance.Name
                    drawing.NameTag.Position = Vector2New((minX + maxX) / 2, minY - 20)
                    drawing.NameTag.Visible = instanceNameTagSettings
                    
                    -- Distance
                    local distance = mathFloor((instance.Position - localRootPart.Position).Magnitude)
                    drawing.Distance.Text = "[" .. tostring(distance) .. "m]"
                    drawing.Distance.Position = Vector2New((minX + maxX) / 2, maxY + 5)
                    drawing.Distance.Visible = instanceDistanceSettings
                    
                    -- Head dot
                    local centerScreen, centerVisible = camera:WorldToViewportPoint(instance.Position)
                    if centerVisible then
                        drawing.HeadDot.Position = Vector2New(centerScreen.X, centerScreen.Y)
                        drawing.HeadDot.Visible = instanceHeadDotSettings
                    else
                        drawing.HeadDot.Visible = false
                    end
                else
                    drawing.Box.Visible = false
                    drawing.NameTag.Visible = false
                    drawing.Distance.Visible = false
                    drawing.HeadDot.Visible = false
                end
            end
        end
    end
end)

return ESP
