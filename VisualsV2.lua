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

-- Big button settings (rectangular button based on the supplied BigButtons example).
local speedButtonVisible = C("speedButtonVisible", false)
local speedButtonWidth = C("speedButtonWidth", 120)
local speedButtonHeight = C("speedButtonHeight", 44)
local speedButtonColor = C("speedButtonColor", Color3.fromRGB(0, 0, 0))
local speedButtonTransparency = C("speedButtonTransparency", 0.65)
local speedButtonOutlineColor = C("speedButtonOutlineColor", Color3.fromRGB(255, 255, 255))
local speedButtonOutlineTransparency = C("speedButtonOutlineTransparency", 0.25)

-- Bindable button settings (adapted from the supplied BindableButtons example).
local speedBindButtonVisible = C("speedBindButtonVisible", true)
local speedBindButtonSize = C("speedBindButtonSize", 0.11)
local speedBindButtonTransparency = C("speedBindButtonTransparency", 0.25)

local lockBigButtonPos = C("lockBigButtonPos", false)
local lockBindButtonPos = C("lockBindButtonPos", false)

local speedGui = nil
local speedButton = nil
local speedButtonStroke = nil
local speedToggle
local speedBindValue = nil

local BIG_BUTTON_DEFAULT = UDim2.new(0.5, -60, 0.22, 0)
local BIND_BUTTON_DEFAULT = UDim2.new(0.10, 0, 0.72, 0)

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

-- =========================================================
-- BINDABLE BUTTONS
-- Based on the BindableButtons.luau supplied by the user.
-- Keeps the documented API:
--   BindableButtons.AddBButton(ID, Text, OnCallback, OffCallback)
--   BindableButtons:SetShape(ID, ShapeNumber)
--   BindableButtons:DeleteBButton(ID)
-- =========================================================

local BindableButtons = {
    Buttons = {},
    Connections = {},
    Values = {},
    Locked = {},
    BaseTransparency = {},
}

local BIND_SHAPES = {
    [0] = "rbxassetid://86221076925479",   -- Circle
    [1] = "rbxassetid://96242665417546",   -- Square
    [2] = "rbxassetid://97129189935336",   -- Hexagon
    [3] = "rbxassetid://76165862027868",   -- Star
    [4] = "rbxassetid://125868092127496",  -- Heart
}

local BIND_NORMAL_COLOR = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.new(0.133333, 0.827451, 0.494118)),
    ColorSequenceKeypoint.new(0.6, Color3.new(0.231373, 0.509804, 0.498039)),
    ColorSequenceKeypoint.new(1, Color3.new(0.501961, 0.501961, 0.501961)),
})

local BIND_TOGGLED_COLOR = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.new(0.0784314, 0.0784314, 0.0784314)),
    ColorSequenceKeypoint.new(0.75, Color3.new(0.0784314, 0.0784314, 0.54902)),
    ColorSequenceKeypoint.new(1, Color3.new(0.470588, 0.156863, 0.470588)),
})

local function safeCallback(callback)
    if not callback then return end
    local ok, err = xpcall(callback, function(e)
        return debug.traceback(e)
    end)
    if not ok then
        warn("[Visuals V2] Bindable button callback error: " .. tostring(err))
    end
end

local function getBindStorage()
    local storageParent
    local ok, hui = pcall(function()
        return gethui and gethui()
    end)
    if ok and hui and typeof(hui) == "Instance" then
        storageParent = hui
    else
        local okCore, core = pcall(function()
            return game:GetService("CoreGui")
        end)
        if okCore and core then
            storageParent = core
        else
            storageParent = player:WaitForChild("PlayerGui")
        end
    end

    local storage = storageParent:FindFirstChild("@bindstorage")
    if not storage then
        storage = Instance.new("ScreenGui")
        storage.Name = "@bindstorage"
        storage.ResetOnSpawn = false
        storage.IgnoreGuiInset = true
        pcall(function()
            storage.ScreenInsets = Enum.ScreenInsets.None
        end)
        storage.Parent = storageParent
    end
    return storage
end

function BindableButtons:DeleteBButton(id)
    local conns = self.Connections[id]
    if conns then
        for _, conn in ipairs(conns) do
            pcall(function() conn:Disconnect() end)
        end
    end

    local button = self.Buttons[id]
    if button then
        pcall(function() button:Destroy() end)
    end

    self.Buttons[id] = nil
    self.Connections[id] = nil
    self.Values[id] = nil
    self.Locked[id] = nil
    self.BaseTransparency[id] = nil
end

function BindableButtons:SetShape(id, shape)
    local button = self.Buttons[id]
    if button and BIND_SHAPES[shape] then
        button.Image = BIND_SHAPES[shape]
    end
end

function BindableButtons:SetLocked(id, locked)
    self.Locked[id] = not not locked
end

function BindableButtons:SetVisible(id, visible)
    local button = self.Buttons[id]
    if button then button.Visible = not not visible end
end

function BindableButtons:SetText(id, text)
    local button = self.Buttons[id]
    local label = button and button:FindFirstChild("@Text")
    if label then label.Text = tostring(text or "") end
end

function BindableButtons:SetPosition(id, pos)
    local button = self.Buttons[id]
    if button then button.Position = pos end
end

function BindableButtons:GetPosition(id)
    local button = self.Buttons[id]
    return button and button.Position or nil
end

function BindableButtons:SetSize(id, buttonSizeY)
    local button = self.Buttons[id]
    if not button then return end

    buttonSizeY = math.clamp(tonumber(buttonSizeY) or 0.11, 0.05, 0.22)
    local camera = workspace.CurrentCamera
    local screen = camera and camera.ViewportSize or Vector2.new(1920, 1080)
    local widthScale = buttonSizeY * (screen.Y / math.max(screen.X, 1))

    button.Size = UDim2.new(widthScale, 0, buttonSizeY, 0)
end

function BindableButtons:SetTransparency(id, transparency)
    local button = self.Buttons[id]
    if not button then return end
    transparency = math.clamp(tonumber(transparency) or 0, 0, 1)
    self.BaseTransparency[id] = transparency
    button.ImageTransparency = transparency
end

function BindableButtons:SetValue(id, state, runCallback)
    local value = self.Values[id]
    local button = self.Buttons[id]
    if not value or not button then return end

    state = not not state
    if value.Value == state then
        local stroke = button:FindFirstChild("@Stroke")
        if stroke then stroke.Color = state and BIND_TOGGLED_COLOR or BIND_NORMAL_COLOR end
        return
    end

    value.Value = state
    local stroke = button:FindFirstChild("@Stroke")
    if stroke then stroke.Color = state and BIND_TOGGLED_COLOR or BIND_NORMAL_COLOR end

    if runCallback then
        local onCallback = button:GetAttribute("VisualsV2_OnCallback")
        -- callbacks are held separately below; attribute exists only as a marker.
    end
end

