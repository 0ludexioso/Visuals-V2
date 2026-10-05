-- ludexioso_visuals
-- Native Overdrive H addon

local shared = odh_shared_plugins

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local mainTab = shared.CreateTab(
    "ludexioso_visuals",
    "/0ludexioso/ludexioso_visuals/refs/heads/main/icon"
)

local CFG_FOLDER = "ludexioso_visuals"
local CFG_FILE = CFG_FOLDER .. "/config.json"
local ConfigData = {}

local function ensureConfigFolder()
    if makefolder and isfolder and not isfolder(CFG_FOLDER) then
        pcall(makefolder, CFG_FOLDER)
    end
end

local function loadConfig()
    ensureConfigFolder()
    if isfile and readfile and isfile(CFG_FILE) then
        local ok, data = pcall(function()
            return HttpService:JSONDecode(readfile(CFG_FILE))
        end)
        if ok and type(data) == "table" then
            ConfigData = data
        end
    end
end

local function saveConfig()
    ensureConfigFolder()
    if writefile then
        pcall(function()
            writefile(CFG_FILE, HttpService:JSONEncode(ConfigData))
        end)
    end
end

local function C(key, default)
    local value = ConfigData[key]
    if value == nil then
        return default
    end
    if typeof(default) == "Color3" and type(value) == "table" then
        return Color3.fromRGB(value[1], value[2], value[3])
    end
    return value
end

local function SetCfg(key, value)
    if typeof(value) == "Color3" then
        ConfigData[key] = {
            math.floor(value.R * 255),
            math.floor(value.G * 255),
            math.floor(value.B * 255),
        }
    else
        ConfigData[key] = value
    end
    saveConfig()
end

local function addToggle(section, name, defaultValue, callback)
    local state = false
    local rawToggle
    rawToggle = section:AddToggle(name, function(newState)
        state = newState
        callback(newState)
    end)

    local controller = {}
    function controller:Set(newState)
        newState = not not newState
        if newState ~= state then
            rawToggle()
        end
    end
    function controller:Get()
        return state
    end

    if defaultValue then
        task.defer(rawToggle)
    end
    return controller
end

local function addDropdown(section, name, items, defaultValue, callback)
    local controller = section:AddDropdown(name, items, callback)
    if defaultValue and controller and controller.Select then
        task.defer(function()
            pcall(function()
                controller:Select(defaultValue)
            end)
        end)
    end
    return controller
end

loadConfig()

local player = LocalPlayer
local camera = workspace.CurrentCamera

-- =========================================================
-- COSMETIC: TRAIL
-- =========================================================

local trailSection = mainTab:AddSection("Trail", "Cosmetic")
local trailEnabled = C("trailEnabled", false)
local trailIsGradient = C("trailIsGradient", false)
local trailRainbow = C("trailRainbow", false)
local trailColorStatic = C("trailColorStatic", Color3.fromRGB(0, 255, 255))
local trailGradient1 = C("trailGradient1", Color3.fromRGB(0, 86, 255))
local trailGradient2 = C("trailGradient2", Color3.fromRGB(255, 0, 0))
local trailLifetime = C("trailLifetime", 0.5)
local trailTransparencyStart = C("trailTransparencyStart", 0)
local trailObject = nil
local trailConnection = nil

local function removeTrail()
    if trailObject then
        trailObject:Destroy()
        trailObject = nil
    end
    local char = player.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local a0 = hrp:FindFirstChild("LV_TrailAttach0")
            local a1 = hrp:FindFirstChild("LV_TrailAttach1")
            if a0 then a0:Destroy() end
            if a1 then a1:Destroy() end
        end
    end
end

local function updateTrail()
    if not trailObject then return end
    trailObject.Lifetime = trailLifetime
    trailObject.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, trailTransparencyStart),
        NumberSequenceKeypoint.new(1, 1),
    })
    if trailIsGradient then
        trailObject.Color = ColorSequence.new(trailGradient1, trailGradient2)
    elseif trailRainbow then
        trailObject.Color = ColorSequence.new(Color3.fromHSV((tick() % 5) / 5, 1, 1))
    else
        trailObject.Color = ColorSequence.new(trailColorStatic)
    end
end

local function createTrail()
    removeTrail()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local a0 = Instance.new("Attachment")
    a0.Name = "LV_TrailAttach0"
    a0.Position = Vector3.new(0, 2, 0)
    a0.Parent = hrp

    local a1 = Instance.new("Attachment")
    a1.Name = "LV_TrailAttach1"
    a1.Position = Vector3.new(0, -2, 0)
    a1.Parent = hrp

    local trail = Instance.new("Trail")
    trail.Name = "LV_Trail"
    trail.Attachment0 = a0
    trail.Attachment1 = a1
    trail.LightEmission = 0.2
    trail.Parent = char
    trailObject = trail
    updateTrail()
end

addToggle(trailSection, "Enable Trail", trailEnabled, function(state)
    trailEnabled = state
    SetCfg("trailEnabled", state)
    if state then
        createTrail()
        if trailConnection then trailConnection:Disconnect() end
        trailConnection = RunService.Heartbeat:Connect(function()
            if trailRainbow and trailEnabled then
                updateTrail()
            end
        end)
    else
        if trailConnection then
            trailConnection:Disconnect()
            trailConnection = nil
        end
        removeTrail()
    end
end)

addToggle(trailSection, "Use Gradient Mode", trailIsGradient, function(state)
    trailIsGradient = state
    SetCfg("trailIsGradient", state)
    updateTrail()
end)

addToggle(trailSection, "Rainbow (Simple Mode)", trailRainbow, function(state)
    trailRainbow = state
    SetCfg("trailRainbow", state)
    updateTrail()
end)

trailSection:AddColorpicker("Static Color", trailColorStatic, function(color)
    trailColorStatic = color
    SetCfg("trailColorStatic", color)
    updateTrail()
end)

trailSection:AddColorpicker("Gradient Color 1", trailGradient1, function(color)
    trailGradient1 = color
    SetCfg("trailGradient1", color)
    updateTrail()
end)

