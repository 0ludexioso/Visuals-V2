-- Visuals V2
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
    "Visuals V2",
    "/0ludexioso/VisualsV2/refs/heads/main/icon"
)

-- Durable plugin settings:
-- workspace/plugins/Visuals V2/settings.json
local CFG_ROOT = "plugins"
local CFG_FOLDER = CFG_ROOT .. "/Visuals V2"
local CFG_FILE = CFG_FOLDER .. "/settings.json"
local ConfigData = {}
local configResetting = false

local env = {}
if type(getgenv) == "function" then
    local ok, result = pcall(getgenv)
    if ok and type(result) == "table" then env = result end
end

local read = type(readfile) == "function" and readfile or env.readfile
local write = type(writefile) == "function" and writefile or env.writefile
local exists = type(isfile) == "function" and isfile or env.isfile
local make = type(makefolder) == "function" and makefolder or env.makefolder
local folderExists = type(isfolder) == "function" and isfolder or env.isfolder
local deleteFile = type(delfile) == "function" and delfile or env.delfile

local function ensureConfigFolder()
    if type(make) ~= "function" then return end
    pcall(function()
        if type(folderExists) == "function" then
            if not folderExists(CFG_ROOT) then make(CFG_ROOT) end
            if not folderExists(CFG_FOLDER) then make(CFG_FOLDER) end
        else
            make(CFG_ROOT)
            make(CFG_FOLDER)
        end
    end)
end

local function loadConfig()
    ensureConfigFolder()
    if type(read) ~= "function" then return end

    local found = true
    if type(exists) == "function" then
        local ok, result = pcall(exists, CFG_FILE)
        found = ok and result
    end
    if not found then return end

    local ok, data = pcall(function()
        return HttpService:JSONDecode(read(CFG_FILE))
    end)
    if ok and type(data) == "table" then
        ConfigData = data
    end
end

local function saveConfig()
    ensureConfigFolder()
    if type(write) ~= "function" then return false end
    local ok = pcall(function()
        write(CFG_FILE, HttpService:JSONEncode(ConfigData))
    end)
    return ok
end

local function C(key, default)
    local value = ConfigData[key]
    if value == nil then return default end
    if typeof(default) == "Color3" and type(value) == "table" then
        return Color3.fromRGB(value[1], value[2], value[3])
    end
    return value
end

local function SetCfg(key, value)
    if configResetting then return end
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
        if newState ~= state then rawToggle() end
    end
    function controller:Get()
        return state
    end

    if defaultValue then task.defer(rawToggle) end
    return controller
end