function BindableButtons.AddBButton(id, text, onFunc, offFunc, onMoved)
    -- Remove an older button left behind by a previous execution.
    local storage = getBindStorage()
    local existing = storage:FindFirstChild(id)
    if existing then existing:Destroy() end
    BindableButtons:DeleteBButton(id)

    local camera = workspace.CurrentCamera
    local screen = camera and camera.ViewportSize or Vector2.new(1920, 1080)
    local buttonSizeY = speedBindButtonSize
    local widthScale = buttonSizeY * (screen.Y / math.max(screen.X, 1))

    local imageButton = Instance.new("ImageButton")
    imageButton.Name = id
    imageButton.Size = UDim2.new(widthScale, 0, buttonSizeY, 0)
    imageButton.Position = loadStoredPosition("speedBindButtonPosition", BIND_BUTTON_DEFAULT)
    imageButton.AnchorPoint = Vector2.new(0.5, 0.5)
    imageButton.Image = BIND_SHAPES[1]
    imageButton.BackgroundTransparency = 1
    imageButton.BorderSizePixel = 0
    imageButton.ClipsDescendants = false
    imageButton.AutoButtonColor = false
    imageButton.Visible = speedBindButtonVisible
    imageButton.Parent = storage

    local bindValue = Instance.new("BoolValue")
    bindValue.Name = "BindValue"
    bindValue.Value = speedEnabled
    bindValue.Parent = imageButton

    local textLabel = Instance.new("TextLabel")
    textLabel.Name = "@Text"
    textLabel.Size = UDim2.new(0.8, 0, 0.8, 0)
    textLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
    textLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    textLabel.BackgroundTransparency = 1
    textLabel.Font = Enum.Font.Jura
    textLabel.Text = text or ""
    textLabel.TextColor3 = Color3.new(1, 1, 1)
    textLabel.TextSize = 10
    textLabel.TextWrapped = true
    textLabel.TextStrokeTransparency = 1
    textLabel.ZIndex = 3
    textLabel.Parent = imageButton

    local aspect = Instance.new("UIAspectRatioConstraint")
    aspect.AspectRatio = 1
    aspect.AspectType = Enum.AspectType.ScaleWithParentSize
    aspect.Parent = imageButton

    local stroke = Instance.new("UIGradient")
    stroke.Name = "@Stroke"
    stroke.Color = bindValue.Value and BIND_TOGGLED_COLOR or BIND_NORMAL_COLOR
    stroke.Parent = imageButton

    local ripple = Instance.new("Frame")
    ripple.Name = "@ripple"
    ripple.BackgroundColor3 = Color3.fromRGB(0, 155, 255)
    ripple.BackgroundTransparency = 0.5
    ripple.Size = UDim2.new(0, 0, 0, 0)
    ripple.AnchorPoint = Vector2.new(0.5, 0.5)
    ripple.Visible = false
    ripple.ZIndex = 2
    ripple.Parent = imageButton
    Instance.new("UICorner", ripple).CornerRadius = UDim.new(1, 0)

    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://3868133279"
    sound.Volume = 0.5
    sound.Parent = imageButton

    BindableButtons.Buttons[id] = imageButton
    BindableButtons.Values[id] = bindValue
    BindableButtons.Connections[id] = {}
    BindableButtons.Locked[id] = lockBindButtonPos
    BindableButtons.BaseTransparency[id] = speedBindButtonTransparency

    local connections = BindableButtons.Connections[id]
    local dragging = false
    local moved = false
    local dragInput = nil
    local dragStart = nil
    local startPos = nil
    local debounce = false

    local function click()
        if debounce then return end
        debounce = true

        local baseTransparency = BindableButtons.BaseTransparency[id] or 0
        local fadeOut = TweenService:Create(
            imageButton,
            TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {ImageTransparency = 1}
        )
        fadeOut:Play()
        fadeOut.Completed:Wait()

        local newState = not bindValue.Value
        bindValue.Value = newState
        stroke.Color = newState and BIND_TOGGLED_COLOR or BIND_NORMAL_COLOR

        if newState then
            safeCallback(onFunc)
        else
            safeCallback(offFunc)
        end

        local fadeIn = TweenService:Create(
            imageButton,
            TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {ImageTransparency = baseTransparency}
        )
        fadeIn:Play()
        fadeIn.Completed:Wait()
        debounce = false
    end

    table.insert(connections, imageButton.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        dragging = true
        moved = false
        dragStart = input.Position
        startPos = imageButton.Position

        sound:Play()
        local absPos = imageButton.AbsolutePosition
        ripple.Position = UDim2.new(0, input.Position.X - absPos.X, 0, input.Position.Y - absPos.Y)
        ripple.Size = UDim2.new(0, 0, 0, 0)
        ripple.BackgroundTransparency = 0.5
        ripple.Visible = true

        TweenService:Create(
            ripple,
            TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 45, 0, 45), BackgroundTransparency = 1}
        ):Play()
    end))

    table.insert(connections, imageButton.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end))

    table.insert(connections, UserInputService.InputChanged:Connect(function(input)
        if not dragging or input ~= dragInput then return end
        if BindableButtons.Locked[id] then return end

        local delta = input.Position - dragStart
        if delta.Magnitude > 7 then moved = true end

        local parentSize = imageButton.Parent.AbsoluteSize
        local xScaleDelta = delta.X / math.max(parentSize.X, 1)
        local yScaleDelta = delta.Y / math.max(parentSize.Y, 1)

        imageButton.Position = UDim2.new(
            startPos.X.Scale + xScaleDelta,
            startPos.X.Offset,
            startPos.Y.Scale + yScaleDelta,
            startPos.Y.Offset
        )
    end))

    table.insert(connections, UserInputService.InputEnded:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        dragging = false

        if moved and not BindableButtons.Locked[id] then
            if onMoved then safeCallback(function() onMoved(imageButton.Position) end) end
        else
            task.spawn(click)
        end
    end))

    table.insert(connections, RunService.RenderStepped:Connect(function()
        stroke.Rotation = (stroke.Rotation + 1) % 360
    end))

    imageButton.ImageTransparency = speedBindButtonTransparency
    return bindValue
end

local function toggleSpeedFromButton()
    if speedToggle then
        speedToggle:Set(not speedEnabled)
    end
end

local function setSpeedFromBindable(state)
    if speedToggle then
        speedToggle:Set(state)
    end
end

local function updateSpeedButtonStyle()
    if speedButton then
        speedButton.Size = UDim2.new(0, speedButtonWidth, 0, speedButtonHeight)
        speedButton.BackgroundColor3 = speedButtonColor
        speedButton.BackgroundTransparency = math.clamp(speedButtonTransparency, 0, 1)
        speedButton.Text = speedEnabled and "ACTIVE" or ""
        speedButton.TextStrokeTransparency = 1
        speedButton.Visible = speedButtonVisible
    end

    if speedButtonStroke then
        speedButtonStroke.Color = speedButtonOutlineColor
        speedButtonStroke.Transparency = math.clamp(speedButtonOutlineTransparency, 0, 1)
    end

    local bindId = "VisualsV2_SpeedBind"
    BindableButtons:SetVisible(bindId, speedBindButtonVisible)
    BindableButtons:SetLocked(bindId, lockBindButtonPos)
    BindableButtons:SetSize(bindId, speedBindButtonSize)
    BindableButtons:SetTransparency(bindId, speedBindButtonTransparency)
    BindableButtons:SetText(bindId, speedEnabled and "ACTIVE" or "")

    local value = BindableButtons.Values[bindId]
    local button = BindableButtons.Buttons[bindId]
    if value and button then
        value.Value = speedEnabled
        local stroke = button:FindFirstChild("@Stroke")
        if stroke then
            stroke.Color = speedEnabled and BIND_TOGGLED_COLOR or BIND_NORMAL_COLOR
        end
    end
end

local function makeDraggableBigButton(button)
    local activePointer = false
    local moved = false
    local dragStart
    local startPos
    local dragInput

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

    button.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not activePointer or input ~= dragInput or lockBigButtonPos then return end
        local delta = input.Position - dragStart
        if delta.Magnitude >= 7 then moved = true end

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
        if moved and not lockBigButtonPos then
            saveStoredPosition("speedButtonPosition", button.Position)
        else
            toggleSpeedFromButton()
        end
    end)
end

local function setupSpeedButtons()
    if speedGui then speedGui:Destroy() end

    -- Rebuild the rectangular big button.
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
    big.AnchorPoint = Vector2.new(0.5, 0.5)
    big.BackgroundColor3 = speedButtonColor
    big.BackgroundTransparency = math.clamp(speedButtonTransparency, 0, 1)
    big.BorderSizePixel = 0
    big.TextColor3 = Color3.fromRGB(255, 255, 255)
    big.TextScaled = true
    big.TextStrokeTransparency = 1
    big.Font = Enum.Font.Jura
    big.Text = speedEnabled and "ACTIVE" or ""
    big.Active = true
    big.AutoButtonColor = false
    big.Visible = speedButtonVisible
    big.Parent = gui
    speedButton = big

    local bigCorner = Instance.new("UICorner")
    bigCorner.CornerRadius = UDim.new(0, 5)
    bigCorner.Parent = big

    local bigStroke = Instance.new("UIStroke")
    bigStroke.Thickness = 1.5
    bigStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    bigStroke.LineJoinMode = Enum.LineJoinMode.Round
    bigStroke.Color = speedButtonOutlineColor
    bigStroke.Transparency = math.clamp(speedButtonOutlineTransparency, 0, 1)
    bigStroke.Parent = big
    speedButtonStroke = bigStroke

    makeDraggableBigButton(big)

    -- Build the actual BindableButtons-style bind button.
    local bindId = "VisualsV2_SpeedBind"
    speedBindValue = BindableButtons.AddBButton(
        bindId,
        speedEnabled and "ACTIVE" or "",
        function()
            setSpeedFromBindable(true)
        end,
        function()
            setSpeedFromBindable(false)
        end,
        function(pos)
            saveStoredPosition("speedBindButtonPosition", pos)
        end
    )

    BindableButtons:SetShape(bindId, 1)
    BindableButtons:SetPosition(bindId, loadStoredPosition("speedBindButtonPosition", BIND_BUTTON_DEFAULT))
    BindableButtons:SetLocked(bindId, lockBindButtonPos)
    BindableButtons:SetVisible(bindId, speedBindButtonVisible)
    BindableButtons:SetSize(bindId, speedBindButtonSize)
    BindableButtons:SetTransparency(bindId, speedBindButtonTransparency)

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

