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
    NameTags = true,
    Thickness = 2,
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
    nameTag.Size = 16
    nameTag.Font = Drawing.Fonts["Plex"]
    nameTag.Center = true
    nameTag.Outline = true
    nameTag.OutlineColor = Color3.fromRGB(0,0,0)
    return nameTag
end

-- Internal function: WorldToScreen helper
local function worldToScreen(pos)
    local screenPos, onScreen = camera:WorldToViewportPoint(pos)
    return Vector2.new(screenPos.X, screenPos.Y), onScreen
end

-- Add a player
function ESP:AddPlayer(player)
    if self.Players[player] then return end

    local drawings = {
        Box = createBox(self.Settings.PlayerColor),
        NameTag = createNameTag(Color3.new(1,1,1))
    }

    self.DrawingObjects[player] = drawings
    self.Players[player] = true

    -- Remove if player leaves
    local conn = player.AncestryChanged:Connect(function(_, parent)
        if not parent then
            if self.DrawingObjects[player] then
                self.DrawingObjects[player]:Remove()
                self.DrawingObjects[player] = nil
                self.Players[player] = nil
            end
            if self.Connections[player] then
                self.Connections:Disconnect()
                self.Connections[player] = nil
            end
        end
    end)
    self.Connections[player] = conn
end

-- Add a custom instance
function ESP:AddInstance(instance)
    if self.Instances[instance] then return end

    local drawings = {
        Box = createBox(self.Settings.InstanceColor),
        NameTag = createNameTag(Color3.new(1,1,1))
    }

    self.DrawingObjects[instance] = drawings
    self.Instances[instance] = true

    -- Remove if instance is destroyed
    local conn = instance.Destroying:Connect(function()
        if self.DrawingObjects[instance] then
            self.DrawingObjects[instance]:Remove()
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
        if drawing then
            drawing:Remove()
        end
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

-- Internal update loop
runService.RenderStepped:Connect(function()
    for target, _ in pairs(ESP.Players) do
        if target.Character and target.Character:FindFirstChild("HumanoidRootPart") and target.Character:FindFirstChild("Humanoid") and target.Character:FindFirstChild("Humanoid").Health > 0.2 then
            local character = target.Character
            local humanoidRootPart = character.HumanoidRootPart
            local humanoid = character.Humanoid
            local head = character.Head
            
            local drawing = ESP.DrawingObjects[target]
            
            if drawing then
                local hrpPosition, onScreen = camera:WorldToViewportPoint(humanoidRootPart.Position)
                if onScreen then
                    local sizeX, sizeY = 0, 0
                    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge

                    for _, part in pairs(character:GetChildren()) do
                        if part:IsA("BasePart") then
                            local topLeft = workspace.CurrentCamera:WorldToViewportPoint(part.Position + Vector3.new(-part.Size.X/2, part.Size.Y/2, 0))
                            local topRight = workspace.CurrentCamera:WorldToViewportPoint(part.Position + Vector3.new(part.Size.X/2, part.Size.Y/2, 0))
                            local bottomLeft = workspace.CurrentCamera:WorldToViewportPoint(part.Position + Vector3.new(-part.Size.X/2, -part.Size.Y/2, 0))
                            local bottomRight = workspace.CurrentCamera:WorldToViewportPoint(part.Position + Vector3.new(part.Size.X/2, -part.Size.Y/2, 0))
                            
                            -- Update bounds
                            minX = math.min(minX, topLeft.X, topRight.X, bottomLeft.X, bottomRight.X)
                            minY = math.min(minY, topLeft.Y, topRight.Y, bottomLeft.Y, bottomRight.Y)
                            maxX = math.max(maxX, topLeft.X, topRight.X, bottomLeft.X, bottomRight.X)
                            maxY = math.max(maxY, topLeft.Y, topRight.Y, bottomLeft.Y, bottomRight.Y)
                        end
                    end

                    local padding = 2
                    minX, minY = minX - padding, minY - padding
                    maxX, maxY = maxX + padding, maxY + padding

                    drawing.box.Size = Vector2.new(maxX - minX, maxY - minY)
                    drawing.box.Position = Vector2.new(minX, minY)
                    drawing.NameTag.Text = target.Name
                    drawing.NameTag.Position = Vector2.new((minX + maxX) / 2, minY - 20)
                else
                    drawing.Box.Visible = false
                    drawing.NameTag.Visible = false
                end
            end
        else
            ESP.DrawingObjects[target].Box.Visible = false
            ESP.DrawingObjects[target].NameTag.Visible = false
        end
    end

    for instance, _ in pairs(ESP.Instances) do
        if instance:IsA("BasePart") then
            local pos = instance.Position
            local screenPos, onScreen = worldToScreen(pos)

            local box = ESP.DrawingObjects[instance]
            if box then
                box.Visible = onScreen
                if onScreen then
                    box.Size = Vector2.new(30, 30)
                    box.Position = screenPos - box.Size/2
                end
            end
        end
    end
end)

return ESP