trailSection:AddColorpicker("Gradient Color 2", trailGradient2, function(color)
    trailGradient2 = color
    SetCfg("trailGradient2", color)
    updateTrail()
end)

trailSection:AddSlider("Trail Lifetime", 0.1, 3, trailLifetime, function(value)
    trailLifetime = value
    SetCfg("trailLifetime", value)
    updateTrail()
end)

trailSection:AddSlider("Trail Transparency Start", 0, 1, trailTransparencyStart, function(value)
    trailTransparencyStart = value
    SetCfg("trailTransparencyStart", value)
    updateTrail()
end)

-- =========================================================
-- COSMETIC: SKIN
-- =========================================================

local skinSection = mainTab:AddSection("Skin", "Cosmetic")
local ffEnabled = C("ffEnabled", false)
local ffRainbow = C("ffRainbow", false)
local ffColor = C("ffColor", Color3.fromRGB(128, 128, 128))
local skinTrailEnabled = C("skinTrailEnabled", false)
local skinTrailColor = C("skinTrailColor", Color3.fromRGB(255, 0, 0))
local skinTrailLife = C("skinTrailLife", 0.5)
local originalAppearance = {}
local ffConnection = nil

local function saveOriginalAppearance(char)
    originalAppearance = {}
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            originalAppearance[part] = {
                Color = part.Color,
                Material = part.Material,
            }
        end
    end
end

local function applyForceField()
    local char = player.Character
    if not char then return end
    if next(originalAppearance) == nil then
        saveOriginalAppearance(char)
    end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Material = Enum.Material.ForceField
            part.Color = ffRainbow and Color3.fromHSV((tick() % 5) / 5, 1, 1) or ffColor
        end
    end
end

local function removeForceField()
    for part, data in pairs(originalAppearance) do
        if part and part.Parent then
            part.Color = data.Color
            part.Material = data.Material
        end
    end
    originalAppearance = {}
end

local function clearSkinTrail()
    local char = player.Character
    if not char then return end
    for _, obj in ipairs(char:GetDescendants()) do
        if obj.Name == "LV_SkinTrail" or obj.Name == "LV_SkinPointer1" or obj.Name == "LV_SkinPointer2" then
            obj:Destroy()
        end
    end
end

local function applySkinTrail()
    clearSkinTrail()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not char or not hrp then return end

    for _, part in ipairs(char:GetChildren()) do
        if part:IsA("BasePart") and part ~= hrp then
            local a0 = Instance.new("Attachment")
            a0.Name = "LV_SkinPointer1"
            a0.Parent = part

            local a1 = Instance.new("Attachment")
            a1.Name = "LV_SkinPointer2"
            a1.Parent = hrp

            local trail = Instance.new("Trail")
            trail.Name = "LV_SkinTrail"
            trail.Texture = "rbxassetid://1390780157"
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(skinTrailColor)
            trail.Lifetime = skinTrailLife
            trail.Parent = part
        end
    end
end

local function updateSkinTrail()
    local char = player.Character
    if not char then return end
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("Trail") and obj.Name == "LV_SkinTrail" then
            obj.Color = ColorSequence.new(skinTrailColor)
            obj.Lifetime = skinTrailLife
        end
    end
end

addToggle(skinSection, "Enable ForceField", ffEnabled, function(state)
    ffEnabled = state
    SetCfg("ffEnabled", state)
    if state then
        applyForceField()
        if ffConnection then ffConnection:Disconnect() end
        ffConnection = RunService.Heartbeat:Connect(function()
            if ffEnabled and ffRainbow then
                applyForceField()
            end
        end)
    else
        if ffConnection then
            ffConnection:Disconnect()
            ffConnection = nil
        end
        removeForceField()
    end
end)

addToggle(skinSection, "Rainbow ForceField", ffRainbow, function(state)
    ffRainbow = state
    SetCfg("ffRainbow", state)
    if ffEnabled then applyForceField() end
end)

skinSection:AddColorpicker("ForceField Color", ffColor, function(color)
    ffColor = color
    SetCfg("ffColor", color)
    if ffEnabled and not ffRainbow then applyForceField() end
end)

addToggle(skinSection, "Enable Skin Trail", skinTrailEnabled, function(state)
    skinTrailEnabled = state
    SetCfg("skinTrailEnabled", state)
    if state then applySkinTrail() else clearSkinTrail() end
end)

skinSection:AddColorpicker("Skin Trail Color", skinTrailColor, function(color)
    skinTrailColor = color
    SetCfg("skinTrailColor", color)
    updateSkinTrail()
end)

skinSection:AddSlider("Skin Trail Lifetime", 0.1, 3, skinTrailLife, function(value)
    skinTrailLife = value
    SetCfg("skinTrailLife", value)
    updateSkinTrail()
end)

-- =========================================================
-- COSMETIC: AURAS
-- =========================================================

local auraSection = mainTab:AddSection("Auras", "Cosmetic")
local auraEnabled = C("auraEnabled", false)
local auraType = C("auraType", "Godly")
local currentAuraModel = nil
local auraEffects = {}
local AuraModels = {
    Godly = "rbxassetid://16699750981",
    ["Super Sayien"] = "rbxassetid://116109508364297",
    ["North Star"] = "rbxassetid://83945069652732",
    ["Blue Lord"] = "rbxassetid://10974316799",
    ["Pink Aura"] = "rbxassetid://115980859615239",
    ["Angel Wing"] = "rbxassetid://90022969696073",
    ["Sweet Heart"] = "rbxassetid://91724768175470",
    ["Ethereal Aura"] = "rbxassetid://97041568674250",
}

local function clearAura()
    for _, obj in ipairs(auraEffects) do
        if obj and obj.Parent then obj:Destroy() end
    end
    auraEffects = {}
end

local function loadAuraModel()
    local id = AuraModels[auraType]
    if not id then return end
    local ok, model = pcall(function()
        return game:GetObjects(id)[1]
    end)
    if ok then currentAuraModel = model end
end