local function addDropdown(section, name, items, defaultValue, callback)
    local controller = section:AddDropdown(name, items, callback)
    if defaultValue and controller and controller.Select then
        task.defer(function()
            pcall(function() controller:Select(defaultValue) end)
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
local trailTransparencyStart = C("trailTransparencyStart", 0.25)
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

trailSection:AddSlider("Trail Transparency Start", 0.0, 1.0, trailTransparencyStart, function(value)
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
local skinTrailRainbow = C("skinTrailRainbow", false)
local skinTrailColor = C("skinTrailColor", Color3.fromRGB(255, 0, 0))
local skinTrailLife = C("skinTrailLife", 0.5)
local skinTrailTransparency = C("skinTrailTransparency", 0.0) -- UI range 0-4; divided by 4 internally.
local originalAppearance = {}
local ffConnection = nil
local skinTrailRainbowConnection = nil

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

local function currentSkinTrailColor()
    if skinTrailRainbow then
        return Color3.fromHSV((tick() % 5) / 5, 1, 1)
    end
    return skinTrailColor
end

local function currentSkinTrailTransparency()
    -- Roblox trail transparency is 0-1. The UI intentionally exposes 0-4
    -- for finer control and maps that larger range back into Roblox's range.
    return math.clamp((tonumber(skinTrailTransparency) or 0) / 4, 0, 1)
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
            trail.Color = ColorSequence.new(currentSkinTrailColor())
            trail.Transparency = NumberSequence.new(currentSkinTrailTransparency())
            trail.Lifetime = skinTrailLife
            trail.Parent = part
        end
    end
end

local function updateSkinTrail()
    local char = player.Character
    if not char then return end
    local color = currentSkinTrailColor()
    local transparency = currentSkinTrailTransparency()

    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("Trail") and obj.Name == "LV_SkinTrail" then
            obj.Color = ColorSequence.new(color)
            obj.Transparency = NumberSequence.new(transparency)
            obj.Lifetime = skinTrailLife
        end
    end
end

local function refreshSkinTrailRainbowConnection()
    if skinTrailRainbowConnection then
        skinTrailRainbowConnection:Disconnect()
        skinTrailRainbowConnection = nil
    end

    if skinTrailEnabled and skinTrailRainbow then
        skinTrailRainbowConnection = RunService.Heartbeat:Connect(function()
            updateSkinTrail()
        end)
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
    if state then
        applySkinTrail()
    else
        clearSkinTrail()
    end
    refreshSkinTrailRainbowConnection()
end)

addToggle(skinSection, "Rainbow Skin Trail", skinTrailRainbow, function(state)
    skinTrailRainbow = state
    SetCfg("skinTrailRainbow", state)
    updateSkinTrail()
    refreshSkinTrailRainbowConnection()
end)

skinSection:AddColorpicker("Skin Trail Color", skinTrailColor, function(color)
    skinTrailColor = color
    SetCfg("skinTrailColor", color)
    if not skinTrailRainbow then updateSkinTrail() end
end)

skinSection:AddSlider("Skin Trail Lifetime", 0.1, 3.0, skinTrailLife, function(value)
    skinTrailLife = value
    SetCfg("skinTrailLife", value)
    updateSkinTrail()
end)

skinSection:AddSlider("Skin Transparency", 0.0, 4.0, skinTrailTransparency, function(value)
    skinTrailTransparency = value
    SetCfg("skinTrailTransparency", value)
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
        if obj and obj.Parent then
            obj:Destroy()
        end
    end
    auraEffects = {}
end

local function loadAuraModel()
    if currentAuraModel and currentAuraModel.Parent then
        currentAuraModel:Destroy()
    end
    currentAuraModel = nil

    local id = AuraModels[auraType]
    if not id then return end

    local ok, model = pcall(function()
        return game:GetObjects(id)[1]
    end)

    if ok and model then
        currentAuraModel = model
    end
end

local function applyAura()
    clearAura()

    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not char or not root then return end

    if not currentAuraModel then
        loadAuraModel()
    end
    if not currentAuraModel then return end

    -- Keep the aura's original hierarchy intact. Some aura assets use
    -- attachments/beams/emitters that break when their descendants are
    -- copied individually. Parenting the whole clone preserves animation.
    local clone = currentAuraModel:Clone()
    clone.Name = "VisualsV2_Aura"

    if clone:IsA("Model") then
        clone.Parent = char
        pcall(function()
            clone:PivotTo(root.CFrame)
        end)
    elseif clone:IsA("BasePart") then
        clone.CFrame = root.CFrame
        clone.Parent = char
    else
        clone.Parent = char
    end

    local baseParts = {}
    if clone:IsA("BasePart") then
        table.insert(baseParts, clone)
    end
    for _, obj in ipairs(clone:GetDescendants()) do
        if obj:IsA("BasePart") then
            table.insert(baseParts, obj)
        end
    end

    for _, part in ipairs(baseParts) do
        part.Anchored = false
        part.CanCollide = false
        part.CanTouch = false
        part.CanQuery = false
        part.Massless = true

        -- Pink Aura uses invisible carrier parts for its animated effects.
        -- Hiding those carriers removes the choppy box look while keeping
        -- their particle/beam children active.
        if auraType == "Pink Aura" then
            part.Transparency = 1
        end

        local weld = Instance.new("WeldConstraint")
        weld.Name = "VisualsV2_AuraWeld"
        weld.Part0 = root
        weld.Part1 = part
        weld.Parent = part
    end

    table.insert(auraEffects, clone)
end

addToggle(auraSection, "Enable Local Aura", auraEnabled, function(state)
    auraEnabled = state
    SetCfg("auraEnabled", state)
    if state then
        applyAura()
    else
        clearAura()
    end
end)

local auraItems = {}
for name in pairs(AuraModels) do
    table.insert(auraItems, name)
end
table.sort(auraItems)

addDropdown(auraSection, "Aura Type", auraItems, auraType, function(selected)
    auraType = selected
    SetCfg("auraType", selected)
    loadAuraModel()
    if auraEnabled then
        applyAura()
    end
end)

-- =========================================================
-- COSMETIC: JUMP CIRCLES
-- =========================================================

local jumpSection = mainTab:AddSection("Jump Circles", "Cosmetic")
local jumpCirclesEnabled = C("jumpCirclesEnabled", false)
local jumpCircleRainbow = C("jumpCircleRainbow", false)
local jumpCircleSize = C("jumpCircleSize", 6)
local jumpCircleTransparency = C("jumpCircleTransparency", 1.75) -- UI range 0-5; divided by 5 internally.
local jumpCircleLifetime = C("jumpCircleLifetime", 0.8)
local jumpCircleColor = C("jumpCircleColor", Color3.fromRGB(0, 255, 255))

local function createJumpCircle(position)
    local ring = Instance.new("Part")
    ring.Name = "LV_JumpCircle"
    ring.Anchored = true
    ring.CanCollide = false
    ring.CastShadow = false
    ring.Material = Enum.Material.Neon
    ring.Transparency = math.clamp((tonumber(jumpCircleTransparency) or 0) / 5, 0, 1)
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
jumpSection:AddSlider("Transparency", 0.0, 5.0, jumpCircleTransparency, function(value)
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
local characterOriginal = setmetatable({}, {__mode = "k"})

characterSection:AddParagraph(
    "Visual-only",
    "Headless and Korblox are local/client-side appearance changes only. Other players will not see them."
)

local function rememberPart(part)
    if not part or characterOriginal[part] then return end
    local data = {
        Transparency = part.Transparency,
        LocalTransparencyModifier = part.LocalTransparencyModifier,
    }
    if part:IsA("MeshPart") then
        pcall(function() data.MeshId = part.MeshId end)
        pcall(function() data.TextureID = part.TextureID end)
    end
    characterOriginal[part] = data
end

local function restorePart(part)
    if not part or not part:IsA("BasePart") then return end
    local data = characterOriginal[part]
    if not data then return end
    pcall(function() part.Transparency = data.Transparency end)
    pcall(function() part.LocalTransparencyModifier = data.LocalTransparencyModifier end)
    if part:IsA("MeshPart") then
        if data.MeshId then pcall(function() part.MeshId = data.MeshId end) end
        if data.TextureID then pcall(function() part.TextureID = data.TextureID end) end
    end
end

local function setLocalHidden(part, hidden)
    if not part or not part:IsA("BasePart") then return end
    rememberPart(part)
    if hidden then
        part.Transparency = 1
        part.LocalTransparencyModifier = 1
    else
        restorePart(part)
    end
end

local function rememberDecal(decal)
    if not decal or characterOriginal[decal] then return end
    characterOriginal[decal] = {Transparency = decal.Transparency}
end

local function setDecalHidden(decal, hidden)
    if not decal or not decal:IsA("Decal") then return end
    rememberDecal(decal)
    if hidden then
        decal.Transparency = 1
    else
        local data = characterOriginal[decal]
        if data then decal.Transparency = data.Transparency end
    end
end

local function applyKorbloxVisual(char, enabled)
    local upper = char and char:FindFirstChild("RightUpperLeg")
    local lower = char and char:FindFirstChild("RightLowerLeg")
    local foot = char and char:FindFirstChild("RightFoot")

    if upper then rememberPart(upper) end
    if lower then rememberPart(lower) end
    if foot then rememberPart(foot) end

    if not enabled then
        if upper then restorePart(upper) end
        if lower then restorePart(lower) end
        if foot then restorePart(foot) end
        return
    end

    -- R15 Korblox Deathspeaker right-leg visual.
    if upper and upper:IsA("MeshPart") then
        pcall(function()
            upper.MeshId = "https://assetdelivery.roblox.com/v1/asset/?id=9598310133"
            upper.TextureID = "https://www.roblox.com/asset/?id=902843398"
            upper.Transparency = 0
            upper.LocalTransparencyModifier = 0
        end)
    end
    if lower then
        lower.Transparency = 1
        lower.LocalTransparencyModifier = 1
    end
    if foot then
        foot.Transparency = 1
        foot.LocalTransparencyModifier = 1
    end
end

local function applyCharacterVisuals(runExternal)
    local char = player.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not char or not humanoid then return end

    if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
        if korbloxEnabled or headlessEnabled then
            shared.Notify("Headless/Korblox visual requires R15.", 0)
        end
        return
    end

    local head = char:FindFirstChild("Head")
    if head then
        setLocalHidden(head, headlessEnabled)
        for _, obj in ipairs(head:GetChildren()) do
            if obj:IsA("Decal") then
                setDecalHidden(obj, headlessEnabled)
            end
        end
    end

    applyKorbloxVisual(char, korbloxEnabled)

    getgenv().Mscuaz_Korblox = korbloxEnabled
    getgenv().Mscuaz_Headless = headlessEnabled
    getgenv().MscuazScriptIsTheBest = "MscuazScripter"

    -- Keep the original external visual loader as a compatibility fallback.
    if runExternal and (korbloxEnabled or headlessEnabled) then
        pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/gwnrdt/Try/refs/heads/main/Headless%26Korblox.lua"))()
        end)
    end
end

addToggle(characterSection, "Korblox (Visual Only / Local)", korbloxEnabled, function(state)
    korbloxEnabled = state
    SetCfg("korbloxEnabled", state)
    applyCharacterVisuals(state)
end)

addToggle(characterSection, "Headless (Visual Only / Local)", headlessEnabled, function(state)
    headlessEnabled = state
    SetCfg("headlessEnabled", state)
    applyCharacterVisuals(state)
end)

-- =========================================================
-- UTILITIES: SPEED GLITCH
-- =========================================================

local speedSection = mainTab:AddSection("Speed Glitch", "Utilities")
local speedEnabled = C("speedGlitchEnabled", false)
local speedValue = C("speedValue", 50)
local speedButtonVisible = C("speedButtonVisible", false)
local speedBindButtonVisible = C("speedBindButtonVisible", true)
local speedButtonWidth = C("speedButtonWidth", 120)
local speedButtonHeight = C("speedButtonHeight", 44)
local speedButtonColor = C("speedButtonColor", Color3.fromRGB(0, 0, 0))
local speedButtonTransparency = C("speedButtonTransparency", 0.5)
local speedButtonOutlineColor = C("speedButtonOutlineColor", Color3.fromRGB(255, 255, 255))
local speedButtonOutlineTransparency = C("speedButtonOutlineTransparency", 0.2)
local lockBigButtonPos = C("lockBigButtonPos", false)
local lockBindButtonPos = C("lockBindButtonPos", false)
local speedGui = nil
local speedButton = nil
local speedBindButton = nil
local speedButtonStroke = nil
local speedBindButtonStroke = nil
local speedToggle

local BIG_BUTTON_DEFAULT = UDim2.new(0.5, -60, 0.22, 0)
local BIND_BUTTON_DEFAULT = UDim2.new(0.1, 0, 0.72, 0)

local function loadStoredPosition(key, fallback)
    local data = C(key, nil)
    if type(data) == "table" then
        return UDim2.new(
            tonumber(data.XS) or fallback.X.Scale,
            tonumber(data.XO) or fallback.X.Offset,
            tonumber(data.YS) or fallback.Y.Scale,
            tonumber(data.YO) or fallback.Y.Offset
        )
    end
    return fallback
end

local function saveStoredPosition(key, pos)
    SetCfg(key, {
        XS = pos.X.Scale,
        XO = pos.X.Offset,
        YS = pos.Y.Scale,
        YO = pos.Y.Offset,
    })
end

local function updateSpeedButtonStyle()
    if speedButton then
        speedButton.Size = UDim2.new(0, speedButtonWidth, 0, speedButtonHeight)
        speedButton.BackgroundColor3 = speedButtonColor
        speedButton.BackgroundTransparency = math.clamp(speedButtonTransparency, 0, 1)
        speedButton.Text = speedEnabled and "ACTIVE" or "INACTIVE"
        speedButton.TextStrokeTransparency = 1
        speedButton.Visible = speedButtonVisible
    end
    if speedButtonStroke then
        speedButtonStroke.Color = speedButtonOutlineColor
        speedButtonStroke.Transparency = math.clamp(speedButtonOutlineTransparency, 0, 1)
    end

    if speedBindButton then
        speedBindButton.BackgroundColor3 = speedButtonColor
        speedBindButton.BackgroundTransparency = math.clamp(speedButtonTransparency, 0, 1)
        speedBindButton.Text = "BIND"
        speedBindButton.TextStrokeTransparency = 1
        speedBindButton.Visible = speedBindButtonVisible
    end
    if speedBindButtonStroke then
        speedBindButtonStroke.Color = speedButtonOutlineColor
        speedBindButtonStroke.Transparency = math.clamp(speedButtonOutlineTransparency, 0, 1)
    end
end

local function toggleSpeedFromButton()
    if speedToggle then
        speedToggle:Set(not speedEnabled)
    end
end

local function makeDraggableToggleButton(button, isLocked, positionKey)
    local activePointer = false
    local moved = false
    local dragStart
    local startPos

    button.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        activePointer = true
        moved = false
        dragStart = input.Position
        startPos = button.Position
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not activePointer or isLocked() then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        local delta = input.Position - dragStart
        if delta.Magnitude >= 5 then moved = true end
        button.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end)

    UserInputService.InputEnded:Connect(function(input)
        if not activePointer then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        activePointer = false
        if moved and not isLocked() then
            saveStoredPosition(positionKey, button.Position)
        else
            toggleSpeedFromButton()
        end
    end)
end

local function setupSpeedButtons()
    if speedGui then speedGui:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "VisualsV2_SpeedGlitchUI"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.Parent = player:WaitForChild("PlayerGui")
    speedGui = gui

    local big = Instance.new("TextButton")
    big.Name = "SpeedGlitchBigButton"
    big.Size = UDim2.new(0, speedButtonWidth, 0, speedButtonHeight)
    big.Position = loadStoredPosition("speedButtonPosition", BIG_BUTTON_DEFAULT)
    big.TextColor3 = Color3.fromRGB(255, 255, 255)
    big.TextScaled = true
    big.Font = Enum.Font.GothamBold
    big.Active = true
    big.AutoButtonColor = false
    big.Parent = gui
    speedButton = big

    local bigCorner = Instance.new("UICorner")
    bigCorner.CornerRadius = UDim.new(0, 5)
    bigCorner.Parent = big

    local bigStroke = Instance.new("UIStroke")
    bigStroke.Thickness = 2
    bigStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    bigStroke.LineJoinMode = Enum.LineJoinMode.Round
    bigStroke.Parent = big
    speedButtonStroke = bigStroke

    local bind = Instance.new("TextButton")
    bind.Name = "SpeedGlitchBindButton"
    bind.Size = UDim2.new(0, 72, 0, 34)
    bind.Position = loadStoredPosition("speedBindButtonPosition", BIND_BUTTON_DEFAULT)
    bind.TextColor3 = Color3.fromRGB(255, 255, 255)
    bind.TextScaled = true
    bind.Font = Enum.Font.GothamBold
    bind.Active = true
    bind.AutoButtonColor = false
    bind.Parent = gui
    speedBindButton = bind

    local bindCorner = Instance.new("UICorner")
    bindCorner.CornerRadius = UDim.new(0, 5)
    bindCorner.Parent = bind

    local bindStroke = Instance.new("UIStroke")
    bindStroke.Thickness = 2
    bindStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    bindStroke.LineJoinMode = Enum.LineJoinMode.Round
    bindStroke.Parent = bind
    speedBindButtonStroke = bindStroke

    makeDraggableToggleButton(big, function() return lockBigButtonPos end, "speedButtonPosition")
    makeDraggableToggleButton(bind, function() return lockBindButtonPos end, "speedBindButtonPosition")
    updateSpeedButtonStyle()
end

speedToggle = addToggle(speedSection, "Enable Speed Glitch", speedEnabled, function(state)
    speedEnabled = state
    SetCfg("speedGlitchEnabled", state)
    updateSpeedButtonStyle()
end)

speedSection:AddSlider("Speed", 1, 300, speedValue, function(value)
    speedValue = value
    SetCfg("speedValue", value)
end)

-- Native ODH rebindable keyboard shortcut, per the Filho addon API.
speedSection:AddKeybind("Speed Glitch Bind", "G", function()
    toggleSpeedFromButton()
end)

addToggle(speedSection, "Show Button", speedButtonVisible, function(state)
    speedButtonVisible = state
    SetCfg("speedButtonVisible", state)
    updateSpeedButtonStyle()
end)

addToggle(speedSection, "Show Bind Button", speedBindButtonVisible, function(state)
    speedBindButtonVisible = state
    SetCfg("speedBindButtonVisible", state)
    updateSpeedButtonStyle()
end)

speedSection:AddSlider("Button Width", 70, 220, speedButtonWidth, function(value)
    speedButtonWidth = value
    SetCfg("speedButtonWidth", value)
    updateSpeedButtonStyle()
end)

speedSection:AddSlider("Button Height", 28, 90, speedButtonHeight, function(value)
    speedButtonHeight = value
    SetCfg("speedButtonHeight", value)
    updateSpeedButtonStyle()
end)

speedSection:AddColorpicker("Button Color", speedButtonColor, function(color)
    speedButtonColor = color
    SetCfg("speedButtonColor", color)
    updateSpeedButtonStyle()
end)

speedSection:AddSlider("Button Transparency", 0, 1, speedButtonTransparency, function(value)
    speedButtonTransparency = value
    SetCfg("speedButtonTransparency", value)
    updateSpeedButtonStyle()
end)

speedSection:AddColorpicker("Outline Color", speedButtonOutlineColor, function(color)
    speedButtonOutlineColor = color
    SetCfg("speedButtonOutlineColor", color)
    updateSpeedButtonStyle()
end)

speedSection:AddSlider("Outline Transparency", 0, 1, speedButtonOutlineTransparency, function(value)
    speedButtonOutlineTransparency = value
    SetCfg("speedButtonOutlineTransparency", value)
    updateSpeedButtonStyle()
end)

speedSection:AddButton("Reset Big Button Position", function()
    if speedButton then speedButton.Position = BIG_BUTTON_DEFAULT end
    SetCfg("speedButtonPosition", nil)
end)

speedSection:AddButton("Reset Bind Button Position", function()
    if speedBindButton then speedBindButton.Position = BIND_BUTTON_DEFAULT end
    SetCfg("speedBindButtonPosition", nil)
end)

setupSpeedButtons()

RunService.Heartbeat:Connect(function()
    local char = player.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    if speedEnabled and humanoid and hrp and humanoid.FloorMaterial == Enum.Material.Air then
        local moveDir = humanoid.MoveDirection
        if moveDir.Magnitude > 0 then
            local vel = hrp.AssemblyLinearVelocity
            hrp.AssemblyLinearVelocity = Vector3.new(
                moveDir.X * speedValue,
                vel.Y,
                moveDir.Z * speedValue
            )
        end
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

local function getWallRaycastResult()
    local character = player.Character
    if not character then return nil end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    raycastParams.FilterDescendantsInstances = {character}
    local directions = {
        hrp.CFrame.LookVector,
        -hrp.CFrame.LookVector,
        hrp.CFrame.RightVector,
        -hrp.CFrame.RightVector,
    }
    local detectionDistance = 2
    local closestHit = nil
    local minDistance = detectionDistance + 1

    for _, direction in pairs(directions) do
        local ray = workspace:Raycast(hrp.Position, direction * detectionDistance, raycastParams)
        if ray and ray.Instance and ray.Distance < minDistance then
            minDistance = ray.Distance
            closestHit = ray
        end
    end

    return closestHit
end

addToggle(wallHopSection, "Enable WallHop", wallHopEnabled, function(state)
    wallHopEnabled = state
    SetCfg("wallHopEnabled", state)
end)

UserInputService.JumpRequest:Connect(function()
    if not wallHopEnabled or wallHopCooldown then return end

    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    local cam = workspace.CurrentCamera
    if not (humanoid and rootPart and cam) then return end

    local wallRayResult = getWallRaycastResult()
    if not wallRayResult then return end

    wallHopCooldown = true

    local wallNormal = wallRayResult.Normal
    local horizontalWallNormal = Vector3.new(wallNormal.X, 0, wallNormal.Z)
    if horizontalWallNormal.Magnitude < 0.1 then
        horizontalWallNormal = rootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
        if horizontalWallNormal.Magnitude < 0.1 then
            horizontalWallNormal = Vector3.new(0, 0, -1)
        end
    end
    horizontalWallNormal = horizontalWallNormal.Unit

    local baseDirectionAwayFromWall = horizontalWallNormal
    local cameraLook = cam.CFrame.LookVector
    local horizontalCameraLook = Vector3.new(cameraLook.X, 0, cameraLook.Z)
    if horizontalCameraLook.Magnitude < 0.1 then
        horizontalCameraLook = baseDirectionAwayFromWall
    else
        horizontalCameraLook = horizontalCameraLook.Unit
    end

    local maxInfluenceAngle = math.rad(40)
    local dot = math.clamp(baseDirectionAwayFromWall:Dot(horizontalCameraLook), -1, 1)
    local angleBetween = math.acos(dot)
    local cross = baseDirectionAwayFromWall:Cross(horizontalCameraLook)
    local rotationSign = math.sign(cross.Y)
    if rotationSign == 0 then angleBetween = 0 end

    local actualInfluenceAngle = math.min(angleBetween, maxInfluenceAngle)
    local adjustmentRotation = CFrame.Angles(0, actualInfluenceAngle * rotationSign, 0)
    local initialTargetLookDirection = adjustmentRotation * baseDirectionAwayFromWall

    rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + initialTargetLookDirection)
    RunService.Heartbeat:Wait()

    local didJump = false
    if humanoid:GetState() ~= Enum.HumanoidStateType.Dead then
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        didJump = true
    end

    if didJump then
        local directionTowardsWall = -baseDirectionAwayFromWall
        rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + directionTowardsWall)
    end

    task.wait(0.15)
    wallHopCooldown = false
end)