-- Native ODH keyboard bind is kept for PC users.
speedSection:AddKeybind("Speed Glitch Bind", "G", function()
    toggleSpeedFromButton()
end)

addToggle(speedSection, "Show Big Button", speedButtonVisible, function(state)
    speedButtonVisible = state
    SetCfg("speedButtonVisible", state)
    updateSpeedButtonStyle()
end)

addToggle(speedSection, "Show Bindable Button", speedBindButtonVisible, function(state)
    speedBindButtonVisible = state
    SetCfg("speedBindButtonVisible", state)
    updateSpeedButtonStyle()
end)

speedSection:AddSlider("Big Button Width", 70, 260, speedButtonWidth, function(value)
    speedButtonWidth = value
    SetCfg("speedButtonWidth", value)
    updateSpeedButtonStyle()
end)

speedSection:AddSlider("Big Button Height", 28, 110, speedButtonHeight, function(value)
    speedButtonHeight = value
    SetCfg("speedButtonHeight", value)
    updateSpeedButtonStyle()
end)

speedSection:AddColorpicker("Big Button Color", speedButtonColor, function(color)
    speedButtonColor = color
    SetCfg("speedButtonColor", color)
    updateSpeedButtonStyle()
end)

speedSection:AddSlider("Big Button Transparency", 0, 1, speedButtonTransparency, function(value)
    speedButtonTransparency = value
    SetCfg("speedButtonTransparency", value)
    updateSpeedButtonStyle()
end)

speedSection:AddColorpicker("Big Button Outline Color", speedButtonOutlineColor, function(color)
    speedButtonOutlineColor = color
    SetCfg("speedButtonOutlineColor", color)
    updateSpeedButtonStyle()
end)

speedSection:AddSlider("Big Button Outline Transparency", 0, 1, speedButtonOutlineTransparency, function(value)
    speedButtonOutlineTransparency = value
    SetCfg("speedButtonOutlineTransparency", value)
    updateSpeedButtonStyle()
end)

speedSection:AddSlider("Bind Button Size", 0.05, 0.22, speedBindButtonSize, function(value)
    speedBindButtonSize = value
    SetCfg("speedBindButtonSize", value)
    updateSpeedButtonStyle()
end)

speedSection:AddSlider("Bind Button Transparency", 0, 1, speedBindButtonTransparency, function(value)
    speedBindButtonTransparency = value
    SetCfg("speedBindButtonTransparency", value)
    updateSpeedButtonStyle()
end)

speedSection:AddButton("Reset Big Button Position", function()
    if speedButton then speedButton.Position = BIG_BUTTON_DEFAULT end
    SetCfg("speedButtonPosition", nil)
end)