local function applyAura()
    clearAura()
    local char = player.Character
    if not char then return end
    if not currentAuraModel then loadAuraModel() end
    if not currentAuraModel then return end

    local temp = currentAuraModel:Clone()
    for _, obj in ipairs(temp:GetDescendants()) do
        if not obj:IsA("BasePart") then
            local parentName = obj.Parent and obj.Parent.Name
            local target = (parentName and char:FindFirstChild(parentName)) or char:FindFirstChildWhichIsA("BasePart")
            if target and not target:FindFirstChild(obj.Name) then
                local clone = obj:Clone()
                clone.Parent = target
                table.insert(auraEffects, clone)
            end
        end
    end
    temp:Destroy()
end

addToggle(auraSection, "Enable Local Aura", auraEnabled, function(state)
    auraEnabled = state
    SetCfg("auraEnabled", state)
    if state then applyAura() else clearAura() end
end)

local auraItems = {}
for name in pairs(AuraModels) do table.insert(auraItems, name) end
table.sort(auraItems)
addDropdown(auraSection, "Aura Type", auraItems, auraType, function(selected)
    auraType = selected
    SetCfg("auraType", selected)
    currentAuraModel = nil
    loadAuraModel()
    if auraEnabled then applyAura() end
end)

-- =========================================================
-- COSMETIC: JUMP CIRCLES
-- =========================================================

local jumpSection = mainTab:AddSection("Jump Circles", "Cosmetic")
local jumpCirclesEnabled = C("jumpCirclesEnabled", false)
local jumpCircleRainbow = C("jumpCircleRainbow", false)
local jumpCircleSize = C("jumpCircleSize", 6)
local jumpCircleTransparency = C("jumpCircleTransparency", 0.35)
local jumpCircleLifetime = C("jumpCircleLifetime", 0.8)
local jumpCircleColor = C("jumpCircleColor", Color3.fromRGB(0, 255, 255))

local function createJumpCircle(position)
    local ring = Instance.new("Part")
    ring.Name = "LV_JumpCircle"
    ring.Anchored = true
    ring.CanCollide = false
    ring.CastShadow = false
    ring.Material = Enum.Material.Neon
    ring.Transparency = jumpCircleTransparency
    ring.Color = jumpCircleRainbow and Color3.fromHSV((tick() % 5) / 5, 1, 1) or jumpCircleColor
    ring.Size = Vector3.new(1, 1, 1)
    ring.CFrame = CFrame.new(position) * CFrame.Angles(math.rad(90), 0, 0)
    ring.Parent = workspace

    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.FileMesh
    mesh.MeshId = "rbxassetid://3270017"
    mesh.Scale = Vector3.new(jumpCircleSize, jumpCircleSize, 0.15)
    mesh.Parent = ring

    TweenService:Create(mesh, TweenInfo.new(jumpCircleLifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Scale = Vector3.new(jumpCircleSize + 4, jumpCircleSize + 4, 0.15),
    }):Play()
    TweenService:Create(ring, TweenInfo.new(jumpCircleLifetime), {Transparency = 1}):Play()
    task.delay(jumpCircleLifetime, function()
        if ring then ring:Destroy() end
    end)
end

local function setupJumpCircles(char)
    task.spawn(function()
        local humanoid = char:WaitForChild("Humanoid", 5)
        local hrp = char:WaitForChild("HumanoidRootPart", 5)
        if not humanoid or not hrp then return end
        local wasInAir = false
        local debounce = false
        while char.Parent do
            RunService.RenderStepped:Wait()
            if jumpCirclesEnabled and humanoid.Health > 0 then
                local state = humanoid:GetState()
                if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then
                    wasInAir = true
                end
                if wasInAir and humanoid.FloorMaterial ~= Enum.Material.Air and not debounce then
                    debounce = true
                    wasInAir = false
                    createJumpCircle(hrp.Position - Vector3.new(0, 2.8, 0))
                    task.delay(0.15, function() debounce = false end)
                end
            end
        end
    end)
end

addToggle(jumpSection, "Enable Jump Circles", jumpCirclesEnabled, function(state)
    jumpCirclesEnabled = state
    SetCfg("jumpCirclesEnabled", state)
end)
addToggle(jumpSection, "Rainbow", jumpCircleRainbow, function(state)
    jumpCircleRainbow = state
    SetCfg("jumpCircleRainbow", state)
end)
jumpSection:AddSlider("Circle Size", 2, 15, jumpCircleSize, function(value)
    jumpCircleSize = value
    SetCfg("jumpCircleSize", value)
end)
jumpSection:AddSlider("Transparency", 0, 1, jumpCircleTransparency, function(value)
    jumpCircleTransparency = value
    SetCfg("jumpCircleTransparency", value)
end)
jumpSection:AddSlider("Lifetime", 0.1, 5, jumpCircleLifetime, function(value)
    jumpCircleLifetime = value
    SetCfg("jumpCircleLifetime", value)
end)
jumpSection:AddColorpicker("Circle Color", jumpCircleColor, function(color)
    jumpCircleColor = color
    SetCfg("jumpCircleColor", color)
end)

-- =========================================================
-- COSMETIC: CHARACTER
-- =========================================================

local characterSection = mainTab:AddSection("Character", "Cosmetic")
local korbloxEnabled = C("korbloxEnabled", false)
local headlessEnabled = C("headlessEnabled", false)

local function applyKorbloxHeadless()
    local char = player.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R15 then return end

    getgenv().Mscuaz_Korblox = korbloxEnabled
    getgenv().Mscuaz_Headless = headlessEnabled
    getgenv().MscuazScriptIsTheBest = "MscuazScripter"
    pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/gwnrdt/Try/refs/heads/main/Headless%26Korblox.lua"))()
    end)
end

addToggle(characterSection, "Korblox [Only Mobile + R15]", korbloxEnabled, function(state)
    korbloxEnabled = state
    SetCfg("korbloxEnabled", state)
    getgenv().Mscuaz_Korblox = state
    if state then applyKorbloxHeadless() end
end)
addToggle(characterSection, "Headless", headlessEnabled, function(state)
    headlessEnabled = state
    SetCfg("headlessEnabled", state)
    getgenv().Mscuaz_Headless = state
    if state then applyKorbloxHeadless() end
end)