-- =========================================================
-- UTILITIES: DISTANCE ESP ONLY
-- =========================================================

local espSection = mainTab:AddSection("Distance ESP", "Utilities")
local distanceEspEnabled = C("distanceEspEnabled", false)
local distanceRenderDistance = C("distanceRenderDistance", 200)
local distanceColor = C("distanceColor", Color3.fromRGB(255, 255, 255))
local distanceTextSize = C("distanceTextSize", 14)
local distancePosition = C("distancePosition", "Bottom")
local distanceObjects = {}

local function distanceOffset()
    if distancePosition == "Top" then
        return Vector3.new(0, 3.25, 0)
    elseif distancePosition == "Middle" then
        return Vector3.new(0, 0, 0)
    end
    return Vector3.new(0, -3.0, 0)
end

local function removeDistanceObject(plr)
    local gui = distanceObjects[plr]
    if gui then
        gui:Destroy()
    end
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
        gui.Name = "VisualsV2_DistanceESP"
        gui.Size = UDim2.new(0, 100, 0, 26)
        gui.StudsOffset = distanceOffset()
        gui.AlwaysOnTop = true
        gui.Adornee = root
        gui.Parent = root

        local label = Instance.new("TextLabel")
        label.Name = "Distance"
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.Code
        label.TextStrokeTransparency = 0.35
        label.TextXAlignment = Enum.TextXAlignment.Center
        label.TextYAlignment = Enum.TextYAlignment.Center
        label.Parent = gui

        distanceObjects[plr] = gui
    else
        gui.Adornee = root
        gui.StudsOffset = distanceOffset()
        if gui.Parent ~= root then
            gui.Parent = root
        end
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
    if not state then
        clearDistanceEsp()
    end
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