speedSection:AddButton("Reset Bind Button Position", function()
    BindableButtons:SetPosition("VisualsV2_SpeedBind", BIND_BUTTON_DEFAULT)
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
-- UTILITIES: SHOOT MURDERER BUTTON
-- Adapted from the supplied SMB plugin.
-- It customizes the existing Shoot Murderer button; it does not create the action.
-- =========================================================

local shootSection = mainTab:AddSection("Shoot Murderer Button", "Utilities")

local shootButtonWidth = C("shootButtonWidth", 100)
local shootButtonHeight = C("shootButtonHeight", 40)
local shootKeepGunEnabled = C("shootKeepGunEnabled", false)
local shootDragEnabled = C("shootDragEnabled", false)
local shootHideText = C("shootHideText", false)

local shootButton = nil
local shootScale = nil
local shootOldText = nil
local shootConnections = {}
local shootGunConnection = nil
local shootGunTask = nil
local shootDragging = false
local shootDragInput = nil
local shootDragStart = nil
local shootStartPos = nil

local SHOOT_DEFAULT_POS = UDim2.new(0.5, -shootButtonWidth / 2, 0.5, -shootButtonHeight / 2)
local shootButtonPos = loadStoredPosition("shootMurdButtonPosition", SHOOT_DEFAULT_POS)

local function shootNormalize(value)
    return tostring(value or ""):lower():gsub("%s+", "")
end

local function getShootRoots()
    local roots = {}
    local seen = {}

    local function add(root)
        if root and not seen[root] then
            seen[root] = true
            table.insert(roots, root)
        end
    end

    pcall(function() add(game:GetService("CoreGui")) end)
    pcall(function()
        if gethui then add(gethui()) end
    end)
    pcall(function() add(player:FindFirstChildOfClass("PlayerGui")) end)

    return roots
end

local function isShootMurderButton(item)
    if not item or not item:IsA("TextButton") then return false end

    local ownText = shootNormalize(item.Text)
    if ownText:find("shootmurderer", 1, true) then return true end

    local label = item:FindFirstChildWhichIsA("TextLabel", true)
    if label and shootNormalize(label.Text):find("shootmurderer", 1, true) then
        return true
    end

    return item:GetAttribute("ShootMurderButton") == true
end

local function findShootMurderButton()
    for _, root in ipairs(getShootRoots()) do
        local ok, descendants = pcall(function()
            return root:GetDescendants()
        end)
        if ok then
            for _, item in ipairs(descendants) do
                if isShootMurderButton(item) then
                    item:SetAttribute("ShootMurderButton", true)
                    return item
                end
            end
        end
    end
end

local function stopShootGunKeeper()
    if shootGunConnection then
        shootGunConnection:Disconnect()
        shootGunConnection = nil
    end
    if shootGunTask then
        pcall(task.cancel, shootGunTask)
        shootGunTask = nil
    end
end

local function keepShootGunEquipped()
    if not shootKeepGunEnabled then return end

    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    local gun = nil
    local backpack = player:FindFirstChildOfClass("Backpack")
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") and item.Name:lower():find("gun", 1, true) then
                gun = item
                break
            end
        end
    end

    if not gun and character then
        for _, item in ipairs(character:GetChildren()) do
            if item:IsA("Tool") and item.Name:lower():find("gun", 1, true) then
                gun = item
                break
            end
        end
    end

    if not gun then return end

    stopShootGunKeeper()

    shootGunConnection = gun.AncestryChanged:Connect(function(_, parent)
        if shootKeepGunEnabled and backpack and parent == backpack then
            task.defer(function()
                if humanoid and humanoid.Parent and gun and gun.Parent then
                    pcall(function() humanoid:EquipTool(gun) end)
                end
            end)
        end
    end)

    shootGunTask = task.delay(0.3, stopShootGunKeeper)
end

local function animateShootButton()
    if not shootScale then return end

    shootScale.Scale = 0.91
    TweenService:Create(
        shootScale,
        TweenInfo.new(0.65, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
        {Scale = 1}
    ):Play()
end

local function updateShootButton()
    if not shootButton then return end

    shootButton.Size = UDim2.new(0, shootButtonWidth, 0, shootButtonHeight)
    shootButton.Position = shootButtonPos
    shootButton.Text = shootHideText and "" or (shootOldText or "Shoot Murderer")
end

local function clearShootButtonConnections()
    for _, connection in ipairs(shootConnections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(shootConnections)

    if shootScale then
        pcall(function() shootScale:Destroy() end)
        shootScale = nil
    end
end

local function bindShootMurderButton(newButton)
    if not newButton or shootButton == newButton then return end

    clearShootButtonConnections()

    shootButton = newButton
    shootButton:SetAttribute("ShootMurderButton", true)
    shootOldText = shootButton.Text

    shootScale = Instance.new("UIScale")
    shootScale.Parent = shootButton

    updateShootButton()

    table.insert(shootConnections, shootButton.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        if shootDragEnabled then
            shootDragging = true
            shootDragInput = input
            shootDragStart = input.Position
            shootStartPos = shootButton.Position
        else
            keepShootGunEquipped()
            animateShootButton()
        end
    end))

    table.insert(shootConnections, UserInputService.InputChanged:Connect(function(input)
        if not shootDragEnabled or not shootDragging or not shootButton then return end

        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        if shootDragInput
            and shootDragInput.UserInputType == Enum.UserInputType.Touch
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        local delta = input.Position - shootDragStart
        shootButton.Position = UDim2.new(
            shootStartPos.X.Scale,
            shootStartPos.X.Offset + delta.X,
            shootStartPos.Y.Scale,
            shootStartPos.Y.Offset + delta.Y
        )
    end))

    table.insert(shootConnections, UserInputService.InputEnded:Connect(function(input)
        if not shootDragging then return end

        if input == shootDragInput
            or input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then

            shootDragging = false
            shootDragInput = nil

            if shootButton then
                shootButtonPos = shootButton.Position
                saveStoredPosition("shootMurdButtonPosition", shootButtonPos)
            end
        end
    end))

    table.insert(shootConnections, shootButton:GetPropertyChangedSignal("Size"):Connect(function()
        if not shootButton then return end
        local wanted = UDim2.new(0, shootButtonWidth, 0, shootButtonHeight)
        if shootButton.Size ~= wanted then
            shootButton.Size = wanted
        end
    end))

    table.insert(shootConnections, shootButton.AncestryChanged:Connect(function()
        if shootButton and not shootButton:IsDescendantOf(game) then
            shootButton = nil
            task.defer(function()
                local replacement = findShootMurderButton()
                if replacement then bindShootMurderButton(replacement) end
            end)
        end
    end))
end

shootSection:AddSlider("Button Width", 40, 300, shootButtonWidth, function(value)
    shootButtonWidth = value
    SetCfg("shootButtonWidth", value)
    updateShootButton()
end)

shootSection:AddSlider("Button Height", 20, 150, shootButtonHeight, function(value)
    shootButtonHeight = value
    SetCfg("shootButtonHeight", value)
    updateShootButton()
end)

addToggle(shootSection, "Keep Gun Equipped", shootKeepGunEnabled, function(state)
    shootKeepGunEnabled = state
    SetCfg("shootKeepGunEnabled", state)
    if not state then stopShootGunKeeper() end
end)

addToggle(shootSection, "Allow Drag", shootDragEnabled, function(state)
    shootDragEnabled = state
    SetCfg("shootDragEnabled", state)
    shootDragging = false
    shootDragInput = nil
end)

addToggle(shootSection, "Hide Button Text", shootHideText, function(state)
    shootHideText = state
    SetCfg("shootHideText", state)
    updateShootButton()
end)

shootSection:AddButton("Save Button Position", function()
    if shootButton then
        shootButtonPos = shootButton.Position
        saveStoredPosition("shootMurdButtonPosition", shootButtonPos)
        shared.Notify("Shoot Murderer button position saved.", 2)
    else
        shared.Notify("Shoot Murderer button was not found.", 2)
    end
end)

shootSection:AddButton("Reset Button Position", function()
    SHOOT_DEFAULT_POS = UDim2.new(0.5, -shootButtonWidth / 2, 0.5, -shootButtonHeight / 2)
    shootButtonPos = SHOOT_DEFAULT_POS
    SetCfg("shootMurdButtonPosition", nil)
    if shootButton then shootButton.Position = shootButtonPos end
end)

shootSection:AddButton("Rescan Shoot Murderer Button", function()
    local found = findShootMurderButton()
    if found then
        bindShootMurderButton(found)
        shared.Notify("Shoot Murderer button found.", 2)
    else
        shared.Notify("Shoot Murderer button was not found.", 2)
    end
end)

task.defer(function()
    task.wait(0.5)
    local found = findShootMurderButton()
    if found then bindShootMurderButton(found) end

    for _, root in ipairs(getShootRoots()) do
        pcall(function()
            root.DescendantAdded:Connect(function(item)
                if isShootMurderButton(item) then
                    task.defer(function() bindShootMurderButton(item) end)
                end
            end)
        end)
    end
end)

-- =========================================================
-- VISUALS: BINDABLE BUTTON VISUALS
-- Based on the supplied BindableButtonsColor plugin, with a new 3-color gradient.
-- =========================================================

local bindVisualSection = mainTab:AddSection("Bindable Button Visuals", "Visuals")

local bindVisualEnabled = C("bindVisualEnabled", false)
local bindVisualBgColor = C("bindVisualBgColor", Color3.fromRGB(255, 70, 70))
local bindVisualTextColor = C("bindVisualTextColor", Color3.fromRGB(255, 255, 255))
local bindVisualStrokeColor = C("bindVisualStrokeColor", Color3.fromRGB(0, 0, 0))
local bindVisualGradientEnabled = C("bindVisualGradientEnabled", false)
local bindVisualGradient1 = C("bindVisualGradient1", Color3.fromRGB(255, 255, 255))
local bindVisualGradient2 = C("bindVisualGradient2", Color3.fromRGB(180, 120, 255))
local bindVisualGradient3 = C("bindVisualGradient3", Color3.fromRGB(80, 160, 255))
local bindVisualGradientRotation = C("bindVisualGradientRotation", 0)

local bindVisualTargets = setmetatable({}, {__mode = "k"})
local bindVisualOriginals = setmetatable({}, {__mode = "k"})
local bindVisualManualTarget = nil
local BIND_VISUAL_GRADIENT_NAME = "VisualsV2_ThreeColorGradient"

local function normalizeBindVisual(value)
    return tostring(value or ""):lower():gsub("<[^>]*>", ""):gsub("%s+", "")
end

local function isInsideBindStorage(inst)
    local cur = inst
    local depth = 0
    while cur and depth < 30 do
        if cur.Name == "@bindstorage" then return true end
        cur = cur.Parent
        depth = depth + 1
    end
    return false
end

local function isBindableVisualCandidate(inst)
    if not inst or not inst:IsA("GuiButton") then return false end

    if isInsideBindStorage(inst) then
        return true
    end

    local ownText = nil
    pcall(function() ownText = normalizeBindVisual(inst.Text) end)

    local childText = nil
    local label = inst:FindFirstChildWhichIsA("TextLabel", true)
    if label then childText = normalizeBindVisual(label.Text) end

    local name = normalizeBindVisual(inst.Name)

    return (ownText and ownText:find("shootmurderer", 1, true))
        or (childText and childText:find("shootmurderer", 1, true))
        or name:find("shootmurderer", 1, true)
end

local function snapshotBindableObject(obj)
    if bindVisualOriginals[obj] then return bindVisualOriginals[obj] end

    local snap = {}

    pcall(function()
        if obj:IsA("GuiObject") then
            snap.BackgroundColor3 = obj.BackgroundColor3
        end
        if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
            snap.ImageColor3 = obj.ImageColor3
        end
        if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
            snap.TextColor3 = obj.TextColor3
            snap.TextStrokeColor3 = obj.TextStrokeColor3
        end
        if obj:IsA("UIStroke") then
            snap.UIStrokeColor = obj.Color
        end
        if obj:IsA("UIGradient") then
            snap.GradientColor = obj.Color
            snap.GradientRotation = obj.Rotation
        end
    end)

    bindVisualOriginals[obj] = snap
    return snap
end

local function gradientSequence()
    return ColorSequence.new({
        ColorSequenceKeypoint.new(0, bindVisualGradient1),
        ColorSequenceKeypoint.new(0.5, bindVisualGradient2),
        ColorSequenceKeypoint.new(1, bindVisualGradient3),
    })
end

local function styleBindableTree(root)
    if not root or not root.Parent then return end

    bindVisualTargets[root] = true

    local objects = {root}
    for _, obj in ipairs(root:GetDescendants()) do
        table.insert(objects, obj)
    end

    local existingGradient = nil

    for _, obj in ipairs(objects) do
        snapshotBindableObject(obj)

        pcall(function()
            if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
                obj.ImageColor3 = bindVisualBgColor
            elseif obj:IsA("GuiObject") and not obj:IsA("TextLabel") and not obj:IsA("TextBox") then
                obj.BackgroundColor3 = bindVisualBgColor
            end

            if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                obj.TextColor3 = bindVisualTextColor
                obj.TextStrokeColor3 = bindVisualStrokeColor
            end

            if obj:IsA("UIStroke") then
                obj.Color = bindVisualStrokeColor
            end

            if obj:IsA("UIGradient") and not existingGradient then
                existingGradient = obj
            end
        end)
    end

    if bindVisualGradientEnabled then
        local gradient = existingGradient
        if not gradient then
            gradient = root:FindFirstChild(BIND_VISUAL_GRADIENT_NAME)
        end
        if not gradient then
            gradient = Instance.new("UIGradient")
            gradient.Name = BIND_VISUAL_GRADIENT_NAME
            gradient.Parent = root
        end
        snapshotBindableObject(gradient)
        gradient.Color = gradientSequence()
        gradient.Rotation = bindVisualGradientRotation
    else
        local ours = root:FindFirstChild(BIND_VISUAL_GRADIENT_NAME)
        if ours then ours:Destroy() end

        if existingGradient then
            local original = bindVisualOriginals[existingGradient]
            if original and original.GradientColor then
                existingGradient.Color = original.GradientColor
                existingGradient.Rotation = original.GradientRotation or 0
            end
        end
    end
end

local function restoreBindableVisuals()
    for obj, snap in pairs(bindVisualOriginals) do
        pcall(function()
            if obj and obj.Parent then
                if snap.BackgroundColor3 then obj.BackgroundColor3 = snap.BackgroundColor3 end
                if snap.ImageColor3 then obj.ImageColor3 = snap.ImageColor3 end
                if snap.TextColor3 then obj.TextColor3 = snap.TextColor3 end
                if snap.TextStrokeColor3 then obj.TextStrokeColor3 = snap.TextStrokeColor3 end
                if snap.UIStrokeColor then obj.Color = snap.UIStrokeColor end
                if snap.GradientColor then
                    obj.Color = snap.GradientColor
                    obj.Rotation = snap.GradientRotation or 0
                end
            end
        end)
    end

    for root in pairs(bindVisualTargets) do
        if root and root.Parent then
            local ours = root:FindFirstChild(BIND_VISUAL_GRADIENT_NAME)
            if ours then ours:Destroy() end
        end
    end
end

local function scanBindableVisualTargets()
    local found = 0
    for _, root in ipairs(getShootRoots()) do
        local ok, descendants = pcall(function()
            return root:GetDescendants()
        end)
        if ok then
            for _, inst in ipairs(descendants) do
                if isBindableVisualCandidate(inst) then
                    bindVisualTargets[inst] = true
                    found = found + 1
                    if bindVisualEnabled then
                        styleBindableTree(inst)
                    end
                end
            end
        end
    end

    if bindVisualManualTarget and bindVisualManualTarget.Parent then
        bindVisualTargets[bindVisualManualTarget] = true
        if bindVisualEnabled then styleBindableTree(bindVisualManualTarget) end
    end

    return found
end

local function applyBindableVisuals()
    if not bindVisualEnabled then return end
    scanBindableVisualTargets()
    for target in pairs(bindVisualTargets) do
        if target and target.Parent then
            styleBindableTree(target)
        end
    end
end

local function pickBindableButton()
    local gui = Instance.new("ScreenGui")
    gui.Name = "VisualsV2_BindPicker"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 2000000000

    local overlay = Instance.new("TextButton")
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.BackgroundTransparency = 1
    overlay.Text = ""
    overlay.AutoButtonColor = false
    overlay.Active = true
    overlay.Parent = gui

    local parent = nil
    pcall(function() parent = gethui and gethui() end)
    if not parent then parent = game:GetService("CoreGui") end
    gui.Parent = parent

    local finished = false

    local function finish(x, y)
        if finished then return end
        finished = true

        local best = nil
        local bestArea = math.huge

        for _, root in ipairs(getShootRoots()) do
            local ok, descendants = pcall(function()
                return root:GetDescendants()
            end)
            if ok then
                for _, inst in ipairs(descendants) do
                    if inst ~= overlay and inst:IsA("GuiButton") and inst.Visible then
                        local pos = inst.AbsolutePosition
                        local size = inst.AbsoluteSize
                        if x >= pos.X and x <= pos.X + size.X and y >= pos.Y and y <= pos.Y + size.Y then
                            local area = size.X * size.Y
                            if area < bestArea then
                                best = inst
                                bestArea = area
                            end
                        end
                    end
                end
            end
        end

        gui:Destroy()

        if best then
            bindVisualManualTarget = best
            bindVisualTargets[best] = true
            if bindVisualEnabled then styleBindableTree(best) end
            shared.Notify("Bindable button selected: " .. tostring(best.Name), 3)
        else
            shared.Notify("No button found under that tap.", 2)
        end
    end

    overlay.Activated:Connect(function(inputObject)
        local position = inputObject and inputObject.Position
        if position then
            finish(position.X, position.Y)
        end
    end)

    task.delay(6, function()
        if not finished and gui.Parent then
            finished = true
            gui:Destroy()
            shared.Notify("Button selection timed out.", 2)
        end
    end)

    shared.Notify("Tap the bindable button you want to customize.", 3)
end

addToggle(bindVisualSection, "Enable Bindable Button Visuals", bindVisualEnabled, function(state)
    bindVisualEnabled = state
    SetCfg("bindVisualEnabled", state)

    if state then
        applyBindableVisuals()
    else
        restoreBindableVisuals()
    end
end)

bindVisualSection:AddColorpicker("Button / Icon Color", bindVisualBgColor, function(color)
    bindVisualBgColor = color
    SetCfg("bindVisualBgColor", color)
    applyBindableVisuals()
end)

bindVisualSection:AddColorpicker("Text Color", bindVisualTextColor, function(color)
    bindVisualTextColor = color
    SetCfg("bindVisualTextColor", color)
    applyBindableVisuals()
end)

bindVisualSection:AddColorpicker("Outline Color", bindVisualStrokeColor, function(color)
    bindVisualStrokeColor = color
    SetCfg("bindVisualStrokeColor", color)
    applyBindableVisuals()
end)

addToggle(bindVisualSection, "Three Color Gradient", bindVisualGradientEnabled, function(state)
    bindVisualGradientEnabled = state
    SetCfg("bindVisualGradientEnabled", state)
    applyBindableVisuals()
end)

bindVisualSection:AddColorpicker("Gradient Color 1", bindVisualGradient1, function(color)
    bindVisualGradient1 = color
    SetCfg("bindVisualGradient1", color)
    applyBindableVisuals()
end)

bindVisualSection:AddColorpicker("Gradient Color 2", bindVisualGradient2, function(color)
    bindVisualGradient2 = color
    SetCfg("bindVisualGradient2", color)
    applyBindableVisuals()
end)

bindVisualSection:AddColorpicker("Gradient Color 3", bindVisualGradient3, function(color)
    bindVisualGradient3 = color
    SetCfg("bindVisualGradient3", color)
    applyBindableVisuals()
end)

bindVisualSection:AddSlider("Gradient Rotation", 0, 360, bindVisualGradientRotation, function(value)
    bindVisualGradientRotation = value
    SetCfg("bindVisualGradientRotation", value)
    applyBindableVisuals()
end)

bindVisualSection:AddButton("Pick Button Manually", function()
    pickBindableButton()
end)

bindVisualSection:AddButton("Rescan Bindable Buttons", function()
    local count = scanBindableVisualTargets()
    shared.Notify("Bindable button scan complete: " .. tostring(count) .. " candidate(s).", 2)
end)

bindVisualSection:AddButton("Reset Bindable Button Visuals", function()
    bindVisualEnabled = false
    SetCfg("bindVisualEnabled", false)
    restoreBindableVisuals()
    bindVisualTargets = setmetatable({}, {__mode = "k"})
    bindVisualManualTarget = nil
    shared.Notify("Bindable button visuals restored.", 2)
end)

task.defer(function()
    task.wait(1)
    scanBindableVisualTargets()

    for _, root in ipairs(getShootRoots()) do
        pcall(function()
            root.DescendantAdded:Connect(function(inst)
                if isBindableVisualCandidate(inst) then
                    bindVisualTargets[inst] = true
                    if bindVisualEnabled then
                        task.defer(function()
                            if inst and inst.Parent then styleBindableTree(inst) end
                        end)
                    end
                end
            end)
        end)
    end

    if bindVisualEnabled then applyBindableVisuals() end
end)



-- =========================================================
-- UTILITIES: FIREFLY CLUTCH
-- =========================================================

;(function()
local fireflySection = mainTab:AddSection("Firefly Clutch", "Utilities")

local fireflyEnabled = C("fireflyEnabled", false)
local fireflyAutoClutch = C("fireflyAutoClutch", false)
local fireflyShowTimer = C("fireflyShowTimer", true)
local fireflyShowBindButton = C("fireflyShowBindButton", true)
local fireflyLockBindPos = C("fireflyLockBindPos", false)
local fireflyCountdownDuration = C("fireflyCountdownDuration", 2.5)
local fireflyCooldownDuration = C("fireflyCooldownDuration", 16)
local fireflyTriggerPoint = C("fireflyTriggerPoint", 0.23)
local fireflyBurstDuration = C("fireflyBurstDuration", 0.5)
local fireflyUISize = C("fireflyUISize", 100)

local FIREFLY_BIND_ID = "VisualsV2_FireflyCooldown"
local FIREFLY_BIND_DEFAULT = UDim2.new(0.82, 0, 0.72, 0)

local fireflyTimerGui
local fireflyTimerFrame
local fireflyTimerLabel
local fireflyTimerStroke
local fireflyToolConnection
local fireflyPhaseConnection
local fireflyJumpConnection
local fireflyWatchConnections = {}
local fireflyCooldownEnd = 0
local fireflyClutchEnd = 0
local fireflyJumpTriggered = false

local function ffDisconnect(connection)
    if connection then
        pcall(function() connection:Disconnect() end)
    end
end

local function buildFireflyTimer()
    if fireflyTimerGui and fireflyTimerGui.Parent then return end

    fireflyTimerGui = Instance.new("ScreenGui")
    fireflyTimerGui.Name = "VisualsV2_FireflyTimer"
    fireflyTimerGui.ResetOnSpawn = false
    fireflyTimerGui.IgnoreGuiInset = true
    fireflyTimerGui.Parent = player:WaitForChild("PlayerGui")

    fireflyTimerFrame = Instance.new("Frame")
    fireflyTimerFrame.Name = "Timer"
    fireflyTimerFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    fireflyTimerFrame.Position = UDim2.new(0.5, 0, 0.08, 0)
    fireflyTimerFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    fireflyTimerFrame.BackgroundTransparency = 0.55
    fireflyTimerFrame.BorderSizePixel = 0
    fireflyTimerFrame.Visible = false
    fireflyTimerFrame.Parent = fireflyTimerGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = fireflyTimerFrame

    fireflyTimerStroke = Instance.new("UIStroke")
    fireflyTimerStroke.Color = Color3.fromRGB(255, 255, 255)
    fireflyTimerStroke.Transparency = 0.35
    fireflyTimerStroke.Thickness = 1
    fireflyTimerStroke.Parent = fireflyTimerFrame

    fireflyTimerLabel = Instance.new("TextLabel")
    fireflyTimerLabel.Name = "Text"
    fireflyTimerLabel.Size = UDim2.fromScale(1, 1)
    fireflyTimerLabel.BackgroundTransparency = 1
    fireflyTimerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    fireflyTimerLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    fireflyTimerLabel.TextStrokeTransparency = 0.25
    fireflyTimerLabel.Font = Enum.Font.GothamBold
    fireflyTimerLabel.Text = ""
    fireflyTimerLabel.Parent = fireflyTimerFrame
end

local function setFireflyTimerVisible(visible)
    buildFireflyTimer()
    fireflyTimerFrame.Visible = fireflyEnabled and fireflyShowTimer and visible
end

local function setFireflyTimerText(text)
    buildFireflyTimer()
    fireflyTimerLabel.Text = tostring(text or "")
end

local function applyFireflyUISize()
    buildFireflyTimer()
    local scale = math.clamp(tonumber(fireflyUISize) or 100, 50, 160) / 100
    fireflyTimerFrame.Size = UDim2.new(0, math.floor(126 * scale), 0, math.floor(34 * scale))
    fireflyTimerLabel.TextSize = math.max(8, math.floor(17 * scale))
    BindableButtons:SetSize(FIREFLY_BIND_ID, math.clamp(0.085 * scale, 0.05, 0.22))
end

local function updateFireflyCooldownButton()
    local remaining = fireflyCooldownEnd - os.clock()
    if fireflyEnabled and remaining > 0 then
        BindableButtons:SetText(FIREFLY_BIND_ID, string.format("%.1f", remaining))
    else
        BindableButtons:SetText(FIREFLY_BIND_ID, "")
    end
end

local function stopFireflyJumpBurst()
    ffDisconnect(fireflyJumpConnection)
    fireflyJumpConnection = nil
end

local function fireflyJumpOnce()
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    humanoid.Jump = true
    if humanoid.FloorMaterial ~= Enum.Material.Air then
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end

local function startFireflyJumpBurst()
    stopFireflyJumpBurst()
    local elapsed = 0
    fireflyJumpConnection = RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed >= fireflyBurstDuration then
            stopFireflyJumpBurst()
            return
        end
        fireflyJumpOnce()
    end)
end

local function stopFireflyPhase()
    ffDisconnect(fireflyPhaseConnection)
    fireflyPhaseConnection = nil
    setFireflyTimerVisible(false)
    updateFireflyCooldownButton()
end

local function startFireflyCycle()
    if not fireflyEnabled then return end
    local now = os.clock()
    if now < fireflyCooldownEnd then return end

    ffDisconnect(fireflyPhaseConnection)
    fireflyPhaseConnection = nil
    fireflyJumpTriggered = false
    fireflyClutchEnd = now + fireflyCountdownDuration
    fireflyCooldownEnd = now + fireflyCooldownDuration
    setFireflyTimerVisible(true)

    fireflyPhaseConnection = RunService.Heartbeat:Connect(function()
        local current = os.clock()
        local clutchRemaining = fireflyClutchEnd - current
        local cooldownRemaining = fireflyCooldownEnd - current

        if clutchRemaining > 0 then
            setFireflyTimerText(string.format("CLUTCH %.1f", clutchRemaining))
            if fireflyAutoClutch and not fireflyJumpTriggered and clutchRemaining <= fireflyTriggerPoint then
                fireflyJumpTriggered = true
                startFireflyJumpBurst()
            end
        elseif cooldownRemaining > 0 then
            setFireflyTimerText(string.format("CD %.1f", cooldownRemaining))
        else
            fireflyCooldownEnd = 0
            fireflyClutchEnd = 0
            stopFireflyPhase()
            return
        end

        updateFireflyCooldownButton()
    end)
end

local function clearFireflyWatchers()
    ffDisconnect(fireflyToolConnection)
    fireflyToolConnection = nil
    for _, connection in ipairs(fireflyWatchConnections) do ffDisconnect(connection) end
    table.clear(fireflyWatchConnections)
end

local function connectFireflyTool(tool)
    if not tool or not tool:IsA("Tool") or tool.Name ~= "Fireflies" then return end
    ffDisconnect(fireflyToolConnection)
    fireflyToolConnection = tool.Activated:Connect(startFireflyCycle)
end

local function watchFireflyContainer(container)
    if not container then return end
    local existing = container:FindFirstChild("Fireflies")
    if existing and existing:IsA("Tool") then connectFireflyTool(existing) end
    table.insert(fireflyWatchConnections, container.ChildAdded:Connect(function(child)
        if child:IsA("Tool") and child.Name == "Fireflies" then connectFireflyTool(child) end
    end))
end

local function hookFireflyTool()
    clearFireflyWatchers()
    watchFireflyContainer(player:FindFirstChildOfClass("Backpack"))
    watchFireflyContainer(player.Character)
    table.insert(fireflyWatchConnections, player.ChildAdded:Connect(function(child)
        if child:IsA("Backpack") then watchFireflyContainer(child) end
    end))
    table.insert(fireflyWatchConnections, player.CharacterAdded:Connect(function(character)
        task.wait(0.2)
        watchFireflyContainer(character)
    end))
end

local function stopFirefly()
    clearFireflyWatchers()
    stopFireflyJumpBurst()
    stopFireflyPhase()
    fireflyCooldownEnd = 0
    fireflyClutchEnd = 0
    fireflyJumpTriggered = false
    updateFireflyCooldownButton()
end

local function syncFireflyBindButton()
    BindableButtons:SetVisible(FIREFLY_BIND_ID, fireflyEnabled and fireflyShowBindButton)
    BindableButtons:SetLocked(FIREFLY_BIND_ID, fireflyLockBindPos)
    BindableButtons:SetValue(FIREFLY_BIND_ID, false, false)
    applyFireflyUISize()
    updateFireflyCooldownButton()
end

-- Display-only bindable button. It only shows the cooldown countdown.
BindableButtons.AddBButton(
    FIREFLY_BIND_ID,
    "",
    function()
        task.defer(function()
            BindableButtons:SetValue(FIREFLY_BIND_ID, false, false)
            updateFireflyCooldownButton()
        end)
    end,
    function()
        updateFireflyCooldownButton()
    end,
    function(position)
        saveStoredPosition("fireflyBindButtonPosition", position)
    end
)
BindableButtons:SetShape(FIREFLY_BIND_ID, 0)
BindableButtons:SetPosition(FIREFLY_BIND_ID, loadStoredPosition("fireflyBindButtonPosition", FIREFLY_BIND_DEFAULT))

fireflySection:AddParagraph(
    "Firefly Clutch",
    "Top-center countdown before the clutch, then cooldown. The bindable button is only a movable cooldown timer."
)

addToggle(fireflySection, "Enable Firefly Clutch", fireflyEnabled, function(state)
    fireflyEnabled = state
    SetCfg("fireflyEnabled", state)
    if state then hookFireflyTool() else stopFirefly() end
    syncFireflyBindButton()
end)

addToggle(fireflySection, "Auto Firefly Clutch", fireflyAutoClutch, function(state)
    fireflyAutoClutch = state
    SetCfg("fireflyAutoClutch", state)
end)

addToggle(fireflySection, "Show Top Timer", fireflyShowTimer, function(state)
    fireflyShowTimer = state
    SetCfg("fireflyShowTimer", state)
    if not state then setFireflyTimerVisible(false) end
end)

addToggle(fireflySection, "Show Cooldown Bind Button", fireflyShowBindButton, function(state)
    fireflyShowBindButton = state
    SetCfg("fireflyShowBindButton", state)
    syncFireflyBindButton()
end)

fireflySection:AddSlider("Clutch Countdown", 1.5, 4.0, fireflyCountdownDuration, function(value)
    fireflyCountdownDuration = value
    SetCfg("fireflyCountdownDuration", value)
end)

fireflySection:AddSlider("Cooldown Time", 10, 20, fireflyCooldownDuration, function(value)
    fireflyCooldownDuration = value
    SetCfg("fireflyCooldownDuration", value)
end)

fireflySection:AddSlider("Auto Clutch Trigger", 0.05, 0.50, fireflyTriggerPoint, function(value)
    fireflyTriggerPoint = value
    SetCfg("fireflyTriggerPoint", value)
end)

fireflySection:AddSlider("Jump Burst Duration", 0.10, 1.00, fireflyBurstDuration, function(value)
    fireflyBurstDuration = value
    SetCfg("fireflyBurstDuration", value)
end)

fireflySection:AddSlider("Firefly UI Size", 50, 160, fireflyUISize, function(value)
    fireflyUISize = value
    SetCfg("fireflyUISize", value)
    applyFireflyUISize()
end)

addToggle(fireflySection, "Lock Firefly Bind POS", fireflyLockBindPos, function(state)
    fireflyLockBindPos = state
    SetCfg("fireflyLockBindPos", state)
    BindableButtons:SetLocked(FIREFLY_BIND_ID, state)
end)

fireflySection:AddButton("Reset Firefly Bind Position", function()
    BindableButtons:SetPosition(FIREFLY_BIND_ID, FIREFLY_BIND_DEFAULT)
    saveStoredPosition("fireflyBindButtonPosition", FIREFLY_BIND_DEFAULT)
    shared.Notify("Firefly cooldown button position reset.", 2)
end)

task.defer(function()
    buildFireflyTimer()
    syncFireflyBindButton()
    if fireflyEnabled then hookFireflyTool() else BindableButtons:SetVisible(FIREFLY_BIND_ID, false) end
end)


end)()

-- =========================================================
-- VISUALS: GUNS & KNIVES
-- Integrated from the G&K module so it stays in Visuals V2.
-- =========================================================

;(function()
local gunsVisualSection = mainTab:AddSection("Guns & Knives", "Visuals")
local gunsVisualEnabled = C("gunsVisualEnabled", false)
local gunsTintMode = C("gunsTintMode", "Tool Color")
local gunsTintColor = C("gunsTintColor", Color3.fromRGB(255, 0, 0))
local gunsRainbow = C("gunsRainbow", false)
local gunsRainbowSpeed = C("gunsRainbowSpeed", 3)

local gunsRainbowConnection
local gunsCurrentRainbowTool
local gunsSeen = setmetatable({}, {__mode = "k"})
local gunsOriginals = setmetatable({}, {__mode = "k"})
local GUNS_HIGHLIGHT_NAME = "_visualsv2_gk_highlight"

local function snapshotGunObject(obj)
    if gunsOriginals[obj] then return end
    local snap = {}
    pcall(function()
        if obj:IsA("BasePart") then snap.Color = obj.Color end
        if obj:IsA("DataModelMesh") then snap.VertexColor = obj.VertexColor end
        if obj:IsA("Decal") or obj:IsA("Texture") then snap.Color3 = obj.Color3 end
        if obj:IsA("SurfaceAppearance") then snap.SurfaceColor = obj.Color end
        if obj:IsA("Beam") or obj:IsA("Trail") or obj:IsA("ParticleEmitter") then snap.Sequence = obj.Color end
    end)
    if next(snap) then gunsOriginals[obj] = snap end
end

local function restoreGunObject(obj)
    local snap = gunsOriginals[obj]
    if not snap or not obj or not obj.Parent then return end
    pcall(function()
        if snap.Color then obj.Color = snap.Color end
        if snap.VertexColor then obj.VertexColor = snap.VertexColor end
        if snap.Color3 then obj.Color3 = snap.Color3 end
        if snap.SurfaceColor then obj.Color = snap.SurfaceColor end
        if snap.Sequence then obj.Color = snap.Sequence end
    end)
end

local function setGunObjectColor(obj, color)
    snapshotGunObject(obj)
    pcall(function()
        if obj:IsA("BasePart") then
            obj.Color = color
        elseif obj:IsA("DataModelMesh") then
            obj.VertexColor = Vector3.new(color.R, color.G, color.B)
        elseif obj:IsA("Decal") or obj:IsA("Texture") then
            obj.Color3 = color
        elseif obj:IsA("SurfaceAppearance") then
            obj.Color = color
        elseif obj:IsA("Beam") or obj:IsA("Trail") or obj:IsA("ParticleEmitter") then
            obj.Color = ColorSequence.new(color)
        end
    end)
end

local function removeGunHighlights(tool)
    if not tool then return end
    for _, obj in ipairs(tool:GetDescendants()) do
        if obj:IsA("Highlight") and obj.Name == GUNS_HIGHLIGHT_NAME then obj:Destroy() end
    end
end

local function applyGunHighlight(tool, color)
    removeGunHighlights(tool)
    for _, obj in ipairs(tool:GetDescendants()) do
        if obj:IsA("BasePart") then
            local highlight = Instance.new("Highlight")
            highlight.Name = GUNS_HIGHLIGHT_NAME
            highlight.FillColor = color
            highlight.FillTransparency = 0.5
            highlight.OutlineTransparency = 1
            highlight.DepthMode = Enum.HighlightDepthMode.Occluded
            highlight.Parent = obj
        end
    end
end

local function restoreGunTool(tool)
    if not tool then return end
    removeGunHighlights(tool)
    for _, obj in ipairs(tool:GetDescendants()) do restoreGunObject(obj) end
end

local function tintGunTool(tool, color)
    if not tool then return end
    removeGunHighlights(tool)
    for _, obj in ipairs(tool:GetDescendants()) do setGunObjectColor(obj, color) end
end

local function getCurrentVisualTool()
    local character = player.Character
    local equipped = character and character:FindFirstChildOfClass("Tool")
    if equipped then return equipped end
    local backpack = player:FindFirstChildOfClass("Backpack")
    return backpack and backpack:FindFirstChildOfClass("Tool") or nil
end

local function currentGunRainbowColor()
    return Color3.fromHSV((os.clock() * (gunsRainbowSpeed * 0.1)) % 1, 1, 1)
end

local function applyGunVisual(tool)
    if not gunsVisualEnabled or not tool then return end
    local color = gunsRainbow and currentGunRainbowColor() or gunsTintColor
    if gunsTintMode == "Highlight" then
        applyGunHighlight(tool, color)
    else
        tintGunTool(tool, color)
    end
end

local function stopGunRainbow()
    if gunsRainbowConnection then gunsRainbowConnection:Disconnect() end
    gunsRainbowConnection = nil
    gunsCurrentRainbowTool = nil
end

local function updateGunRainbow()
    stopGunRainbow()
    if not gunsVisualEnabled or not gunsRainbow then return end
    gunsRainbowConnection = RunService.RenderStepped:Connect(function()
        local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
        if not tool then return end
        gunsCurrentRainbowTool = tool
        applyGunVisual(tool)
    end)
end

local function bindGunVisualTool(tool)
    if not tool or gunsSeen[tool] then return end
    gunsSeen[tool] = true
    tool.DescendantAdded:Connect(function(obj)
        if gunsVisualEnabled then task.defer(function() applyGunVisual(tool) end) end
    end)
    tool.Equipped:Connect(function()
        if gunsVisualEnabled then applyGunVisual(tool) end
        updateGunRainbow()
    end)
    tool.Unequipped:Connect(updateGunRainbow)
end

local function watchGunVisualContainer(container)
    if not container then return end
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("Tool") then bindGunVisualTool(child) end
    end
    container.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            bindGunVisualTool(child)
            if gunsVisualEnabled then task.defer(function() applyGunVisual(child) end) end
        end
    end)
end

local function applyAllGunVisuals()
    local character = player.Character
    local backpack = player:FindFirstChildOfClass("Backpack")
    for _, container in ipairs({character, backpack}) do
        if container then
            for _, child in ipairs(container:GetChildren()) do
                if child:IsA("Tool") then applyGunVisual(child) end
            end
        end
    end
    updateGunRainbow()
end

local function restoreAllGunVisuals()
    stopGunRainbow()
    for obj in pairs(gunsOriginals) do restoreGunObject(obj) end
    local character = player.Character
    local backpack = player:FindFirstChildOfClass("Backpack")
    for _, container in ipairs({character, backpack}) do
        if container then
            for _, child in ipairs(container:GetChildren()) do
                if child:IsA("Tool") then removeGunHighlights(child) end
            end
        end
    end
end

watchGunVisualContainer(player:FindFirstChildOfClass("Backpack"))
watchGunVisualContainer(player.Character)
player.CharacterAdded:Connect(function(character)
    watchGunVisualContainer(character)
    task.defer(function()
        if gunsVisualEnabled then applyAllGunVisuals() end
    end)
end)

addToggle(gunsVisualSection, "Enable Guns & Knives Visuals", gunsVisualEnabled, function(state)
    gunsVisualEnabled = state
    SetCfg("gunsVisualEnabled", state)
    if state then applyAllGunVisuals() else restoreAllGunVisuals() end
end)

addDropdown(gunsVisualSection, "Tint Mode", {"Tool Color", "Highlight"}, gunsTintMode, function(value)
    gunsTintMode = value
    SetCfg("gunsTintMode", value)
    if gunsVisualEnabled then applyAllGunVisuals() end
end)

gunsVisualSection:AddColorpicker("Tool Color", gunsTintColor, function(color)
    gunsTintColor = color
    SetCfg("gunsTintColor", color)
    if gunsVisualEnabled and not gunsRainbow then applyAllGunVisuals() end
end)

addToggle(gunsVisualSection, "Rainbow", gunsRainbow, function(state)
    gunsRainbow = state
    SetCfg("gunsRainbow", state)
    if gunsVisualEnabled then applyAllGunVisuals() end
end)

gunsVisualSection:AddSlider("Rainbow Speed", 1, 10, gunsRainbowSpeed, function(value)
    gunsRainbowSpeed = value
    SetCfg("gunsRainbowSpeed", value)
end)

end)()