-- =========================================================
-- UTILITIES: SPEED GLITCH
-- =========================================================

local speedSection = mainTab:AddSection("Speed Glitch", "Utilities")
local speedEnabled = C("speedGlitchEnabled", false)
local speedValue = C("speedValue", 50)
local speedButtonVisible = C("speedButtonVisible", false)
local speedButtonEditMode = C("speedButtonEditMode", false)
local speedButtonSize = C("speedButtonSize", 70)
local spinBotEnabled = C("spinBotEnabled", false)
local spinBotDelay = C("spinBotDelay", 0.1)
local speedGui = nil
local speedButton = nil
local speedToggle

local function saveButtonPosition(pos)
    if not writefile then return end
    ensureConfigFolder()
    pcall(function()
        writefile(CFG_FOLDER .. "/speed_button.json", HttpService:JSONEncode({
            XS = pos.X.Scale, XO = pos.X.Offset,
            YS = pos.Y.Scale, YO = pos.Y.Offset,
        }))
    end)
end

local function loadButtonPosition()
    if not (isfile and readfile) then return nil end
    local path = CFG_FOLDER .. "/speed_button.json"
    if not isfile(path) then return nil end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if ok and data then
        return UDim2.new(data.XS or 0.5, data.XO or 0, data.YS or 0.22, data.YO or 0)
    end
    return nil
end

local function setupSpeedButton()
    if speedGui then speedGui:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "LV_SpeedGlitchUI"
    gui.ResetOnSpawn = false
    gui.Parent = player:WaitForChild("PlayerGui")
    speedGui = gui

    local button = Instance.new("TextButton")
    button.Name = "SpeedGlitchButton"
    button.Size = UDim2.new(0, speedButtonSize, 0, speedButtonSize)
    button.Position = loadButtonPosition() or UDim2.new(0.5, -speedButtonSize / 2, 0.22, 0)
    button.BackgroundTransparency = 0.15
    button.Text = speedButtonEditMode and "MOVE" or "SG"
    button.TextScaled = true
    button.Visible = speedButtonVisible
    button.Active = true
    button.Parent = gui
    speedButton = button

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = button

    local dragging = false
    local dragStart = nil
    local startPos = nil

    button.InputBegan:Connect(function(input)
        if speedButtonEditMode and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = true
            dragStart = input.Position
            startPos = button.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and speedButtonEditMode and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            button.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            saveButtonPosition(button.Position)
        end
    end)

    button.MouseButton1Click:Connect(function()
        if not speedButtonEditMode and speedToggle then
            speedToggle:Set(not speedEnabled)
        end
    end)
end

speedToggle = addToggle(speedSection, "Enable Speed Glitch", speedEnabled, function(state)
    speedEnabled = state
    SetCfg("speedGlitchEnabled", state)
end)

speedSection:AddSlider("Speed", 1, 300, speedValue, function(value)
    speedValue = value
    SetCfg("speedValue", value)
end)

speedSection:AddKeybind("Speed Glitch Bind", "G", function()
    if speedToggle then speedToggle:Set(not speedEnabled) end
end)

addToggle(speedSection, "Show Button", speedButtonVisible, function(state)
    speedButtonVisible = state
    SetCfg("speedButtonVisible", state)
    if speedButton then speedButton.Visible = state end
end)

addToggle(speedSection, "Edit Mode", speedButtonEditMode, function(state)
    speedButtonEditMode = state
    SetCfg("speedButtonEditMode", state)
    if speedButton then speedButton.Text = state and "MOVE" or "SG" end
end)

speedSection:AddSlider("Button Size", 20, 200, speedButtonSize, function(value)
    speedButtonSize = value
    SetCfg("speedButtonSize", value)
    if speedButton then speedButton.Size = UDim2.new(0, value, 0, value) end
end)

addToggle(speedSection, "Spin Bot", spinBotEnabled, function(state)
    spinBotEnabled = state
    SetCfg("spinBotEnabled", state)
end)

speedSection:AddSlider("Spin Delay", 0.01, 1, spinBotDelay, function(value)
    spinBotDelay = value
    SetCfg("spinBotDelay", value)
end)

setupSpeedButton()

RunService.Heartbeat:Connect(function()
    local char = player.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if speedEnabled and humanoid and hrp and humanoid.FloorMaterial == Enum.Material.Air then
        local moveDir = humanoid.MoveDirection
        if moveDir.Magnitude > 0 then
            local vel = hrp.AssemblyLinearVelocity
            hrp.AssemblyLinearVelocity = Vector3.new(moveDir.X * speedValue, vel.Y, moveDir.Z * speedValue)
        end
    end
end)

task.spawn(function()
    while true do
        if spinBotEnabled then
            local char = player.Character
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if humanoid and root and humanoid.FloorMaterial == Enum.Material.Air then
                root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, math.rad(math.random(0, 360)), 0)
            end
        end
        task.wait(math.max(spinBotDelay, 0.01))
    end
end)

-- =========================================================
-- UTILITIES: WALLHOP
-- =========================================================

local wallHopSection = mainTab:AddSection("WallHop", "Utilities")
local wallHopEnabled = C("wallHopEnabled", false)
local wallHopCooldown = false
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

addToggle(wallHopSection, "Enable WallHop", wallHopEnabled, function(state)
    wallHopEnabled = state
    SetCfg("wallHopEnabled", state)
end)

local function getWallHit(char, root)
    raycastParams.FilterDescendantsInstances = {char}
    local directions = {
        root.CFrame.LookVector,
        -root.CFrame.LookVector,
        root.CFrame.RightVector,
        -root.CFrame.RightVector,
    }
    local closest = nil
    local closestDistance = 3
    for _, direction in ipairs(directions) do
        local hit = workspace:Raycast(root.Position, direction * 2, raycastParams)
        if hit and hit.Distance < closestDistance then
            closestDistance = hit.Distance
            closest = hit
        end
    end
    return closest
end