addDropdown(espSection, "Position", {"Top", "Middle", "Bottom"}, distancePosition, function(selected)
    distancePosition = selected
    SetCfg("distancePosition", selected)
    for _, gui in pairs(distanceObjects) do
        if gui and gui.Parent then
            gui.StudsOffset = distanceOffset()
        end
    end
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
                        gui.StudsOffset = distanceOffset()

                        local label = gui:FindFirstChild("Distance")
                        if label then
                            label.Text = "[" .. tostring(math.floor(distance + 0.5)) .. "]"
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
-- SCREEN
-- =========================================================

local screenSection = mainTab:AddSection("Screen", "Visuals")
local stretchScreenEnabled = C("stretchScreenEnabled", false)
local STRETCH_FACTOR = 0.65

addToggle(screenSection, "Stretch Screen", stretchScreenEnabled, function(state)
    stretchScreenEnabled = state
    SetCfg("stretchScreenEnabled", state)
end)

RunService.RenderStepped:Connect(function()
    camera = workspace.CurrentCamera
    if camera and stretchScreenEnabled then
        camera.CFrame = camera.CFrame * CFrame.new(
            0, 0, 0,
            1, 0, 0,
            0, STRETCH_FACTOR, 0,
            0, 0, 1
        )
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
local originalSky = Lighting:FindFirstChildOfClass("Sky")
originalSky = originalSky and originalSky:Clone() or nil

local function clearSky()
    for _, obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("Sky") then
            obj:Destroy()
        end
    end
end

local function restoreDefaultSky()
    clearSky()
    if originalSky then
        originalSky:Clone().Parent = Lighting
    end
end

local function applySkybox(assetId)
    clearSky()

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
    {"Default", nil},
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

local skyboxByName = {}
local skyboxNames = {}
for _, entry in ipairs(skyboxes) do
    skyboxByName[entry[1]] = entry[2]
    table.insert(skyboxNames, entry[1])
end

local selectedSkybox = C("selectedSkybox", "Default")
addDropdown(skyboxSection, "Skybox", skyboxNames, selectedSkybox, function(selected)
    selectedSkybox = selected
    SetCfg("selectedSkybox", selected)

    local assetId = skyboxByName[selected]
    if assetId then
        applySkybox(assetId)
    else
        restoreDefaultSky()
    end
end)

-- =========================================================
-- MISCELLANEOUS
-- =========================================================

local miscSection = mainTab:AddSection("Miscellaneous", "Settings")

addToggle(miscSection, "Lock Big Button POS", lockBigButtonPos, function(state)
    lockBigButtonPos = state
    SetCfg("lockBigButtonPos", state)
end)

addToggle(miscSection, "Lock Bind Button POS", lockBindButtonPos, function(state)
    lockBindButtonPos = state
    SetCfg("lockBindButtonPos", state)
end)

miscSection:AddButton("Reset Configuration", function()
    configResetting = true
    ConfigData = {}

    ensureConfigFolder()

    -- Prefer deleting the old settings file, then write a clean empty config.
    if type(exists) == "function" and type(deleteFile) == "function" then
        local ok, found = pcall(exists, CFG_FILE)
        if ok and found then pcall(deleteFile, CFG_FILE) end
    end
    if type(write) == "function" then
        pcall(function()
            write(CFG_FILE, "{}")
        end)
    end

    shared.Notify("Visuals V2 settings reset. Re-execute the addon to load defaults.", 2)
end)

-- Reapply character visuals after respawn.
local function onCharacterAdded(char)
    task.wait(1)

    characterOriginal = setmetatable({}, {__mode = "k"})

    if trailEnabled then createTrail() end
    if ffEnabled then applyForceField() end
    if skinTrailEnabled then
        applySkinTrail()
        refreshSkinTrailRainbowConnection()
    end
    if auraEnabled then applyAura() end
    if korbloxEnabled or headlessEnabled then applyCharacterVisuals(false) end

    setupJumpCircles(char)
    task.delay(0.5, setupSpeedButtons)
end

if player.Character then
    task.defer(function()
        onCharacterAdded(player.Character)
    end)
end
player.CharacterAdded:Connect(onCharacterAdded)

shared.Notify("Visuals V2 loaded", 2)