-- =========================================================
-- UTILITIES: GUN+
-- Integrated from the supplied Gun+ loader/source.
-- =========================================================

;(function()
local gunPlusSection = mainTab:AddSection("Gun+", "Utilities")
local gunPlusBlockAnimations = C("gunPlusBlockAnimations", false)
local gunPlusEquipSound = C("gunPlusEquipSound", false)
local gunPlusAnimationCooldown = C("gunPlusAnimationCooldown", 5)
local gunPlusSoundVolume = C("gunPlusSoundVolume", 1)
local gunPlusSoundOffset = C("gunPlusSoundOffset", 0)
local GUN_PLUS_SOUND_ID = "rbxassetid://6968135315"

local gunPlusConnections = {}
local gunPlusCharacterConnections = {}
local gunPlusSounds = {}
local gunPlusLastUnequipped = 0
local gunPlusIsEquipped = false

local function clearConnectionList(list)
    for _, connection in ipairs(list) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(list)
end

local function clearGunPlusSounds()
    for sound in pairs(gunPlusSounds) do
        pcall(function()
            sound:Stop()
            sound:Destroy()
        end)
    end
    table.clear(gunPlusSounds)
end

local function playGunPlusSound(character)
    if not gunPlusEquipSound then return end
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local sound = Instance.new("Sound")
    sound.SoundId = GUN_PLUS_SOUND_ID
    sound.Volume = gunPlusSoundVolume
    sound.Parent = hrp
    pcall(function() sound.TimePosition = math.max(0, gunPlusSoundOffset) end)
    gunPlusSounds[sound] = true
    sound.Ended:Connect(function()
        gunPlusSounds[sound] = nil
        if sound.Parent then sound:Destroy() end
    end)
    sound:Play()
end

local function setupGunPlusCharacter(character)
    clearConnectionList(gunPlusCharacterConnections)
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
    local animator = humanoid and (humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator", 10))
    if not humanoid or not animator then return end

    local current = character:FindFirstChild("Gun")
    gunPlusIsEquipped = current and current:IsA("Tool") or false

    table.insert(gunPlusCharacterConnections, character.ChildAdded:Connect(function(child)
        if child:IsA("Tool") and child.Name == "Gun" then
            gunPlusIsEquipped = true
            task.wait(0.05)
            playGunPlusSound(character)
        end
    end))

    table.insert(gunPlusCharacterConnections, character.ChildRemoved:Connect(function(child)
        if child:IsA("Tool") and child.Name == "Gun" then
            gunPlusIsEquipped = false
            gunPlusLastUnequipped = os.clock()
            task.wait(0.05)
            playGunPlusSound(character)
        end
    end))

    table.insert(gunPlusCharacterConnections, animator.AnimationPlayed:Connect(function(track)
        if not gunPlusBlockAnimations then return end
        local withinCooldown = (os.clock() - gunPlusLastUnequipped) <= gunPlusAnimationCooldown
        if (gunPlusIsEquipped or withinCooldown) and track.Priority == Enum.AnimationPriority.Action then
            track:Stop()
        end
    end))
end

local function refreshGunPlus()
    clearConnectionList(gunPlusConnections)
    clearConnectionList(gunPlusCharacterConnections)
    clearGunPlusSounds()
    gunPlusLastUnequipped = 0
    gunPlusIsEquipped = false

    if not gunPlusBlockAnimations and not gunPlusEquipSound then return end
    if player.Character then setupGunPlusCharacter(player.Character) end
    table.insert(gunPlusConnections, player.CharacterAdded:Connect(function(character)
        task.defer(function() setupGunPlusCharacter(character) end)
    end))
end

addToggle(gunPlusSection, "Disable Gun Animations", gunPlusBlockAnimations, function(state)
    gunPlusBlockAnimations = state
    SetCfg("gunPlusBlockAnimations", state)
    refreshGunPlus()
end)

addToggle(gunPlusSection, "Enable Un/Equip Sounds", gunPlusEquipSound, function(state)
    gunPlusEquipSound = state
    SetCfg("gunPlusEquipSound", state)
    refreshGunPlus()
end)

gunPlusSection:AddSlider("Animation Block Cooldown", 0, 10, gunPlusAnimationCooldown, function(value)
    gunPlusAnimationCooldown = value
    SetCfg("gunPlusAnimationCooldown", value)
end)

gunPlusSection:AddSlider("Gun Sound Volume", 0, 2, gunPlusSoundVolume, function(value)
    gunPlusSoundVolume = value
    SetCfg("gunPlusSoundVolume", value)
end)

gunPlusSection:AddSlider("Gun Sound Start Offset", 0, 5, gunPlusSoundOffset, function(value)
    gunPlusSoundOffset = value
    SetCfg("gunPlusSoundOffset", value)
end)

task.defer(function()
    if gunPlusBlockAnimations or gunPlusEquipSound then refreshGunPlus() end
end)

end)()

-- =========================================================
-- SCREEN
-- =========================================================

;(function()
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

end)()

-- =========================================================
-- WORLD
-- =========================================================

;(function()
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

end)()

-- =========================================================
-- MISCELLANEOUS
-- =========================================================

;(function()
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

end)()

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