UserInputService.JumpRequest:Connect(function()
    if not wallHopEnabled or wallHopCooldown then return end
    local char = player.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root then return end

    local hit = getWallHit(char, root)
    if not hit then return end

    wallHopCooldown = true
    local normal = Vector3.new(hit.Normal.X, 0, hit.Normal.Z)
    if normal.Magnitude < 0.1 then normal = Vector3.new(0, 0, -1) end
    normal = normal.Unit

    root.CFrame = CFrame.lookAt(root.Position, root.Position + normal)
    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    RunService.Heartbeat:Wait()
    root.CFrame = CFrame.lookAt(root.Position, root.Position - normal)
    task.delay(0.15, function() wallHopCooldown = false end)
end)

-- =========================================================
-- UTILITIES: DISTANCE ESP ONLY
-- =========================================================

local espSection = mainTab:AddSection("Distance ESP", "Utilities")
local distanceEspEnabled = C("distanceEspEnabled", false)
local distanceRenderDistance = C("distanceRenderDistance", 200)
local distanceColor = C("distanceColor", Color3.fromRGB(255, 255, 255))
local distanceTextSize = C("distanceTextSize", 14)
local distanceObjects = {}

local function removeDistanceObject(plr)
    local gui = distanceObjects[plr]
    if gui then gui:Destroy() end
    distanceObjects[plr] = nil
end

local function ensureDistanceObject(plr)
    if plr == player then return nil end
    local char = plr.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then
        removeDistanceObject(plr)
        return nil
    end

    local gui = distanceObjects[plr]
    if not gui or not gui.Parent then
        gui = Instance.new("BillboardGui")
        gui.Name = "LV_DistanceESP"
        gui.Size = UDim2.new(0, 120, 0, 30)
        gui.StudsOffset = Vector3.new(0, 2.8, 0)
        gui.AlwaysOnTop = true
        gui.Adornee = root
        gui.Parent = root

        local label = Instance.new("TextLabel")
        label.Name = "Distance"
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.Code
        label.TextStrokeTransparency = 0.5
        label.Parent = gui

        distanceObjects[plr] = gui
    else
        gui.Adornee = root
        if gui.Parent ~= root then gui.Parent = root end
    end
    return gui
end

local function clearDistanceEsp()
    for plr in pairs(distanceObjects) do
        removeDistanceObject(plr)
    end
end

addToggle(espSection, "Enable Distance ESP", distanceEspEnabled, function(state)
    distanceEspEnabled = state
    SetCfg("distanceEspEnabled", state)
    if not state then clearDistanceEsp() end
end)

espSection:AddSlider("Render Distance", 50, 2000, distanceRenderDistance, function(value)
    distanceRenderDistance = value
    SetCfg("distanceRenderDistance", value)
end)

espSection:AddColorpicker("Distance Color", distanceColor, function(color)
    distanceColor = color
    SetCfg("distanceColor", color)
end)

espSection:AddSlider("Text Size", 8, 30, distanceTextSize, function(value)
    distanceTextSize = value
    SetCfg("distanceTextSize", value)
end)

RunService.RenderStepped:Connect(function()
    if not distanceEspEnabled then return end
    local myChar = player.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then
            local char = plr.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")
            if root and humanoid and humanoid.Health > 0 then
                local distance = (root.Position - myRoot.Position).Magnitude
                if distance <= distanceRenderDistance then
                    local gui = ensureDistanceObject(plr)
                    if gui then
                        gui.Enabled = true
                        local label = gui:FindFirstChild("Distance")
                        if label then
                            label.Text = tostring(math.floor(distance + 0.5)) .. " studs"
                            label.TextColor3 = distanceColor
                            label.TextSize = distanceTextSize
                        end
                    end
                else
                    local gui = distanceObjects[plr]
                    if gui then gui.Enabled = false end
                end
            else
                removeDistanceObject(plr)
            end
        end
    end
end)

Players.PlayerRemoving:Connect(removeDistanceObject)

-- =========================================================
-- UTILITIES: CUSTOM SHIFTLOCK CURSOR
-- =========================================================

local shiftSection = mainTab:AddSection("Custom ShiftLock", "Utilities")
local shiftEnabled = C("shiftEnabled", false)
local shiftSpinEnabled = C("shiftSpinEnabled", false)
local shiftSpinSpeed = C("shiftSpinSpeed", 5)
local shiftSpinDirection = C("shiftSpinDirection", "Right")
local shiftCursorWidth = C("shiftCursorWidth", 32)
local shiftCursorHeight = C("shiftCursorHeight", 32)
local shiftRotation = 0
local shiftObjects = {}
local CursorMap = {
    Green = "rbxassetid://11927621846",
    Purple = "rbxassetid://11927593271",
    Blue = "rbxassetid://11934534450",
    Cyan = "rbxassetid://11927574847",
    ["Blu notful"] = "rbxassetid://95871237116034",
    ["Blu star"] = "rbxassetid://11716557686",
    ["White circle"] = "rbxassetid://98322941706613",
    ["Spawn roboblox"] = "rbxassetid://83520160375628",
    ["Angel Sahur"] = "rbxassetid://128878142732909",
    ["White circles ay blyat"] = "rbxassetid://116983963395648",
    ["Nikiliss shiftlock"] = "rbxassetid://134047116604554",
    ["Red circles"] = "rbxassetid://109913835522060",
    ["Heart 1"] = "rbxassetid://88440417174442",
    ["Gray circle"] = "rbxassetid://79184859368119",
    ["Red star"] = "rbxassetid://73038181685886",
    ["White heart"] = "rbxassetid://92154647211527",
    ["Black heart"] = "rbxassetid://111025831598904",
    ["Pink circle"] = "rbxassetid://81221855342501",
    ["Shooter aim 2"] = "rbxassetid://124007606116932",
    ["Evil sahur"] = "rbxassetid://125269217374166",
    ["Shooter aim 3"] = "rbxassetid://87787133926543",
    ["White dot"] = "rbxassetid://311756276",
    X = "rbxassetid://5689419560",
    ["Heart 2"] = "rbxassetid://11754490336",
}
local shiftCursorName = C("shiftCursorName", "Green")
local shiftSelectedCursor = CursorMap[shiftCursorName] or CursorMap.Green

