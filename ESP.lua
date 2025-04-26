-- ESP Library
local ESP = {
    Players = {},
    Instances = {},
    DrawingObjects = {},
    Connections = {}
}

-- Settings
ESP.Settings = {
    PlayerColor = Color3.fromRGB(255, 0, 0),
    InstanceColor = Color3.fromRGB(0, 255, 0),
    playerBoxes = true,
    playerNameTags = true,
    playerHeadDots = true,
    playerDistances = true,
    instanceBoxes = true,
    instanceNameTags = true,
    instanceHeadDots = false,
    instanceDistances = true,
    Thickness = 1.25,
    TeamCheck = false
}

local camera = workspace.CurrentCamera
local runService = game:GetService("RunService")
local localPlayer = game:GetService("Players").LocalPlayer

-- Internal function: Create box
local function createBox(color)
    local box = Drawing.new("Square")
    box.Color = color
    box.Thickness = ESP.Settings.Thickness
    box.Filled = false
    box.Visible = false
    return box
end

local function createNameTag(color)
    local nameTag = Drawing.new("Text")
    nameTag.Visible = false
    nameTag.Transparency = 1
    nameTag.Color = color
    nameTag.Size = 14
    nameTag.Font = Drawing.Fonts["Plex"]
    nameTag.Center = true
    nameTag.Outline = true
    nameTag.OutlineColor = Color3.fromRGB(0,0,0)
    return nameTag
end

local function createDistance(color)
    local distance = Drawing.new("Text")
    distance.Visible = false
    distance.Transparency = 1
    distance.Color = color
    distance.Size = 14
    distance.Font = Drawing.Fonts["Plex"]
    distance.Center = true
    distance.Outline = true
    distance.OutlineColor = Color3.fromRGB(0,0,0)
    return distance
end

local function createHeadDot(color)
    local headDot = Drawing.new("Circle")
    headDot.Visible = false
    headDot.Transparency = 1
    headDot.Color = color
    headDot.NumSides = 32
    headDot.Radius = 4
    headDot.Thickness = 1
    return headDot
end

-- Add a player
function ESP:AddPlayer(player)
    if self.Players[player] then return end

    local drawings = {
        Box = createBox(self.Settings.PlayerColor),
        NameTag = createNameTag(Color3.new(1,1,1)),
        Distance = createDistance(Color3.new(1,1,1)),
        HeadDot = createHeadDot(Color3.new(1,1,1))
    }

    self.DrawingObjects[player] = drawings
    self.Players[player] = true

    -- Remove if player leaves
    local conn = player.AncestryChanged:Connect(function(_, parent)
        if not parent then
            if self.DrawingObjects[player] then
                self.DrawingObjects[player].Box:Destroy()
                self.DrawingObjects[player].NameTag:Destroy()
                self.DrawingObjects[player].Distance:Destroy()
                self.DrawingObjects[player].HeadDot:Destroy()
                self.DrawingObjects[player] = nil
                self.Players[player] = nil
            end
            if self.Connections[player] then
                self.Connections[player]:Disconnect()
                self.Connections[player] = nil
            end
        end
    end)
    self.Connections[player] = conn
end

-- Add a custom instance
function ESP:AddInstance(instance)
    if self.Instances[instance] then return end

    if instance:IsA("Model") then
        if not instance.PrimaryPart then warn("[ESP] Skipped model because it has no PrimaryPart:", instance:GetFullName()) return end
        if not instance.PrimaryPart.Position then warn("[ESP] Skipped model because couldn't find position:", instance.PrimaryPart:GetFullName()) return end
        instance = instance.PrimaryPart
    end

    if instance:IsA("BasePart") then
        if not instance.Position then warn("[ESP] Skipped part because couldn't find position:", instance:GetFullName()) return end
    end

    local drawings = {
        Box = createBox(self.Settings.InstanceColor),
        NameTag = createNameTag(Color3.new(1,1,1)),
        Distance = createDistance(Color3.new(1,1,1)),
        HeadDot = createHeadDot(Color3.new(1,1,1))
    }

    self.DrawingObjects[instance] = drawings
    self.Instances[instance] = true

    -- Remove if instance is destroyed
    local conn = instance.Destroying:Connect(function()
        if self.DrawingObjects[instance] then
            self.DrawingObjects[instance].Box:Destroy()
            self.DrawingObjects[instance].NameTag:Destroy()
            self.DrawingObjects[instance].Distance:Destroy()
            self.DrawingObjects[instance].HeadDot:Destroy()
            self.DrawingObjects[instance] = nil
            self.Instances[instance] = nil
        end
        if self.Connections[instance] then
            self.Connections[instance]:Disconnect()
            self.Connections[instance] = nil
        end
    end)
    self.Connections[instance] = conn
