-- ESP Library
local ESP = {
    Players = {},
    Instances = {},
    DrawingObjects = {}
}

-- Settings
ESP.Settings = {
    PlayerColor = Color3.fromRGB(255, 0, 0),
    InstanceColor = Color3.fromRGB(0, 255, 0),
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

-- Internal function: WorldToScreen helper
local function worldToScreen(pos)
    local screenPos, onScreen = camera:WorldToViewportPoint(pos)
    return Vector2.new(screenPos.X, screenPos.Y), onScreen
end

-- Add a player
function ESP:AddPlayer(player)
    if self.Players[player] then return end

    local box = createBox(self.Settings.PlayerColor)
    self.DrawingObjects[player] = box
    self.Players[player] = true

    -- Remove if player leaves
    player.AncestryChanged:Connect(function(_, parent)
        if not parent then
            if self.DrawingObjects[player] then
                self.DrawingObjects[player]:Remove()
                self.DrawingObjects[player] = nil
                self.Players[player] = nil
            end
        end
    end)
end

-- Add a custom instance
function ESP:AddInstance(instance)
    if self.Instances[instance] then return end

    local box = createBox(self.Settings.InstanceColor)
    self.DrawingObjects[instance] = box
    self.Instances[instance] = true

    -- Remove if instance is destroyed
    instance.Destroying:Connect(function()
        if self.DrawingObjects[instance] then
            self.DrawingObjects[instance]:Remove()
            self.DrawingObjects[instance] = nil
            self.Instances[instance] = nil
        end
    end)
end

-- Internal update loop
runService.RenderStepped:Connect(function()
    for target, _ in pairs(ESP.Players) do
        if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
            local pos = target.Character.HumanoidRootPart.Position
            local screenPos, onScreen = worldToScreen(pos)

            local box = ESP.DrawingObjects[target]
            if box then
                box.Visible = onScreen
                if onScreen then
                    box.Size = Vector2.new(40, 40)
                    box.Position = screenPos - box.Size/2
                end
            end
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