local function scanShiftLock()
    shiftObjects = {}
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
            local name = string.lower(obj.Name)
            if string.find(name, "shift") or string.find(name, "lock") or string.find(obj.Image or "", "MouseLockedCursor") then
                table.insert(shiftObjects, obj)
            end
        end
    end
end

local function applyShiftLock()
    for _, obj in ipairs(shiftObjects) do
        if obj and obj.Parent then
            if shiftEnabled then
                obj.Image = shiftSelectedCursor
                obj.Size = UDim2.new(0, shiftCursorWidth, 0, shiftCursorHeight)
                obj.BackgroundTransparency = 1
                obj.ImageTransparency = 0
            else
                obj.Rotation = 0
            end
        end
    end
end

scanShiftLock()
addToggle(shiftSection, "Enable Custom ShiftLock", shiftEnabled, function(state)
    shiftEnabled = state
    SetCfg("shiftEnabled", state)
    applyShiftLock()
end)

local cursorItems = {}
for name in pairs(CursorMap) do table.insert(cursorItems, name) end
table.sort(cursorItems)
addDropdown(shiftSection, "Choose Cursor", cursorItems, shiftCursorName, function(selected)
    shiftCursorName = selected
    shiftSelectedCursor = CursorMap[selected] or CursorMap.Green
    SetCfg("shiftCursorName", selected)
    applyShiftLock()
end)

addToggle(shiftSection, "Spin ShiftLock", shiftSpinEnabled, function(state)
    shiftSpinEnabled = state
    SetCfg("shiftSpinEnabled", state)
end)
shiftSection:AddSlider("Spin Speed", 0.1, 500, shiftSpinSpeed, function(value)
    shiftSpinSpeed = value
    SetCfg("shiftSpinSpeed", value)
end)
addDropdown(shiftSection, "Spin Direction", {"Left", "Right"}, shiftSpinDirection, function(selected)
    shiftSpinDirection = selected
    SetCfg("shiftSpinDirection", selected)
end)
shiftSection:AddSlider("Cursor Width", 1, 100, shiftCursorWidth, function(value)
    shiftCursorWidth = value
    SetCfg("shiftCursorWidth", value)
    applyShiftLock()
end)
shiftSection:AddSlider("Cursor Height", 1, 100, shiftCursorHeight, function(value)
    shiftCursorHeight = value
    SetCfg("shiftCursorHeight", value)
    applyShiftLock()
end)

RunService.RenderStepped:Connect(function()
    if shiftEnabled and shiftSpinEnabled then
        local direction = shiftSpinDirection == "Right" and 1 or -1
        shiftRotation = (shiftRotation + shiftSpinSpeed * direction) % 360
        for _, obj in ipairs(shiftObjects) do
            if obj and obj.Parent then obj.Rotation = shiftRotation end
        end
    end
end)

-- =========================================================
-- UTILITIES: CROSSHAIR
-- =========================================================

local crosshairSection = mainTab:AddSection("Crosshair [PC]", "Utilities")
local crosshairEnabled = C("crosshairEnabled", false)
local crosshairMode = C("crosshairMode", "mouse")
local crosshairWidth = C("crosshairWidth", 1.5)
local crosshairLength = C("crosshairLength", 10)
local crosshairRadius = C("crosshairRadius", 11)
local crosshairColor = C("crosshairColor", Color3.fromRGB(199, 110, 255))
local crosshairSpin = C("crosshairSpin", true)
local crosshairSpinSpeed = C("crosshairSpinSpeed", 150)
local crosshairSpinMax = C("crosshairSpinMax", 340)
local crosshairSpinStyle = C("crosshairSpinStyle", "Sine")
local crosshairResize = C("crosshairResize", true)
local crosshairResizeSpeed = C("crosshairResizeSpeed", 150)
local crosshairResizeMin = C("crosshairResizeMin", 5)
local crosshairResizeMax = C("crosshairResizeMax", 22)
local crosshairLines = {}

local function clearCrosshair()
    for _, line in ipairs(crosshairLines) do
        pcall(function() line:Remove() end)
    end
    crosshairLines = {}
end

local function ensureCrosshair()
    if not Drawing or not Drawing.new then return false end
    if #crosshairLines == 8 then return true end
    clearCrosshair()
    for i = 1, 8 do
        local line = Drawing.new("Line")
        line.Visible = false
        table.insert(crosshairLines, line)
    end
    return true
end

local function pointAt(angle, radius)
    return Vector2.new(math.sin(math.rad(angle)) * radius, math.cos(math.rad(angle)) * radius)
end

addToggle(crosshairSection, "Enable Crosshair", crosshairEnabled, function(state)
    crosshairEnabled = state
    SetCfg("crosshairEnabled", state)
    if not state then clearCrosshair() end
end)
addDropdown(crosshairSection, "Mode", {"mouse", "center"}, crosshairMode, function(selected)
    crosshairMode = selected
    SetCfg("crosshairMode", selected)
end)
crosshairSection:AddSlider("Width", 0.5, 5, crosshairWidth, function(value)
    crosshairWidth = value
    SetCfg("crosshairWidth", value)
end)
crosshairSection:AddSlider("Length", 1, 50, crosshairLength, function(value)
    crosshairLength = value
    SetCfg("crosshairLength", value)
end)
crosshairSection:AddSlider("Radius", 0, 50, crosshairRadius, function(value)
    crosshairRadius = value
    SetCfg("crosshairRadius", value)
end)
crosshairSection:AddColorpicker("Color", crosshairColor, function(color)
    crosshairColor = color
    SetCfg("crosshairColor", color)
end)
addToggle(crosshairSection, "Spin", crosshairSpin, function(state)
    crosshairSpin = state
    SetCfg("crosshairSpin", state)
end)
crosshairSection:AddSlider("Spin Speed", 1, 500, crosshairSpinSpeed, function(value)
    crosshairSpinSpeed = value
    SetCfg("crosshairSpinSpeed", value)
end)
crosshairSection:AddSlider("Spin Max", 90, 720, crosshairSpinMax, function(value)
    crosshairSpinMax = value
    SetCfg("crosshairSpinMax", value)
end)
addDropdown(crosshairSection, "Spin Style", {"Linear", "Sine", "Quad", "Cubic", "Quart", "Quint", "Back"}, crosshairSpinStyle, function(selected)
    crosshairSpinStyle = selected
    SetCfg("crosshairSpinStyle", selected)
end)
addToggle(crosshairSection, "Resize", crosshairResize, function(state)
    crosshairResize = state
    SetCfg("crosshairResize", state)
end)
crosshairSection:AddSlider("Resize Speed", 1, 500, crosshairResizeSpeed, function(value)
    crosshairResizeSpeed = value
    SetCfg("crosshairResizeSpeed", value)
end)
crosshairSection:AddSlider("Resize Min", 1, 50, crosshairResizeMin, function(value)
    crosshairResizeMin = value
    SetCfg("crosshairResizeMin", value)
end)
crosshairSection:AddSlider("Resize Max", 1, 50, crosshairResizeMax, function(value)
    crosshairResizeMax = value
    SetCfg("crosshairResizeMax", value)
end)