end

function ESP:Clear()
    for obj, drawing in pairs(self.DrawingObjects) do
        if drawing.Box then drawing.Box:Destroy() end
        if drawing.NameTag then drawing.NameTag:Destroy() end
        if drawing.Distance then drawing.Distance:Destroy() end
        if drawing.HeadDot then drawing.HeadDot:Destroy() end
    end

    for obj, conn in pairs(self.Connections) do
        if conn then
            conn:Disconnect()
        end
    end

    table.clear(self.DrawingObjects)
    table.clear(self.Players)
    table.clear(self.Instances)
    table.clear(self.Connections)
end

runService.RenderStepped:Connect(function()
    for target, _ in pairs(ESP.Players) do
        if target.Character and target.Character:FindFirstChild("HumanoidRootPart") and target.Character:FindFirstChild("Humanoid") and target.Character:FindFirstChild("Humanoid").Health > 0.2 and localPlayer and localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local character = target.Character
            local humanoidRootPart = character.HumanoidRootPart
            local humanoid = character.Humanoid
            local head = character.Head

            local drawing = ESP.DrawingObjects[target]

            if drawing then
                local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
                local points = {}

                -- Collect screen points of all parts
                for _, part in ipairs(character:GetChildren()) do
                    if part:IsA("BasePart") then
                        local size = part.Size
                        local cf = part.CFrame

                        -- 8 corners of the part
                        local corners = {
                            cf:PointToWorldSpace(Vector3.new(-size.X/2, -size.Y/2, -size.Z/2)),
                            cf:PointToWorldSpace(Vector3.new(size.X/2, -size.Y/2, -size.Z/2)),
                            cf:PointToWorldSpace(Vector3.new(-size.X/2, size.Y/2, -size.Z/2)),
                            cf:PointToWorldSpace(Vector3.new(size.X/2, size.Y/2, -size.Z/2)),
                            cf:PointToWorldSpace(Vector3.new(-size.X/2, -size.Y/2, size.Z/2)),
                            cf:PointToWorldSpace(Vector3.new(size.X/2, -size.Y/2, size.Z/2)),
                            cf:PointToWorldSpace(Vector3.new(-size.X/2, size.Y/2, size.Z/2)),
                            cf:PointToWorldSpace(Vector3.new(size.X/2, size.Y/2, size.Z/2)),
                        }

                        for _, corner in ipairs(corners) do
                            local screenPoint, visible = camera:WorldToViewportPoint(corner)
                            if visible then
                                table.insert(points, screenPoint)
                            end
                        end
                    end
                end

                if #points > 0 then
                    for _, point in ipairs(points) do
                        minX = math.min(minX, point.X)
                        minY = math.min(minY, point.Y)
                        maxX = math.max(maxX, point.X)
                        maxY = math.max(maxY, point.Y)
                    end

                    local padding = 2
                    minX, minY = minX - padding, minY - padding
                    maxX, maxY = maxX + padding, maxY + padding

                    drawing.Box.Size = Vector2.new(maxX - minX, maxY - minY)
                    drawing.Box.Position = Vector2.new(minX, minY)
                    drawing.NameTag.Text = target.Name
                    drawing.NameTag.Position = Vector2.new((minX + maxX) / 2, minY - 20)
                    drawing.Distance.Text = "[" .. tostring(math.floor((humanoidRootPart.Position - localPlayer.Character.HumanoidRootPart.Position).Magnitude)) .. "m]"
                    drawing.Distance.Position = Vector2.new((minX + maxX) / 2, maxY + 5)

                    local headScreen, headVisible = camera:WorldToViewportPoint(head.Position)
                    if headVisible then
                        drawing.HeadDot.Position = Vector2.new(headScreen.X, headScreen.Y)
                        if ESP.Settings.playerHeadDots then drawing.HeadDot.Visible = true else drawing.HeadDot.Visible = false end
                    else
                        drawing.HeadDot.Visible = false
                    end

                    if ESP.Settings.playerBoxes then drawing.Box.Visible = true else drawing.Box.Visible = false end
                    if ESP.Settings.playerNameTags then drawing.NameTag.Visible = true else drawing.NameTag.Visible = false end
                    if ESP.Settings.playerDistances then drawing.Distance.Visible = true else drawing.Distance.Visible = false end
                else
                    drawing.Box.Visible = false
                    drawing.NameTag.Visible = false
                    drawing.Distance.Visible = false
                    drawing.HeadDot.Visible = false
                end
            end
        else
            if ESP.DrawingObjects[target] then
                ESP.DrawingObjects[target].Box.Visible = false
                ESP.DrawingObjects[target].NameTag.Visible = false
                ESP.DrawingObjects[target].Distance.Visible = false
                ESP.DrawingObjects[target].HeadDot.Visible = false
            end
        end
    end

    for instance, _ in pairs(ESP.Instances) do
        if instance and instance:IsA("BasePart") then
            local drawing = ESP.DrawingObjects[instance]
            if drawing then
                local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
                local points = {}

                local size = instance.Size
                local cf = instance.CFrame

                -- 8 corners
                local corners = {
                    cf:PointToWorldSpace(Vector3.new(-size.X/2, -size.Y/2, -size.Z/2)),
                    cf:PointToWorldSpace(Vector3.new(size.X/2, -size.Y/2, -size.Z/2)),
                    cf:PointToWorldSpace(Vector3.new(-size.X/2, size.Y/2, -size.Z/2)),
                    cf:PointToWorldSpace(Vector3.new(size.X/2, size.Y/2, -size.Z/2)),
                    cf:PointToWorldSpace(Vector3.new(-size.X/2, -size.Y/2, size.Z/2)),
                    cf:PointToWorldSpace(Vector3.new(size.X/2, -size.Y/2, size.Z/2)),
                    cf:PointToWorldSpace(Vector3.new(-size.X/2, size.Y/2, size.Z/2)),
                    cf:PointToWorldSpace(Vector3.new(size.X/2, size.Y/2, size.Z/2)),
                }

                for _, corner in ipairs(corners) do
                    local screenPoint, visible = camera:WorldToViewportPoint(corner)
                    if visible then
                        table.insert(points, screenPoint)
                    end
                end

                if #points > 0 then
                    for _, point in ipairs(points) do
                        minX = math.min(minX, point.X)
                        minY = math.min(minY, point.Y)
                        maxX = math.max(maxX, point.X)
                        maxY = math.max(maxY, point.Y)
                    end

                    local padding = 2
                    minX, minY = minX - padding, minY - padding
                    maxX, maxY = maxX + padding, maxY + padding

                    drawing.Box.Size = Vector2.new(maxX - minX, maxY - minY)
                    drawing.Box.Position = Vector2.new(minX, minY)
                    drawing.NameTag.Text = instance:GetAttribute("ESPDisplayName") or instance.Name
                    drawing.NameTag.Position = Vector2.new((minX + maxX) / 2, minY - 20)
                    drawing.Distance.Text = "[" .. tostring(math.floor((instance.Position - localPlayer.Character.HumanoidRootPart.Position).Magnitude)) .. "m]"
                    drawing.Distance.Position = Vector2.new((minX + maxX) / 2, maxY + 5)

                    local centerScreen, centerVisible = camera:WorldToViewportPoint(instance.Position)
                    if centerVisible then
                        drawing.HeadDot.Position = Vector2.new(centerScreen.X, centerScreen.Y)
                        if ESP.Settings.instanceHeadDots then drawing.HeadDot.Visible = true else drawing.HeadDot.Visible = false end
                    else
                        drawing.HeadDot.Visible = false
                    end

                    if ESP.Settings.instanceBoxes then drawing.Box.Visible = true else drawing.Box.Visible = false end
                    if ESP.Settings.instanceNameTags then drawing.NameTag.Visible = true else drawing.NameTag.Visible = false end
                    if ESP.Settings.instanceDistances then drawing.Distance.Visible = true else drawing.Distance.Visible = false end
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