RunService.RenderStepped:Connect(function()
    if not crosshairEnabled then return end
    if not ensureCrosshair() then return end
    camera = workspace.CurrentCamera
    if not camera then return end

    local center
    if crosshairMode == "center" then
        center = camera.ViewportSize / 2
    else
        center = UserInputService:GetMouseLocation()
    end

    local now = tick()
    local spinOffset = 0
    if crosshairSpin then
        local style = Enum.EasingStyle[crosshairSpinStyle] or Enum.EasingStyle.Sine
        local normalized = ((now * crosshairSpinSpeed) % math.max(crosshairSpinMax, 1)) / math.max(crosshairSpinMax, 1)
        spinOffset = TweenService:GetValue(normalized, style, Enum.EasingDirection.InOut) * 360
    end

    local length = crosshairLength
    if crosshairResize then
        local wave = (math.sin(math.rad((now * crosshairResizeSpeed) % 360)) + 1) / 2
        length = crosshairResizeMin + wave * math.max(crosshairResizeMax - crosshairResizeMin, 0)
    end

    for i = 1, 4 do
        local angle = (i - 1) * 90 + spinOffset
        local outline = crosshairLines[i]
        local inner = crosshairLines[i + 4]
        outline.Visible = true
        outline.Color = Color3.new(0, 0, 0)
        outline.Thickness = crosshairWidth + 1.5
        outline.From = center + pointAt(angle, math.max(crosshairRadius - 1, 0))
        outline.To = center + pointAt(angle, crosshairRadius + length + 1)

        inner.Visible = true
        inner.Color = crosshairColor
        inner.Thickness = crosshairWidth
        inner.From = center + pointAt(angle, crosshairRadius)
        inner.To = center + pointAt(angle, crosshairRadius + length)
    end
end)

-- =========================================================
-- SCREEN
-- =========================================================

local screenSection = mainTab:AddSection("Screen", "Visuals")
local screenEffectEnabled = C("screenEffectEnabled", false)
local screenIntensity = C("screenIntensity", 0)
local fovEnabled = C("fovEnabled", false)
local fovValue = C("fovValue", 70)

addToggle(screenSection, "Enable Screen Effect", screenEffectEnabled, function(state)
    screenEffectEnabled = state
    SetCfg("screenEffectEnabled", state)
end)
screenSection:AddSlider("Screen Stretch", 0, 0.2, screenIntensity, function(value)
    screenIntensity = value
    SetCfg("screenIntensity", value)
end)
addToggle(screenSection, "Enable Custom FOV", fovEnabled, function(state)
    fovEnabled = state
    SetCfg("fovEnabled", state)
    if not state and workspace.CurrentCamera then workspace.CurrentCamera.FieldOfView = 70 end
end)
screenSection:AddSlider("Field of View", 30, 144, fovValue, function(value)
    fovValue = value
    SetCfg("fovValue", value)
end)

RunService.RenderStepped:Connect(function()
    camera = workspace.CurrentCamera
    if not camera then return end
    if fovEnabled then camera.FieldOfView = fovValue end
    if screenEffectEnabled then
        camera.CFrame = camera.CFrame * CFrame.new(0, 0, 0, 1, 0, 0, 0, 0.65 + screenIntensity, 0, 0, 0, 1)
    end
end)

-- =========================================================
-- WORLD
-- =========================================================

local worldSection = mainTab:AddSection("Environment", "World")
local fullbrightEnabled = C("fullbrightEnabled", false)
local ambientColor = C("ambientColor", Lighting.Ambient)
local timeOfDay = C("timeOfDay", Lighting.ClockTime)
local exposure = C("exposure", Lighting.ExposureCompensation)

addToggle(worldSection, "Fullbright", fullbrightEnabled, function(state)
    fullbrightEnabled = state
    SetCfg("fullbrightEnabled", state)
    if state then
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.FogEnd = 100000
    else
        Lighting.Brightness = 1
        Lighting.GlobalShadows = true
        Lighting.Ambient = ambientColor
        Lighting.ClockTime = timeOfDay
    end
end)
worldSection:AddColorpicker("Ambient Color", ambientColor, function(color)
    ambientColor = color
    SetCfg("ambientColor", color)
    if not fullbrightEnabled then
        Lighting.Ambient = color
        Lighting.OutdoorAmbient = color
    end
end)
worldSection:AddSlider("Time of Day", 0, 24, timeOfDay, function(value)
    timeOfDay = value
    SetCfg("timeOfDay", value)
    if not fullbrightEnabled then Lighting.ClockTime = value end
end)
worldSection:AddSlider("Exposure", -2, 5, exposure, function(value)
    exposure = value
    SetCfg("exposure", value)
    Lighting.ExposureCompensation = value
end)

local fogSection = mainTab:AddSection("Fog", "World")
local fogEnabled = C("fogEnabled", false)
local fogRainbow = C("fogRainbow", false)
local fogColor = C("fogColor", Color3.fromRGB(200, 200, 255))
local fogStart = C("fogStart", 0)
local fogEnd = C("fogEnd", 300)

local function applyFog()
    Lighting.FogStart = fogStart
    Lighting.FogEnd = fogEnd
    Lighting.FogColor = fogColor
end

addToggle(fogSection, "Enable Beautiful Fog", fogEnabled, function(state)
    fogEnabled = state
    SetCfg("fogEnabled", state)
    if state then
        applyFog()
    else
        Lighting.FogStart = 0
        Lighting.FogEnd = 100000
    end
end)
addToggle(fogSection, "Rainbow Fog", fogRainbow, function(state)
    fogRainbow = state
    SetCfg("fogRainbow", state)
end)
fogSection:AddSlider("Fog Distance", 50, 2000, fogEnd, function(value)
    fogEnd = value
    SetCfg("fogEnd", value)
    if fogEnabled then applyFog() end
end)
fogSection:AddSlider("Fog Start", 0, 500, fogStart, function(value)
    fogStart = value
    SetCfg("fogStart", value)
    if fogEnabled then applyFog() end
end)
fogSection:AddColorpicker("Fog Color", fogColor, function(color)
    fogColor = color
    SetCfg("fogColor", color)
    if fogEnabled and not fogRainbow then applyFog() end
end)

RunService.RenderStepped:Connect(function()
    if fogEnabled and fogRainbow then
        Lighting.FogColor = Color3.fromHSV((tick() % 5) / 5, 1, 1)
    end
end)

-- =========================================================
-- SKYBOXES
-- =========================================================

local skyboxSection = mainTab:AddSection("Skyboxes", "Visuals")
local function applySkybox(assetId)
    for _, obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("Sky") then obj:Destroy() end
    end

    local ok, asset = pcall(function()
        return game:GetObjects("rbxassetid://" .. tostring(assetId))[1]
    end)

    if ok and asset and asset:IsA("Sky") then
        asset.Parent = Lighting
    else
        local sky = Instance.new("Sky")
        local id = "rbxassetid://" .. tostring(assetId)
        sky.SkyboxBk = id
        sky.SkyboxDn = id
        sky.SkyboxFt = id
        sky.SkyboxLf = id
        sky.SkyboxRt = id
        sky.SkyboxUp = id
        sky.Parent = Lighting
    end
end

local skyboxes = {
    {"Orange Skybox", "627302570"},
    {"FPS+ Skybox", "582303304"},
    {"Space Skybox", "15619750970"},
    {"Green Skybox", "348361280"},
    {"Blue Skybox", "130093177270069"},
    {"Purple Skybox", "83555979203508"},
    {"Red Skybox", "401666131"},
    {"HD Skybox", "16823410580"},
    {"Night Skybox", "12064636"},
    {"Galactic Skybox", "10542194896"},
    {"Winter Skybox", "96628448286151"},
    {"Saturn Skybox", "1898754079"},
    {"Outrun Skybox", "3441770362"},
    {"Cyan Space Skybox", "367149630"},
    {"City Skybox", "117205995214134"},
    {"Green skybox 2.0", "16823294549"},
    {"Obama Skybox (joke)", "2362934358"},
    {"SpongeBob Skybox", "114523453023009"},
    {"Purple Nebula Skybox", "230057997"},
    {"Bart Skybox", "119891349513795"},
    {"Sunless Blue Sky", "591067775"},
    {"Weirdcore Eye Skybox", "11372740893"},
    {"Minecraft Skybox", "5087871978"},
    {"Frutiger Aero Skybox", "97046110924083"},
    {"Cyberpunk Skybox", "13689001090"},
    {"Dark Red Castle Skybox", "15832476802"},
    {"Cartoon Skybox", "107689530722429"},
    {"Skybox HD", "16563510624"},
    {"Error Skybox", "13710730784"},
    {"Abyssal Blues Skybox", "16269853692"},
    {"Earth Skybox", "266878339"},
    {"Black & White Fade Skybox", "6213224205"},
    {"Purple Skybox 2", "8107887936"},
    {"Green Nebula Space", "89018019804256"},
    {"HD Rainbow Skybox", "18915196644"},
    {"Meadow Skybox", "848241313"},
    {"Pink Sky Skybox", "107689530722174"},
    {"Venus Skybox V2", "110450592899174"},
}

for _, entry in ipairs(skyboxes) do
    skyboxSection:AddButton(entry[1], function()
        SetCfg("lastSkybox", entry[2])
        applySkybox(entry[2])
    end)
end

local lastSkybox = C("lastSkybox", nil)
if lastSkybox then
    pcall(function() applySkybox(lastSkybox) end)
end

-- =========================================================
-- MISCELLANEOUS
-- =========================================================

local miscSection = mainTab:AddSection("Miscellaneous", "Settings")
miscSection:AddButton("Reset Configuration", function()
    ConfigData = {}
    if isfile and delfile and isfile(CFG_FILE) then
        pcall(delfile, CFG_FILE)
    end
    shared.Notify("Configuration reset. Reload the addon to apply defaults.", 2)
end)

-- Reapply character visuals after respawn.
local function onCharacterAdded(char)
    task.wait(1)
    if trailEnabled then createTrail() end
    if ffEnabled then applyForceField() end
    if skinTrailEnabled then applySkinTrail() end
    if auraEnabled then applyAura() end
    if korbloxEnabled or headlessEnabled then applyKorbloxHeadless() end
    setupJumpCircles(char)
    task.delay(0.5, setupSpeedButton)
end

if player.Character then
    task.defer(function() onCharacterAdded(player.Character) end)
end
player.CharacterAdded:Connect(onCharacterAdded)

game.DescendantAdded:Connect(function(obj)
    if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
        task.defer(function()
            if not obj.Parent then return end
            local name = string.lower(obj.Name)
            if string.find(name, "shift") or string.find(name, "lock") or string.find(obj.Image or "", "MouseLockedCursor") then
                table.insert(shiftObjects, obj)
                if shiftEnabled then applyShiftLock() end
            end
        end)
    end
end)

shared.Notify("ludexioso_visuals loaded", 2)
