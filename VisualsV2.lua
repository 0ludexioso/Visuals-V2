-- Visuals V2
-- COMPLETE WEAPON RESTORE: latest fixes + Shoot Murderer + Guns & Knives + Gun+
-- COMPLETE BUILD: requested add-ons + accumulated fixes
-- Native Overdrive H addon

local shared = odh_shared_plugins

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TextChatService = game:GetService("TextChatService")

local mainTab = shared.CreateTab(
    "Visuals V2",
    "/0ludexioso/VisualsV2/refs/heads/main/icon"
)

-- Durable add-on settings.
-- writefile()/readfile() are rooted at the executor workspace, so this appears as:
-- ixry shizuka/plugins/workspace/VisualsV2_settings.json
-- It is intentionally separate from ODH's mm2.json.
local CFG_FILE = "VisualsV2_settings.json"
local ConfigData = {}
local PositionData = {}
local configResetting = false

local env = {}
if type(getgenv) == "function" then
    local ok, result = pcall(getgenv)
    if ok and type(result) == "table" then env = result end
end

local read = type(readfile) == "function" and readfile or env.readfile
local write = type(writefile) == "function" and writefile or env.writefile
local exists = type(isfile) == "function" and isfile or env.isfile

local function isPositionKey(key)
    return type(key) == "string" and key:lower():find("position", 1, true) ~= nil
end

local function encodeConfigValue(value)
    if typeof(value) == "Color3" then
        return {color3 = {value.R, value.G, value.B}}
    end
    return value
end

local function decodeConfigValue(value, default)
    if typeof(default) == "Color3" and type(value) == "table" then
        local color = value.color3 or value
        if type(color) == "table" and #color >= 3 then
            local r, g, b = tonumber(color[1]), tonumber(color[2]), tonumber(color[3])
            if r and g and b then
                -- New config stores 0..1 Color3 channels. Old builds stored 0..255.
                if r > 1 or g > 1 or b > 1 then
                    return Color3.fromRGB(r, g, b)
                end
                return Color3.new(r, g, b)
            end
        end
    end
    return value
end

local function loadConfig()
    if type(read) ~= "function" then return end

    local found = true
    if type(exists) == "function" then
        local ok, result = pcall(exists, CFG_FILE)
        found = ok and result
    end
    if not found then return end

    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(read(CFG_FILE))
    end)
    if not ok or type(decoded) ~= "table" then return end

    -- Only load this add-on's standalone schema. Old flat settings are intentionally
    -- not imported so a fresh install starts with every feature disabled.
    if type(decoded.settings) == "table" then
        ConfigData = decoded.settings
    end
    if type(decoded.positions) == "table" then
        PositionData = decoded.positions
    end
end

local function saveConfig()
    if type(write) ~= "function" then return false end
    local payload = {
        version = 2,
        settings = ConfigData,
        positions = PositionData,
    }
    return pcall(function()
        write(CFG_FILE, HttpService:JSONEncode(payload))
    end)
end

local function C(key, default)
    local source = isPositionKey(key) and PositionData or ConfigData
    local value = source[key]
    if value == nil then
        if default ~= nil then
            source[key] = encodeConfigValue(default)
        end
        return default
    end
    return decodeConfigValue(value, default)
end

local function SetCfg(key, value)
    if configResetting then return end
    local target = isPositionKey(key) and PositionData or ConfigData
    if value == nil then
        target[key] = nil
    else
        target[key] = encodeConfigValue(value)
    end
    saveConfig()
end

local function addToggle(section, name, defaultValue, callback)
    local state = false
    local rawToggle

    rawToggle = section:AddToggle(name, function(newState)
        state = not not newState
        callback(state)
    end)

    local controller = {}
    function controller:Set(newState)
        newState = not not newState
        if newState == state then return end

        -- ODH toggles expose a closure rather than Set(value). Try twice so a
        -- retained UI state from a previous execution cannot invert persistence.
        pcall(rawToggle)
        if state ~= newState then pcall(rawToggle) end
        if state ~= newState then
            state = newState
            callback(newState)
        end
    end
    function controller:Get()
        return state
    end

    if defaultValue then
        task.defer(function()
            controller:Set(true)
        end)
    end
    return controller
end

local function addDropdown(section, name, items, defaultValue, callback)
    local controller = section:AddDropdown(name, items, callback)
    if defaultValue then
        task.defer(function()
            local selected = false
            if controller and type(controller.Select)=="function" then
                selected = pcall(controller.Select, defaultValue)
                if not selected then
                    selected = pcall(function() controller:Select(defaultValue) end)
                end
            end
            -- Always apply the persisted value functionally even if this ODH
            -- build does not expose a working dropdown Select setter.
            callback(defaultValue)
        end)
    end
    return controller
end

loadConfig()

-- Clean up a previous execution of this build without changing its saved config.
-- This prevents old UI/effect connections from stacking when the addon is re-executed.
local previousRuntime = env.VisualsV2Runtime
if type(previousRuntime) == "table" and type(previousRuntime.Cleanup) == "function" then
    pcall(previousRuntime.Cleanup)
end

-- Runtime reset registry.
env.VisualsV2Runtime = {Resetters = {}}
env.VisualsV2Runtime.RegisterReset = function(callback)
    if type(callback) == "function" then table.insert(env.VisualsV2Runtime.Resetters, callback) end
end
env.VisualsV2Runtime.Cleanup = function()
    configResetting = true
    for _, resetter in ipairs(env.VisualsV2Runtime.Resetters or {}) do pcall(resetter) end
    configResetting = false
end

-- Settings are already written immediately by SetCfg. These hooks add one
-- final best-effort save when teleporting/leaving so executor workspaces keep
-- the same config between servers and future executions.
pcall(function()
    LocalPlayer.OnTeleport:Connect(function()
        saveConfig()
    end)
end)
pcall(function()
    game:BindToClose(function()
        saveConfig()
    end)
end)

local player = LocalPlayer
local camera = workspace.CurrentCamera

-- =========================================================
-- COSMETIC: CHINESE HAT
-- =========================================================

;(function()
    local hatSection = mainTab:AddSection("Chinese Hat", "Cosmetic")

    local hatEnabled = C("hatEnabled", false)
    local legacyHatTransparency = tonumber(ConfigData["hatTransparency"])
    local hatTransparency = tonumber(C("hatTransparencyLevel", nil))
    if hatTransparency == nil then
        if legacyHatTransparency ~= nil then
            hatTransparency = math.clamp(math.floor((legacyHatTransparency * 4) + 1.5), 1, 5)
        else
            hatTransparency = 2
        end
    end
    hatTransparency = math.clamp(math.floor(hatTransparency + 0.5), 1, 5)
    local hatRainbow = C("hatRainbow", false)
    local hatDualColor = C("hatDualColor", false)
    local hatColor = C("hatColor", Color3.fromRGB(255, 255, 255))
    local hatColor1 = C("hatColor1", Color3.fromRGB(255, 255, 255))
    local hatColor2 = C("hatColor2", Color3.fromRGB(0, 0, 0))
    local hatSize = math.clamp(tonumber(C("hatSize", 1)) or 1, 1, 3)
    local hatHeight = C("hatHeight", 1.1)

    local hatPart = nil
    local hatConnection = nil
    local characterConnection = nil

    local function removeHat()
        if hatPart then
            pcall(function()
                hatPart:Destroy()
            end)
            hatPart = nil
        end

        local char = player.Character
        if char then
            local existing = char:FindFirstChild("VisualsV2_ChineseHat")
            if existing then
                existing:Destroy()
            end
        end
    end

    local function currentHatColor()
        if hatDualColor then
            local t = (math.sin(tick() * 2) + 1) / 2
            return hatColor1:Lerp(hatColor2, t)
        elseif hatRainbow then
            return Color3.fromHSV((tick() % 5) / 5, 1, 1)
        end
        return hatColor
    end

    local function updateHat()
        if not hatPart or not hatPart.Parent then return end

        hatPart.Transparency = ((math.clamp(tonumber(hatTransparency) or 2, 1, 5) - 1) / 4) * 0.8
        hatPart.Color = currentHatColor()

        local mesh = hatPart:FindFirstChildOfClass("SpecialMesh")
        if mesh then
            mesh.Scale = Vector3.new(
                2.4 * (tonumber(hatSize) or 1),
                1.6 * (tonumber(hatSize) or 1),
                2.4 * (tonumber(hatSize) or 1)
            )
        end

        local char = player.Character
        local head = char and char:FindFirstChild("Head")
        if head then
            hatPart.CFrame = head.CFrame * CFrame.new(0, tonumber(hatHeight) or 1.1, 0)
        end
    end

    local function addHat(char)
        if not hatEnabled or not char then return end

        local head = char:FindFirstChild("Head") or char:WaitForChild("Head", 5)
        if not head then return end

        removeHat()

        local hat = Instance.new("Part")
        hat.Name = "VisualsV2_ChineseHat"
        hat.Size = Vector3.new(1, 1, 1)
        hat.Transparency = ((math.clamp(tonumber(hatTransparency) or 2, 1, 5) - 1) / 4) * 0.8
        hat.Color = currentHatColor()
        hat.Material = Enum.Material.Neon
        hat.Anchored = false
        hat.CanCollide = false
        hat.CanTouch = false
        hat.CanQuery = false
        hat.CastShadow = false
        hat.Massless = true
        hat.CFrame = head.CFrame * CFrame.new(0, tonumber(hatHeight) or 1.1, 0)
        hat.Parent = char

        local mesh = Instance.new("SpecialMesh")
        mesh.MeshId = "rbxassetid://1033714"
        mesh.Scale = Vector3.new(
            2.4 * (tonumber(hatSize) or 1),
            1.6 * (tonumber(hatSize) or 1),
            2.4 * (tonumber(hatSize) or 1)
        )
        mesh.Parent = hat

        local weld = Instance.new("WeldConstraint")
        weld.Name = "VisualsV2_ChineseHatWeld"
        weld.Part0 = head
        weld.Part1 = hat
        weld.Parent = hat

        hatPart = hat
        updateHat()
    end

    local function refreshHatConnection()
        if hatConnection then
            hatConnection:Disconnect()
            hatConnection = nil
        end

        if hatEnabled then
            hatConnection = RunService.Heartbeat:Connect(function()
                if hatEnabled then
                    updateHat()
                end
            end)
        end
    end

    local enableToggle = addToggle(hatSection, "Enable Chinese Hat", hatEnabled, function(state)
        hatEnabled = state
        SetCfg("hatEnabled", state)

        if state then
            addHat(player.Character)
        else
            removeHat()
        end

        refreshHatConnection()
    end)

    local rainbowToggle = addToggle(hatSection, "Rainbow Hat", hatRainbow, function(state)
        hatRainbow = state
        SetCfg("hatRainbow", state)
        updateHat()
    end)

    local dualColorToggle = addToggle(hatSection, "Dual Color Hat", hatDualColor, function(state)
        hatDualColor = state
        SetCfg("hatDualColor", state)
        updateHat()
    end)

    hatSection:AddSlider("Transparency", 1, 5, hatTransparency, function(value)
        hatTransparency = math.clamp(math.floor((tonumber(value) or 2) + 0.5), 1, 5)
        SetCfg("hatTransparencyLevel", hatTransparency)
        updateHat()
    end)

    hatSection:AddColorpicker("Base Color", hatColor, function(color)
        hatColor = color
        SetCfg("hatColor", color)
        updateHat()
    end)

    hatSection:AddColorpicker("Color 1", hatColor1, function(color)
        hatColor1 = color
        SetCfg("hatColor1", color)
        updateHat()
    end)

    hatSection:AddColorpicker("Color 2", hatColor2, function(color)
        hatColor2 = color
        SetCfg("hatColor2", color)
        updateHat()
    end)

    hatSection:AddSlider("Hat Size", 1, 3, hatSize, function(value)
        hatSize = tonumber(value) or 1
        SetCfg("hatSize", hatSize)
        if hatEnabled then
            addHat(player.Character)
        end
    end)

    hatSection:AddSlider("Hat Height", 0.5, 3, hatHeight, function(value)
        hatHeight = tonumber(value) or 1.1
        SetCfg("hatHeight", hatHeight)
        if hatEnabled then
            addHat(player.Character)
        end
    end)

    characterConnection = player.CharacterAdded:Connect(function(char)
        if not hatEnabled then return end
        task.wait(1)
        if hatEnabled then
            addHat(char)
            refreshHatConnection()
        end
    end)

    env.VisualsV2Runtime.RegisterReset(function()
        enableToggle:Set(false)
        rainbowToggle:Set(false)
        dualColorToggle:Set(false)

        hatEnabled = false
        hatRainbow = false
        hatDualColor = false
        hatTransparency = 2
        hatColor = Color3.fromRGB(255, 255, 255)
        hatColor1 = Color3.fromRGB(255, 255, 255)
        hatColor2 = Color3.fromRGB(0, 0, 0)
        hatSize = 1
        hatHeight = 1.1

        if hatConnection then
            hatConnection:Disconnect()
            hatConnection = nil
        end

        removeHat()
    end)

    if hatEnabled and player.Character then
        task.defer(function()
            task.wait(0.5)
            if hatEnabled then
                addHat(player.Character)
                refreshHatConnection()
            end
        end)
    end
end)()

-- =========================================================
-- COSMETIC: TRAIL
-- =========================================================

local trailSection = mainTab:AddSection("Trail", "Cosmetic")
local trailEnabled = C("trailEnabled", false)
local trailIsGradient = C("trailIsGradient", false)
local trailRainbow = C("trailRainbow", false)
local trailColorStatic = C("trailColorStatic", Color3.fromRGB(255, 255, 255))
local trailGradient1 = C("trailGradient1", Color3.fromRGB(255, 255, 255))
local trailGradient2 = C("trailGradient2", Color3.fromRGB(0, 0, 0))
local trailLifetime = math.max(0.2, tonumber(C("trailLifetime", 0.5)) or 0.5)
local trailTransparencyStart = math.clamp(tonumber(C("trailTransparency", 1)) or 1, 1, 4)
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

local function trailAlpha(value)
    value = math.clamp(tonumber(value) or 1, 1, 4)
    -- Never reaches 1, so the transparency slider cannot disable the feature.
    return 0.05 + ((value - 1) / 3) * 0.75
end

local function updateTrail()
    if not trailObject then return end
    trailObject.Lifetime = math.max(0.2, tonumber(trailLifetime) or 0.5)
    trailObject.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, trailAlpha(trailTransparencyStart)),
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

local trailEnableToggle = addToggle(trailSection, "Enable Trail", trailEnabled, function(state)
    trailEnabled = state
    SetCfg("trailEnabled", state)
    if state then
        createTrail()
        if trailConnection then trailConnection:Disconnect() end
        trailConnection = RunService.Heartbeat:Connect(function()
            if trailRainbow and trailEnabled then updateTrail() end
        end)
    else
        if trailConnection then trailConnection:Disconnect(); trailConnection = nil end
        removeTrail()
    end
end)

local trailGradientToggle = addToggle(trailSection, "Use Gradient Mode", trailIsGradient, function(state)
    trailIsGradient = state
    SetCfg("trailIsGradient", state)
    updateTrail()
end)

local trailRainbowToggle = addToggle(trailSection, "Rainbow", trailRainbow, function(state)
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
trailSection:AddSlider("Trail Lifetime", 0.2, 3, trailLifetime, function(value)
    trailLifetime = math.max(0.2, tonumber(value) or 0.5)
    SetCfg("trailLifetime", trailLifetime)
    updateTrail()
end)
trailSection:AddSlider("Trail Transparency", 1, 4, trailTransparencyStart, function(value)
    trailTransparencyStart = math.clamp(math.floor((tonumber(value) or 1) + 0.5), 1, 4)
    SetCfg("trailTransparency", trailTransparencyStart)
    updateTrail()
end)

env.VisualsV2Runtime.RegisterReset(function()
    trailEnableToggle:Set(false)
    trailGradientToggle:Set(false)
    trailRainbowToggle:Set(false)
    trailEnabled = false
    trailIsGradient = false
    trailRainbow = false
    trailLifetime = 0.5
    trailTransparencyStart = 1
    trailColorStatic = Color3.fromRGB(255,255,255)
    trailGradient1 = Color3.fromRGB(255,255,255)
    trailGradient2 = Color3.fromRGB(0,0,0)
    if trailConnection then trailConnection:Disconnect(); trailConnection = nil end
    removeTrail()
end)

-- =========================================================
-- COSMETIC: SKIN
-- =========================================================
-- COSMETIC: SKIN
-- =========================================================

local skinSection = mainTab:AddSection("Skin", "Cosmetic")
local ffEnabled = C("ffEnabled", false)
local ffRainbow = C("ffRainbow", false)
local ffColor = C("ffColor", Color3.fromRGB(255, 255, 255))
local skinTrailEnabled = C("skinTrailEnabled", false)
local skinTrailRainbow = C("skinTrailRainbow", false)
local skinTrailColor = C("skinTrailColor", Color3.fromRGB(255, 255, 255))
local skinTrailLife = math.max(0.2, tonumber(C("skinTrailLife", 0.5)) or 0.5)
local skinTrailTransparency = math.clamp(tonumber(C("skinTrailTransparency", 0.0)) or 0, 0, 3)
local ffConnection = nil
local skinTrailRainbowConnection = nil

local FF_MATERIAL_ATTR = "VisualsV2_OriginalMaterial"
local FF_COLOR_ATTR = "VisualsV2_OriginalColor"

local function rememberForceFieldPart(part)
    if not part:IsA("BasePart") then return end
    if part:GetAttribute(FF_MATERIAL_ATTR) == nil then
        part:SetAttribute(FF_MATERIAL_ATTR, part.Material.Name)
    end
    if part:GetAttribute(FF_COLOR_ATTR) == nil then
        part:SetAttribute(FF_COLOR_ATTR, part.Color)
    end
end

local function restoreForceFieldPart(part)
    if not part:IsA("BasePart") then return end
    local materialName = part:GetAttribute(FF_MATERIAL_ATTR)
    local oldColor = part:GetAttribute(FF_COLOR_ATTR)
    if materialName then
        local ok, material = pcall(function()
            return Enum.Material[materialName]
        end)
        if ok and material then part.Material = material end
    end
    if typeof(oldColor) == "Color3" then part.Color = oldColor end
    part:SetAttribute(FF_MATERIAL_ATTR, nil)
    part:SetAttribute(FF_COLOR_ATTR, nil)
end

local function applyForceField()
    local char = player.Character
    if not char then return end
    local color = ffRainbow and Color3.fromHSV((os.clock() % 5) / 5, 1, 1) or ffColor
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            rememberForceFieldPart(part)
            part.Material = Enum.Material.ForceField
            part.Color = color
        end
    end
end

local function removeForceField()
    if ffConnection then
        ffConnection:Disconnect()
        ffConnection = nil
    end
    local char = player.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then restoreForceFieldPart(part) end
    end
end

local function refreshForceFieldConnection()
    if ffConnection then
        ffConnection:Disconnect()
        ffConnection = nil
    end
    if ffEnabled and ffRainbow then
        ffConnection = RunService.Heartbeat:Connect(applyForceField)
    end
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
    return skinTrailRainbow and Color3.fromHSV((os.clock() % 5) / 5, 1, 1) or skinTrailColor
end

local function currentSkinTrailTransparency()
    return math.clamp((tonumber(skinTrailTransparency) or 0) / 4, 0, 0.75)
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
        skinTrailRainbowConnection = RunService.Heartbeat:Connect(updateSkinTrail)
    end
end

local forceFieldToggle = addToggle(skinSection, "Enable ForceField", ffEnabled, function(state)
    ffEnabled = state
    SetCfg("ffEnabled", state)
    if state then
        applyForceField()
        refreshForceFieldConnection()
    else
        removeForceField()
    end
end)

local rainbowForceFieldToggle = addToggle(skinSection, "Rainbow ForceField", ffRainbow, function(state)
    ffRainbow = state
    SetCfg("ffRainbow", state)
    if ffEnabled then
        applyForceField()
        refreshForceFieldConnection()
    end
end)

skinSection:AddColorpicker("ForceField Color", ffColor, function(color)
    ffColor = color
    SetCfg("ffColor", color)
    if ffEnabled and not ffRainbow then applyForceField() end
end)

local skinTrailToggle = addToggle(skinSection, "Enable Skin Trail", skinTrailEnabled, function(state)
    skinTrailEnabled = state
    SetCfg("skinTrailEnabled", state)
    if state then applySkinTrail() else clearSkinTrail() end
    refreshSkinTrailRainbowConnection()
end)

local rainbowSkinTrailToggle = addToggle(skinSection, "Rainbow Skin Trail", skinTrailRainbow, function(state)
    skinTrailRainbow = state
    SetCfg("skinTrailRainbow", state)
    if skinTrailEnabled then updateSkinTrail() end
    refreshSkinTrailRainbowConnection()
end)

skinSection:AddColorpicker("Skin Trail Color", skinTrailColor, function(color)
    skinTrailColor = color
    SetCfg("skinTrailColor", color)
    if skinTrailEnabled and not skinTrailRainbow then updateSkinTrail() end
end)

skinSection:AddSlider("Skin Trail Lifetime", 0.2, 3.0, skinTrailLife, function(value)
    skinTrailLife = math.max(0.2, tonumber(value) or 0.5)
    SetCfg("skinTrailLife", skinTrailLife)
    if skinTrailEnabled then updateSkinTrail() end
end)

skinSection:AddSlider("Skin Transparency", 0.0, 3.0, skinTrailTransparency, function(value)
    skinTrailTransparency = value
    SetCfg("skinTrailTransparency", value)
    if skinTrailEnabled then updateSkinTrail() end
end)

env.VisualsV2Runtime.RegisterReset(function()
    forceFieldToggle:Set(false)
    rainbowForceFieldToggle:Set(false)
    skinTrailToggle:Set(false)
    rainbowSkinTrailToggle:Set(false)
    removeForceField()
    clearSkinTrail()
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
    currentAuraModel = nil
    local id = AuraModels[auraType]
    if not id then return end
    local ok, model = pcall(function()
        return game:GetObjects(id)[1]
    end)
    if ok and model then currentAuraModel = model end
end

local function originalNexiumAuraClone(char)
    local tempModel = currentAuraModel:Clone()
    for _, obj in pairs(tempModel:GetDescendants()) do
        if not obj:IsA("BasePart") then
            local clone = obj:Clone()
            local parentName = obj.Parent and obj.Parent.Name
            local target = char:FindFirstChild(parentName) or char:FindFirstChildWhichIsA("BasePart")
            if target and not target:FindFirstChild(clone.Name) then
                clone.Parent = target
                table.insert(auraEffects, clone)
            end
        end
    end
    tempModel:Destroy()
end

local function visualEffectsOnlyAuraClone(char)
    local tempModel = currentAuraModel:Clone()

    -- Clone only visual effect roots attached to source body parts. This avoids
    -- importing humanoids, rig parts, scripts, wings, or frozen character models.
    for _, obj in ipairs(tempModel:GetDescendants()) do
        local parent = obj.Parent
        if parent and parent:IsA("BasePart") and not obj:IsA("BasePart") then
            local visual = obj:IsA("Attachment")
                or obj:IsA("ParticleEmitter")
                or obj:IsA("Beam")
                or obj:IsA("Trail")
                or obj:IsA("PointLight")
                or obj:IsA("SpotLight")
                or obj:IsA("SurfaceLight")
                or obj:IsA("Fire")
                or obj:IsA("Smoke")
                or obj:IsA("Sparkles")

            if auraType == "Angel Wing" and parent.Name:lower():find("wing", 1, true) then
                visual = false
            end

            if visual then
                local target = char:FindFirstChild(parent.Name) or char:FindFirstChild("HumanoidRootPart")
                if target and not target:FindFirstChild(obj.Name) then
                    local clone = obj:Clone()
                    clone.Parent = target
                    table.insert(auraEffects, clone)
                end
            end
        end
    end

    tempModel:Destroy()
end

local function applyAura()
    clearAura()
    local char = player.Character
    if not char then return end
    if not currentAuraModel then loadAuraModel() end
    if not currentAuraModel then return end

    -- Blue Lord and Pink Aura use the original Nexium cloning behavior exactly.
    -- Super Sayien keeps the same original Nexium behavior from the previous fix.
    if auraType == "Blue Lord" or auraType == "Pink Aura" or auraType == "Super Sayien" then
        originalNexiumAuraClone(char)
    else
        visualEffectsOnlyAuraClone(char)
    end
end

local auraToggle = addToggle(auraSection, "Enable Local Aura", auraEnabled, function(state)
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
    loadAuraModel()
    if auraEnabled then applyAura() end
end)

env.VisualsV2Runtime.RegisterReset(function()
    auraToggle:Set(false)
    clearAura()
end)

-- =========================================================

-- COSMETIC: JUMP CIRCLES
-- =========================================================

local jumpSection = mainTab:AddSection("Jump Circles", "Cosmetic")
local jumpCirclesEnabled = C("jumpCirclesEnabled", false)
local jumpCircleRainbow = C("jumpCircleRainbow", false)
local jumpCircleSize = C("jumpCircleSize", 5)
local jumpCircleTransparency = math.clamp(tonumber(C("jumpCircleTransparency", 1)) or 1, 0, 4)
local jumpCircleLifetime = math.max(0.2, tonumber(C("jumpCircleLifetime", 0.8)) or 0.8)
local jumpCircleColor = C("jumpCircleColor", Color3.fromRGB(255, 255, 255))

local function jumpAlpha(value)
    value = math.clamp(tonumber(value) or 1, 0, 4)
    return (value / 4) * 0.8
end

local function createJumpCircle(position)
    local ring = Instance.new("Part")
    ring.Name = "LV_JumpCircle"
    ring.Anchored = true
    ring.CanCollide = false
    ring.CanTouch = false
    ring.CanQuery = false
    ring.CastShadow = false
    ring.Material = Enum.Material.Neon
    ring.Transparency = jumpAlpha(jumpCircleTransparency)
    ring.Color = jumpCircleRainbow and Color3.fromHSV((tick() % 5) / 5, 1, 1) or jumpCircleColor
    ring.Size = Vector3.new(1, 1, 1)
    ring.CFrame = CFrame.new(position) * CFrame.Angles(math.rad(90), 0, 0)
    ring.Parent = workspace

    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.FileMesh
    mesh.MeshId = "rbxassetid://3270017"
    mesh.Scale = Vector3.new(jumpCircleSize, jumpCircleSize, 0.15)
    mesh.Parent = ring

    local life = math.max(0.2, tonumber(jumpCircleLifetime) or 0.8)
    TweenService:Create(mesh, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Scale = Vector3.new(jumpCircleSize + 4, jumpCircleSize + 4, 0.15),
    }):Play()
    TweenService:Create(ring, TweenInfo.new(life), {Transparency = 1}):Play()
    task.delay(life, function()
        if ring and ring.Parent then ring:Destroy() end
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

local jumpEnableToggle = addToggle(jumpSection, "Enable Jump Circles", jumpCirclesEnabled, function(state)
    jumpCirclesEnabled = state
    SetCfg("jumpCirclesEnabled", state)
end)
local jumpRainbowToggle = addToggle(jumpSection, "Rainbow", jumpCircleRainbow, function(state)
    jumpCircleRainbow = state
    SetCfg("jumpCircleRainbow", state)
end)
jumpSection:AddSlider("Circle Size", 2, 15, jumpCircleSize, function(value)
    jumpCircleSize = value
    SetCfg("jumpCircleSize", value)
end)
jumpSection:AddSlider("Transparency", 0, 4, jumpCircleTransparency, function(value)
    jumpCircleTransparency = math.clamp(tonumber(value) or 1, 0, 4)
    SetCfg("jumpCircleTransparency", jumpCircleTransparency)
end)
jumpSection:AddSlider("Lifetime", 0.2, 5, jumpCircleLifetime, function(value)
    jumpCircleLifetime = math.max(0.2, tonumber(value) or 0.8)
    SetCfg("jumpCircleLifetime", jumpCircleLifetime)
end)
jumpSection:AddColorpicker("Circle Color", jumpCircleColor, function(color)
    jumpCircleColor = color
    SetCfg("jumpCircleColor", color)
end)

env.VisualsV2Runtime.RegisterReset(function()
    jumpEnableToggle:Set(false)
    jumpRainbowToggle:Set(false)
    jumpCirclesEnabled = false
    jumpCircleRainbow = false
    jumpCircleSize = 5
    jumpCircleTransparency = 1
    jumpCircleLifetime = 0.8
    jumpCircleColor = Color3.fromRGB(255,255,255)
end)

-- =========================================================
-- COSMETIC: CHARACTER
-- =========================================================

local characterSection = mainTab:AddSection("Character", "Cosmetic")
local headlessEnabled = C("headlessEnabled", false)
local characterOriginal = setmetatable({}, {__mode = "k"})

characterSection:AddParagraph(
    "Character Appearance",
    "Headless is a local/client-sided appearance change. Other players will not see it"
)

local function rememberCharacterObject(obj)
    if not obj or characterOriginal[obj] then return end
    if obj:IsA("BasePart") then
        characterOriginal[obj] = {
            Transparency = obj.Transparency,
            LocalTransparencyModifier = obj.LocalTransparencyModifier,
        }
    elseif obj:IsA("Decal") then
        characterOriginal[obj] = {Transparency = obj.Transparency}
    end
end

local function restoreCharacterObject(obj)
    local data = characterOriginal[obj]
    if not obj or not data then return end
    if obj:IsA("BasePart") then
        pcall(function() obj.Transparency = data.Transparency end)
        pcall(function() obj.LocalTransparencyModifier = data.LocalTransparencyModifier end)
    elseif obj:IsA("Decal") then
        pcall(function() obj.Transparency = data.Transparency end)
    end
end

local function applyCharacterVisuals()
    local char = player.Character
    if not char then return end

    local head = char:FindFirstChild("Head")
    if head then
        rememberCharacterObject(head)
        if headlessEnabled then
            head.Transparency = 1
            head.LocalTransparencyModifier = 1
        else
            restoreCharacterObject(head)
        end

        for _, obj in ipairs(head:GetChildren()) do
            if obj:IsA("Decal") then
                rememberCharacterObject(obj)
                if headlessEnabled then
                    obj.Transparency = 1
                else
                    restoreCharacterObject(obj)
                end
            end
        end
    end
end

local headlessToggle = addToggle(characterSection, "Headless", headlessEnabled, function(state)
    headlessEnabled = state
    SetCfg("headlessEnabled", state)
    applyCharacterVisuals()
end)

env.VisualsV2Runtime.RegisterReset(function()
    headlessToggle:Set(false)
    headlessEnabled = false
    applyCharacterVisuals()
end)

-- =========================================================
-- UTILITIES: SPEED GLITCH
-- =========================================================

local speedSection = mainTab:AddSection("Speed Glitch", "Utilities")
local speedEnabled = C("speedGlitchEnabled", false)
local speedValue = C("speedValue", 50)
local speedButtonVisible = C("speedButtonVisible", false)
local speedButtonWidth = C("speedButtonWidth", 115)
local speedButtonHeight = C("speedButtonHeight", 45)
local speedButtonColor = C("speedButtonColor", Color3.fromRGB(0, 0, 0))
local speedButtonTransparency = C("speedButtonTransparency", 4)
if tonumber(speedButtonTransparency) and speedButtonTransparency < 1 then speedButtonTransparency = 1 + (speedButtonTransparency * 4) end
local speedBindButtonVisible = C("speedBindButtonVisible", false)
local speedBindButtonSize = math.clamp(tonumber(C("speedBindButtonSize", 5)) or 5, 1, 10)
local lockBigButtonPos = C("lockBigButtonPos", false)
local lockBindButtonPos = C("lockBindButtonPos", false)
local speedGui, speedButton, speedToggle
local BIG_BUTTON_DEFAULT = UDim2.new(0.5, -57, 0.22, 0)
local BIND_BUTTON_DEFAULT = UDim2.new(0.10, 0, 0.72, 0)


-- Migrate defaults written by older builds. Custom values are left alone.
if tonumber(ConfigData["speedButtonWidth"]) == 120 then speedButtonWidth = 115; ConfigData["speedButtonWidth"] = 115 end
if tonumber(ConfigData["speedButtonHeight"]) == 44 then speedButtonHeight = 45; ConfigData["speedButtonHeight"] = 45 end
if tonumber(ConfigData["speedButtonTransparency"]) == 3.6 then speedButtonTransparency = 4; ConfigData["speedButtonTransparency"] = 4 end
if tonumber(ConfigData["speedBindButtonSize"]) == 2 then speedBindButtonSize = 5; ConfigData["speedBindButtonSize"] = 5 end

local function loadStoredPosition(key, fallback)
    local data = C(key, nil)
    if type(data) ~= "table" then
        PositionData[key] = {
            xs = fallback.X.Scale,
            xo = fallback.X.Offset,
            ys = fallback.Y.Scale,
            yo = fallback.Y.Offset,
        }
        return fallback
    end
    return UDim2.new(
        tonumber(data.xs or data.XS) or fallback.X.Scale,
        tonumber(data.xo or data.XO) or fallback.X.Offset,
        tonumber(data.ys or data.YS) or fallback.Y.Scale,
        tonumber(data.yo or data.YO) or fallback.Y.Offset
    )
end

local function saveStoredPosition(key, pos)
    SetCfg(key, {
        xs = pos.X.Scale,
        xo = pos.X.Offset,
        ys = pos.Y.Scale,
        yo = pos.Y.Offset,
    })
end

local function fiveStepTransparency(value)
    return math.clamp(((tonumber(value) or 1) - 1) / 4, 0, 1)
end

-- ODH bindable-button implementation, based on the supplied BindableButtons.luau.
-- Extra setters only adjust the SG button; the visual/interaction style remains ODH's.
local BindableButtons = (function()
    local buttons = {Buttons={}, Maids={}, Locked={}, Callbacks={}, Count=0}
    local shapes = {
        [0] = "rbxassetid://86221076925479",
        [1] = "rbxassetid://96242665417546",
        [2] = "rbxassetid://97129189935336",
        [3] = "rbxassetid://76165862027868",
        [4] = "rbxassetid://125868092127496",
    }
    local normalColor = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.new(0.133333, 0.827451, 0.494118)),
        ColorSequenceKeypoint.new(0.6, Color3.new(0.231373, 0.509804, 0.498039)),
        ColorSequenceKeypoint.new(1, Color3.new(0.501961, 0.501961, 0.501961)),
    })
    local toggledColor = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.new(0.0784314, 0.0784314, 0.0784314)),
        ColorSequenceKeypoint.new(0.75, Color3.new(0.0784314, 0.0784314, 0.54902)),
        ColorSequenceKeypoint.new(1, Color3.new(0.470588, 0.156863, 0.470588)),
    })

    local function storage()
        local roots={}
        if type(gethui)=="function" then
            local ok,result=pcall(gethui)
            if ok and typeof(result)=="Instance" then table.insert(roots,result) end
        end
        local okCore,core=pcall(function() return game:GetService("CoreGui") end)
        if okCore and typeof(core)=="Instance" then table.insert(roots,core) end
        local pg=player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui")
        table.insert(roots,pg)
        for _,root in ipairs(roots) do
            local ok,existing=pcall(function() return root:FindFirstChild("@bindstorage") end)
            if ok and typeof(existing)=="Instance" and existing:IsA("ScreenGui") then return existing end
        end
        local sg=Instance.new("ScreenGui")
        sg.Name="@bindstorage"
        sg.ResetOnSpawn=false
        sg.IgnoreGuiInset=true
        pcall(function() sg.ScreenInsets=Enum.ScreenInsets.None end)
        sg.Parent=pg
        return sg
    end

    function buttons:DeleteBButton(id)
        local maid=self.Maids[id]
        if maid then
            for _,item in ipairs(maid) do
                if typeof(item)=="RBXScriptConnection" then pcall(function() item:Disconnect() end)
                elseif typeof(item)=="Instance" then pcall(function() item:Destroy() end) end
            end
        end
        local b=self.Buttons[id]
        if b then pcall(function() b:Destroy() end) end
        self.Buttons[id],self.Maids[id],self.Locked[id],self.Callbacks[id]=nil,nil,nil,nil
    end

    function buttons:SetShape(id,shape)
        local b=self.Buttons[id]
        if b and shapes[shape] then b.Image=shapes[shape] end
    end
    function buttons:SetLocked(id,state) self.Locked[id]=not not state end
    function buttons:SetVisible(id,state) local b=self.Buttons[id]; if b then b.Visible=not not state end end
    function buttons:SetText(id,text) local b=self.Buttons[id]; local l=b and b:FindFirstChild("@Text"); if l then l.Text=tostring(text or "") end end
    function buttons:SetPosition(id,pos) local b=self.Buttons[id]; if b then b.Position=pos end end
    function buttons:GetPosition(id) local b=self.Buttons[id]; return b and b.Position or nil end
    function buttons:SetSize(id,level)
        local b=self.Buttons[id]; if not b then return end
        level=math.clamp(tonumber(level) or 2,1,10)
        -- The stock ODH button is much larger. 1..10 maps down to 14..50 px
        -- so level 1 can be substantially smaller than ODH's normal minimum.
        local px=14+((level-1)*4)
        b.Size=UDim2.fromOffset(px,px)
        local label=b:FindFirstChild("@Text")
        if label and label:IsA("TextLabel") then
            label.TextSize=math.clamp(math.floor(px*0.34),6,10)
        end
    end
    function buttons:SetValue(id,state,runCallback)
        local b=self.Buttons[id]; if not b then return end
        local value=b:FindFirstChild("BindValue")
        if not value then return end
        state=not not state
        if value.Value~=state then
            value.Value=state
            if runCallback then
                local callbacks=self.Callbacks[id]
                if callbacks then
                    if state then pcall(callbacks[1]) else pcall(callbacks[2]) end
                end
            end
        end
        local stroke=b:FindFirstChild("@Stroke")
        if stroke and stroke:IsA("UIGradient") then stroke.Color=state and toggledColor or normalColor end
    end

    function buttons.AddBButton(id,text,onFunc,offFunc,onMoved)
        buttons:DeleteBButton(id)
        local root=storage()
        local old=root:FindFirstChild(id)
        if old then old:Destroy() end

        local cameraNow=workspace.CurrentCamera
        local screen=cameraNow and cameraNow.ViewportSize or Vector2.new(1920,1080)
        local buttonSizeY=0.11
        local widthScale=buttonSizeY*(screen.Y/math.max(1,screen.X))
        local xPos=0.1+((buttons.Count%8)*(widthScale+0.005))
        local yPos=0.9-(math.floor(buttons.Count/8)*(buttonSizeY+0.015))

        local b=Instance.new("ImageButton")
        b.Name=id
        b.Size=UDim2.new(widthScale,0,buttonSizeY,0)
        b.Position=UDim2.new(xPos,0,yPos,0)
        b.AnchorPoint=Vector2.new(0.5,0.5)
        b.Image=shapes[0]
        b.BackgroundTransparency=1
        b.BorderSizePixel=0
        b.ClipsDescendants=false
        b.AutoButtonColor=false
        b.Parent=root

        local value=Instance.new("BoolValue")
        value.Name="BindValue"
        value.Parent=b

        local label=Instance.new("TextLabel")
        label.Name="@Text"
        label.Size=UDim2.fromScale(0.8,0.8)
        label.Position=UDim2.fromScale(0.5,0.5)
        label.AnchorPoint=Vector2.new(0.5,0.5)
        label.BackgroundTransparency=1
        label.Font=Enum.Font.Jura
        label.Text=tostring(text or "")
        label.TextColor3=Color3.new(1,1,1)
        label.TextSize=10
        label.TextWrapped=true
        label.ZIndex=3
        label.Parent=b

        local aspect=Instance.new("UIAspectRatioConstraint")
        aspect.AspectRatio=1
        aspect.AspectType=Enum.AspectType.ScaleWithParentSize
        aspect.Parent=b

        local stroke=Instance.new("UIGradient")
        stroke.Name="@Stroke"
        stroke.Color=normalColor
        stroke.Parent=b

        local ripple=Instance.new("Frame")
        ripple.Name="@ripple"
        ripple.BackgroundColor3=Color3.fromRGB(0,155,255)
        ripple.BackgroundTransparency=0.5
        ripple.Size=UDim2.fromOffset(0,0)
        ripple.AnchorPoint=Vector2.new(0.5,0.5)
        ripple.Visible=false
        ripple.ZIndex=2
        ripple.Parent=b
        Instance.new("UICorner",ripple).CornerRadius=UDim.new(1,0)

        local sound=Instance.new("Sound")
        sound.SoundId="rbxassetid://3868133279"
        sound.Volume=0.5
        sound.Parent=b

        buttons.Buttons[id]=b
        buttons.Maids[id]={}
        buttons.Locked[id]=false
        buttons.Callbacks[id]={onFunc,offFunc}
        buttons.Count+=1

        local dragging=false
        local dragInput,dragStart,startPos
        local moved=false
        local debounce=false
        local conns=buttons.Maids[id]

        local function click()
            if debounce then return end
            debounce=true
            local fadeOut=TweenService:Create(b,TweenInfo.new(0.3,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut),{ImageTransparency=1})
            fadeOut:Play(); fadeOut.Completed:Wait()
            value.Value=not value.Value
            stroke.Color=value.Value and toggledColor or normalColor
            if value.Value then pcall(onFunc) else pcall(offFunc) end
            local baseAlpha=tonumber(b:GetAttribute("VisualsV2BaseImageTransparency")) or 0
            local fadeIn=TweenService:Create(b,TweenInfo.new(0.3,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut),{ImageTransparency=baseAlpha})
            fadeIn:Play(); fadeIn.Completed:Wait()
            debounce=false
        end

        table.insert(conns,b.InputBegan:Connect(function(input)
            if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
            dragging=true; moved=false; dragStart=input.Position; startPos=b.Position
            pcall(function() sound:Play() end)
            local abs=b.AbsolutePosition
            ripple.Position=UDim2.fromOffset(input.Position.X-abs.X,input.Position.Y-abs.Y)
            ripple.Size=UDim2.fromOffset(0,0); ripple.BackgroundTransparency=0.5; ripple.Visible=true
            TweenService:Create(ripple,TweenInfo.new(0.4,Enum.EasingStyle.Sine,Enum.EasingDirection.Out),{Size=UDim2.fromOffset(45,45),BackgroundTransparency=1}):Play()
        end))
        table.insert(conns,b.InputChanged:Connect(function(input)
            if input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch then dragInput=input end
        end))
        table.insert(conns,UserInputService.InputChanged:Connect(function(input)
            if input~=dragInput or not dragging or buttons.Locked[id] then return end
            local delta=input.Position-dragStart
            if delta.Magnitude>7 then moved=true end
            local parentSize=b.Parent.AbsoluteSize
            if parentSize.X>0 and parentSize.Y>0 then
                b.Position=UDim2.new(startPos.X.Scale+(delta.X/parentSize.X),0,startPos.Y.Scale+(delta.Y/parentSize.Y),0)
            end
        end))
        table.insert(conns,UserInputService.InputEnded:Connect(function(input)
            if not dragging then return end
            if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
            dragging=false
            if moved and not buttons.Locked[id] then
                if onMoved then pcall(onMoved,b.Position) end
            elseif not moved then
                task.spawn(click)
            end
        end))
        table.insert(conns,RunService.RenderStepped:Connect(function() stroke.Rotation=(stroke.Rotation+1)%360 end))
        return value
    end

    return buttons
end)()

local function updateSpeedButtonStyle()
    if speedButton then
        speedButton.Size=UDim2.fromOffset(speedButtonWidth,speedButtonHeight)
        speedButton.BackgroundColor3=speedButtonColor
        speedButton.BackgroundTransparency=fiveStepTransparency(speedButtonTransparency)
        speedButton.Text=speedEnabled and "Active" or "Off"
        speedButton.TextScaled=false
        speedButton.TextSize=math.max(10,math.floor(speedButtonHeight*0.38))
        speedButton.TextStrokeTransparency=1
        speedButton.Visible=speedButtonVisible
    end
    local id="VisualsV2_SpeedBind"
    BindableButtons:SetVisible(id,speedBindButtonVisible)
    BindableButtons:SetLocked(id,lockBindButtonPos)
    BindableButtons:SetSize(id,speedBindButtonSize)
    BindableButtons:SetText(id,"SG")
    BindableButtons:SetValue(id,speedEnabled,false)
end

local function setSpeedState(state)
    if speedToggle then speedToggle:Set(state) end
end

local function makeBigButtonDraggable(button)
    local active=false
    local moved=false
    local dragStart,startPos,dragInput
    button.InputBegan:Connect(function(input)
        if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
        active=true; moved=false; dragStart=input.Position; startPos=button.Position
    end)
    button.InputChanged:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch then dragInput=input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not active or input~=dragInput or lockBigButtonPos then return end
        local delta=input.Position-dragStart
        if delta.Magnitude>7 then moved=true end
        button.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y)
    end)
    UserInputService.InputEnded:Connect(function(input)
        if not active then return end
        if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
        active=false
        if moved and not lockBigButtonPos then
            saveStoredPosition("speedButtonPosition",button.Position)
        else
            setSpeedState(not speedEnabled)
        end
    end)
end

local function setupSpeedButtons()
    if speedGui then speedGui:Destroy() end
    BindableButtons:DeleteBButton("VisualsV2_SpeedBind")

    local gui=Instance.new("ScreenGui")
    gui.Name="VisualsV2_SpeedGlitchUI"
    gui.ResetOnSpawn=false
    gui.IgnoreGuiInset=true
    gui.Parent=player:WaitForChild("PlayerGui")
    speedGui=gui

    local big=Instance.new("TextButton")
    big.Name="SpeedGlitchBigButton"
    big.AnchorPoint=Vector2.new(0.5,0.5)
    big.Position=loadStoredPosition("speedButtonPosition",BIG_BUTTON_DEFAULT)
    big.BackgroundColor3=speedButtonColor
    big.BorderSizePixel=0
    big.TextColor3=Color3.new(1,1,1)
    big.Font=Enum.Font.Jura
    big.AutoButtonColor=false
    big.Active=true
    big.Parent=gui
    speedButton=big

    local corner=Instance.new("UICorner")
    corner.CornerRadius=UDim.new(0,5)
    corner.Parent=big
    makeBigButtonDraggable(big)

    BindableButtons.AddBButton(
        "VisualsV2_SpeedBind",
        "SG",
        function() setSpeedState(true) end,
        function() setSpeedState(false) end,
        function(pos) saveStoredPosition("speedBindButtonPosition",pos) end
    )
    BindableButtons:SetShape("VisualsV2_SpeedBind",1)
    BindableButtons:SetPosition("VisualsV2_SpeedBind",loadStoredPosition("speedBindButtonPosition",BIND_BUTTON_DEFAULT))
    updateSpeedButtonStyle()
end

speedToggle=addToggle(speedSection,"Enable Speed Glitch",speedEnabled,function(state)
    speedEnabled=state
    SetCfg("speedGlitchEnabled",state)
    updateSpeedButtonStyle()
end)
speedSection:AddSlider("Speed",1,300,speedValue,function(value)
    speedValue=value
    SetCfg("speedValue",value)
end)
speedSection:AddKeybind("Speed Glitch Bind","G",function() setSpeedState(not speedEnabled) end)
addToggle(speedSection,"Show Big Button",speedButtonVisible,function(state)
    speedButtonVisible=state; SetCfg("speedButtonVisible",state); updateSpeedButtonStyle()
end)
addToggle(speedSection,"Show Bindable Button",speedBindButtonVisible,function(state)
    speedBindButtonVisible=state; SetCfg("speedBindButtonVisible",state); updateSpeedButtonStyle()
end)
speedSection:AddSlider("Big Button Width",70,260,speedButtonWidth,function(value)
    speedButtonWidth=value; SetCfg("speedButtonWidth",value); updateSpeedButtonStyle()
end)
speedSection:AddSlider("Big Button Height",28,110,speedButtonHeight,function(value)
    speedButtonHeight=value; SetCfg("speedButtonHeight",value); updateSpeedButtonStyle()
end)
speedSection:AddColorpicker("Big Button Color",speedButtonColor,function(color)
    speedButtonColor=color; SetCfg("speedButtonColor",color); updateSpeedButtonStyle()
end)
speedSection:AddSlider("Big Button Transparency",1,5,speedButtonTransparency,function(value)
    speedButtonTransparency=math.clamp(tonumber(value) or 1,1,5)
    SetCfg("speedButtonTransparency",speedButtonTransparency)
    updateSpeedButtonStyle()
end)
speedSection:AddSlider("Bind Button Size",1,10,speedBindButtonSize,function(value)
    speedBindButtonSize=math.clamp(tonumber(value) or 5,1,10)
    SetCfg("speedBindButtonSize",speedBindButtonSize)
    updateSpeedButtonStyle()
end)
speedSection:AddButton("Reset Big Button Position",function()
    if speedButton then speedButton.Position=BIG_BUTTON_DEFAULT end
    SetCfg("speedButtonPosition",nil)
end)
speedSection:AddButton("Reset Bind Button Position",function()
    BindableButtons:SetPosition("VisualsV2_SpeedBind",BIND_BUTTON_DEFAULT)
    SetCfg("speedBindButtonPosition",nil)
end)

setupSpeedButtons()

local function shiftLockActive()
    return UserInputService.MouseBehavior==Enum.MouseBehavior.LockCenter
end

RunService.Heartbeat:Connect(function()
    local char=player.Character
    local humanoid=char and char:FindFirstChildOfClass("Humanoid")
    local hrp=char and char:FindFirstChild("HumanoidRootPart")
    if speedEnabled and shiftLockActive() and humanoid and hrp and humanoid.FloorMaterial==Enum.Material.Air then
        local moveDir=humanoid.MoveDirection
        if moveDir.Magnitude>0 then
            local vel=hrp.AssemblyLinearVelocity
            hrp.AssemblyLinearVelocity=Vector3.new(moveDir.X*speedValue,vel.Y,moveDir.Z*speedValue)
        end
    end
end)

env.VisualsV2Runtime.RegisterReset(function()
    speedToggle:Set(false)
    speedEnabled=false
    speedButtonVisible=false
    speedBindButtonVisible=false
    lockBigButtonPos=false
    lockBindButtonPos=false
    speedButtonWidth=115
    speedButtonHeight=45
    speedButtonColor=Color3.fromRGB(0,0,0)
    speedButtonTransparency=4
    speedBindButtonSize=5
    if speedButton then speedButton.Position=BIG_BUTTON_DEFAULT; speedButton.Visible=false end
    BindableButtons:SetPosition("VisualsV2_SpeedBind",BIND_BUTTON_DEFAULT)
    BindableButtons:SetVisible("VisualsV2_SpeedBind",false)
    BindableButtons:SetLocked("VisualsV2_SpeedBind",false)
    updateSpeedButtonStyle()
end)

-- =========================================================
-- UTILITIES: DISTANCE ESP ONLY
-- =========================================================

local espSection = mainTab:AddSection("Distance ESP", "Utilities")
local distanceEspEnabled = C("distanceEspEnabled", false)
local distanceRenderDistance = C("distanceRenderDistance", 200)
local distanceColor = C("distanceColor", Color3.fromRGB(0, 0, 0))
local distanceTextSize = C("distanceTextSize", 12)
local distancePosition = C("distancePosition", "Bottom")
local distanceObjects = {}
if tonumber(ConfigData["distanceRenderDistance"]) == 175 then distanceRenderDistance = 200; ConfigData["distanceRenderDistance"] = 200 end
if tonumber(ConfigData["distanceTextSize"]) == 8 then distanceTextSize = 12; ConfigData["distanceTextSize"] = 12 end

local function distanceOffset()
    if distancePosition == "Top" then return Vector3.new(0, 3.25, 0) end
    if distancePosition == "Middle" then return Vector3.new(0, 0, 0) end
    return Vector3.new(0, -3.0, 0)
end

local function removeDistanceObject(plr)
    local gui = distanceObjects[plr]
    if gui then gui:Destroy() end
    distanceObjects[plr] = nil
end

local function ensureDistanceObject(plr)
    if plr == player then return nil end
    local char = plr.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then removeDistanceObject(plr); return nil end

    local gui = distanceObjects[plr]
    if not gui or not gui.Parent then
        gui = Instance.new("BillboardGui")
        gui.Name = "VisualsV2_DistanceESP"
        gui.Size = UDim2.new(0, 100, 0, 26)
        gui.StudsOffset = distanceOffset()
        gui.AlwaysOnTop = false
        gui.Adornee = root
        gui.Parent = root

        local label = Instance.new("TextLabel")
        label.Name = "Distance"
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.Code
        label.TextStrokeTransparency = 1
        label.TextXAlignment = Enum.TextXAlignment.Center
        label.TextYAlignment = Enum.TextYAlignment.Center
        label.Parent = gui
        distanceObjects[plr] = gui
    else
        gui.Adornee = root
        gui.StudsOffset = distanceOffset()
        gui.AlwaysOnTop = false
        if gui.Parent ~= root then gui.Parent = root end
    end
    return gui
end

local function clearDistanceEsp()
    for plr in pairs(distanceObjects) do removeDistanceObject(plr) end
end

local distanceToggle = addToggle(espSection, "Enable Distance ESP", distanceEspEnabled, function(state)
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
addDropdown(espSection, "Position", {"Top", "Middle", "Bottom"}, distancePosition, function(selected)
    distancePosition = selected
    SetCfg("distancePosition", selected)
    for _, gui in pairs(distanceObjects) do if gui and gui.Parent then gui.StudsOffset = distanceOffset() end end
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

env.VisualsV2Runtime.RegisterReset(function()
    distanceToggle:Set(false)
    distanceEspEnabled=false
    distanceRenderDistance=200
    distanceColor=Color3.fromRGB(0,0,0)
    distanceTextSize=12
    distancePosition="Bottom"
    clearDistanceEsp()
end)

-- =========================================================
-- UTILITIES: SHOOT MURDERER BUTTON
-- Customizes only the existing ODH button. Position saves automatically.
-- =========================================================

;(function()
local section=mainTab:AddSection("Shoot Murderer Button","Utilities")
local customEnabled=C("shootCustomizationEnabled",false)
local buttonWidth=C("shootButtonWidth",100)
local buttonHeight=C("shootButtonHeight",40)
local keepGun=C("shootKeepGunEnabled",false)
local allowDrag=C("shootDragEnabled",false)
local hideText=C("shootHideText",false)
local button,scale,textObject,oldText,originalSize,originalPosition
local conns={}
local gunConn,gunTask
local dragging=false
local dragInput,dragStart,startPos
local DEFAULT_POS=UDim2.new(0.5,-50,0.5,-20)
local buttonPos=loadStoredPosition("shootMurdButtonPosition",DEFAULT_POS)

local function normalize(value) return tostring(value or ""):lower():gsub("%s+","") end
local function roots()
    local result,seen={},{}
    local function add(root)
        if typeof(root)=="Instance" and not seen[root] then seen[root]=true; table.insert(result,root) end
    end
    pcall(function() add(game:GetService("CoreGui")) end)
    if type(gethui)=="function" then local ok,r=pcall(gethui); if ok then add(r) end end
    pcall(function() add(player:FindFirstChildOfClass("PlayerGui")) end)
    return result
end
local function isTarget(item)
    if not item or not item:IsA("TextButton") then return false end
    if normalize(item.Text):find("shootmurderer",1,true) then return true end
    local label=item:FindFirstChildWhichIsA("TextLabel",true)
    if label and normalize(label.Text):find("shootmurderer",1,true) then return true end
    return item:GetAttribute("ShootMurderButton")==true
end
local function findButton()
    for _,root in ipairs(roots()) do
        local ok,desc=pcall(function() return root:GetDescendants() end)
        if ok then
            for _,item in ipairs(desc) do
                if isTarget(item) then item:SetAttribute("ShootMurderButton",true); return item end
            end
        end
    end
end
local function getTextTarget(btn)
    if not btn then return nil,nil end
    if tostring(btn.Text or "")~="" then return btn,btn.Text end
    local label=btn:FindFirstChildWhichIsA("TextLabel",true)
    if label then return label,label.Text end
    return btn,"Shoot Murderer"
end
local function stopKeeper()
    if gunConn then gunConn:Disconnect(); gunConn=nil end
    if gunTask then pcall(task.cancel,gunTask); gunTask=nil end
end
local function keepEquipped()
    if not keepGun then return end
    local char=player.Character
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    local backpack=player:FindFirstChildOfClass("Backpack")
    if not hum or not backpack then return end
    local gun
    for _,container in ipairs({char,backpack}) do
        if container then
            for _,item in ipairs(container:GetChildren()) do
                if item:IsA("Tool") and item.Name:lower():find("gun",1,true) then gun=item; break end
            end
        end
        if gun then break end
    end
    if not gun then return end
    stopKeeper()
    gunConn=gun.AncestryChanged:Connect(function(_,parent)
        if keepGun and parent==backpack then
            task.defer(function() if hum.Parent and gun.Parent then pcall(function() hum:EquipTool(gun) end) end end)
        end
    end)
    gunTask=task.delay(0.3,stopKeeper)
end
local function animate()
    if not scale then return end
    scale.Scale=0.91
    TweenService:Create(scale,TweenInfo.new(0.65,Enum.EasingStyle.Elastic,Enum.EasingDirection.Out),{Scale=1}):Play()
end
local function restoreOriginal()
    if not button then return end
    if originalSize then button.Size=originalSize end
    if originalPosition then button.Position=originalPosition end
    if textObject and textObject.Parent and oldText~=nil then textObject.Text=oldText end
end
local function update()
    if not button or not customEnabled then return end
    button.Size=UDim2.new(0,buttonWidth,0,buttonHeight)
    button.Position=buttonPos
    button.Active=true
    button.Modal=false
    button.Selectable=false
    if textObject and textObject.Parent then
        textObject.Text=hideText and "" or ((oldText and oldText~="") and oldText or "Shoot Murderer")
    end
end
local function clearConnections()
    for _,conn in ipairs(conns) do pcall(function() conn:Disconnect() end) end
    table.clear(conns)
    if scale then pcall(function() scale:Destroy() end); scale=nil end
end
local function bind(newButton)
    if not newButton or button==newButton then return end
    clearConnections()
    button=newButton
    button:SetAttribute("ShootMurderButton",true)
    textObject,oldText=getTextTarget(button)
    originalSize=button.Size
    originalPosition=button.Position
    button.AutoButtonColor=false
    button.Active=true
    button.Modal=false
    button.Selectable=false
    scale=Instance.new("UIScale")
    scale.Parent=button
    update()

    -- No addon action is triggered by a random screen press.
    -- Dragging can only begin on this exact button.
    table.insert(conns,button.InputBegan:Connect(function(input)
        if not customEnabled or not allowDrag then return end
        if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
        dragging=true
        dragInput=input
        dragStart=input.Position
        startPos=button.Position
    end))

    -- Keep-gun/animation helpers only run from an actual click on the button.
    table.insert(conns,button.MouseButton1Click:Connect(function()
        if not customEnabled or allowDrag then return end
        keepEquipped()
        animate()
    end))
    table.insert(conns,UserInputService.InputChanged:Connect(function(input)
        if not dragging or not customEnabled or not allowDrag or not button then return end
        if input.UserInputType~=Enum.UserInputType.MouseMovement and input.UserInputType~=Enum.UserInputType.Touch then return end
        if dragInput and dragInput.UserInputType==Enum.UserInputType.Touch and input.UserInputType~=Enum.UserInputType.Touch then return end
        local delta=input.Position-dragStart
        button.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y)
    end))
    table.insert(conns,UserInputService.InputEnded:Connect(function(input)
        if not dragging then return end
        if input==dragInput or input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            dragging=false; dragInput=nil
            if button then buttonPos=button.Position; saveStoredPosition("shootMurdButtonPosition",buttonPos) end
        end
    end))
    table.insert(conns,button:GetPropertyChangedSignal("Size"):Connect(function()
        if not customEnabled or not button then return end
        local wanted=UDim2.new(0,buttonWidth,0,buttonHeight)
        if button.Size~=wanted then button.Size=wanted end
    end))
    table.insert(conns,button.AncestryChanged:Connect(function()
        if button and not button:IsDescendantOf(game) then
            button=nil
            task.defer(function() local replacement=findButton(); if replacement then bind(replacement) end end)
        end
    end))
end

local customToggle=addToggle(section,"Enable Button Customization",customEnabled,function(v)
    customEnabled=v; SetCfg("shootCustomizationEnabled",v)
    if v then update() else restoreOriginal(); dragging=false; dragInput=nil; stopKeeper() end
end)
section:AddSlider("Button Width",40,300,buttonWidth,function(v) buttonWidth=v; SetCfg("shootButtonWidth",v); update() end)
section:AddSlider("Button Height",20,150,buttonHeight,function(v) buttonHeight=v; SetCfg("shootButtonHeight",v); update() end)
local keepToggle=addToggle(section,"Keep Gun Equipped",keepGun,function(v) keepGun=v; SetCfg("shootKeepGunEnabled",v); if not v then stopKeeper() end end)
local dragToggle=addToggle(section,"Allow Drag",allowDrag,function(v) allowDrag=v; SetCfg("shootDragEnabled",v); dragging=false; dragInput=nil end)
local textToggle=addToggle(section,"Hide Button Text",hideText,function(v)
    hideText=v
    SetCfg("shootHideText",v)
    update()
end)
section:AddButton("Reset Button Position",function()
    DEFAULT_POS=UDim2.new(0.5,-buttonWidth/2,0.5,-buttonHeight/2)
    buttonPos=DEFAULT_POS
    SetCfg("shootMurdButtonPosition",nil)
    if customEnabled and button then button.Position=buttonPos end
end)
section:AddButton("Rescan Shoot Murderer Button",function()
    local found=findButton()
    if found then bind(found); shared.Notify("Shoot Murderer button found.",2) else shared.Notify("Shoot Murderer button was not found.",2) end
end)

task.defer(function()
    task.wait(0.5)
    local found=findButton(); if found then bind(found) end
    for _,root in ipairs(roots()) do
        pcall(function()
            root.DescendantAdded:Connect(function(item) if isTarget(item) then task.defer(function() bind(item) end) end end)
        end)
    end
end)

env.VisualsV2Runtime.RegisterReset(function()
    customToggle:Set(false); keepToggle:Set(false); dragToggle:Set(false); textToggle:Set(false)
    customEnabled=false; keepGun=false; allowDrag=false; hideText=false
    buttonWidth=100; buttonHeight=40; buttonPos=UDim2.new(0.5,-50,0.5,-20)
    stopKeeper(); restoreOriginal()
end)
end)()

-- =========================================================
-- VISUALS: GUNS & KNIVES
-- Highlight-only Gun/Knife visuals so there is no tint-mode conflict.
-- =========================================================

;(function()
local section=mainTab:AddSection("Guns & Knives","Visuals")
local enabled=C("gunsVisualEnabled",false)
local tintColor=C("gunsTintColor",Color3.fromRGB(255,255,255))
local rainbow=C("gunsRainbow",false)
local rainbowSpeed=C("gunsRainbowSpeed",3)
local rainbowConnection
local HIGHLIGHT_NAME="VisualsV2_GunsKnivesHighlight"

local function isGunKnife(tool)
    if not tool or not tool:IsA("Tool") then return false end
    local name=tool.Name:lower()
    return name=="gun" or name=="knife"
end
local function currentColor()
    if rainbow then return Color3.fromHSV((os.clock()*((tonumber(rainbowSpeed) or 3)*0.1))%1,1,1) end
    return tintColor
end
local function removeHighlight(tool)
    if not tool then return end
    local h=tool:FindFirstChild(HIGHLIGHT_NAME)
    if h then h:Destroy() end
end
local function applyTool(tool)
    if not enabled or not isGunKnife(tool) then return end
    local h=tool:FindFirstChild(HIGHLIGHT_NAME)
    if not h then
        h=Instance.new("Highlight")
        h.Name=HIGHLIGHT_NAME
        h.Adornee=tool
        h.DepthMode=Enum.HighlightDepthMode.Occluded
        h.FillTransparency=0.5
        h.OutlineTransparency=1
        h.Parent=tool
    end
    h.FillColor=currentColor()
end
local function allTools()
    local result={}
    for _,container in ipairs({player.Character,player:FindFirstChildOfClass("Backpack")}) do
        if container then for _,obj in ipairs(container:GetChildren()) do if isGunKnife(obj) then table.insert(result,obj) end end end
    end
    return result
end
local function restoreAll()
    if rainbowConnection then rainbowConnection:Disconnect(); rainbowConnection=nil end
    for _,tool in ipairs(allTools()) do removeHighlight(tool) end
end
local function applyAll()
    for _,tool in ipairs(allTools()) do applyTool(tool) end
end
local function refresh()
    restoreAll()
    if enabled then applyAll() end
    if enabled and rainbow then
        rainbowConnection=RunService.RenderStepped:Connect(applyAll)
    end
end
local function watch(container)
    if not container then return end
    container.ChildAdded:Connect(function(obj)
        if isGunKnife(obj) and enabled then task.defer(function() applyTool(obj) end) end
    end)
end
watch(player:FindFirstChildOfClass("Backpack")); watch(player.Character)
player.CharacterAdded:Connect(function(char) watch(char); if enabled then task.defer(applyAll) end end)

env.VisualsV2Runtime.GunsKnivesEnabled=enabled
env.VisualsV2Runtime.RefreshGunsKnives=refresh

local enabledToggle=addToggle(section,"Enable Guns & Knives Visuals",enabled,function(state)
    enabled=state
    SetCfg("gunsVisualEnabled",state)
    env.VisualsV2Runtime.GunsKnivesEnabled=state
    if state then
        if type(env.VisualsV2Runtime.RestoreToolTintGunKnife)=="function" then pcall(env.VisualsV2Runtime.RestoreToolTintGunKnife) end
        refresh()
    else
        restoreAll()
        if type(env.VisualsV2Runtime.RefreshToolTint)=="function" then pcall(env.VisualsV2Runtime.RefreshToolTint) end
    end
end)
section:AddColorpicker("Highlight Color",tintColor,function(color)
    tintColor=color; SetCfg("gunsTintColor",color); if enabled and not rainbow then applyAll() end
end)
local rainbowToggle=addToggle(section,"Rainbow",rainbow,function(state)
    rainbow=state; SetCfg("gunsRainbow",state); refresh()
end)
section:AddSlider("Rainbow Speed",1,10,rainbowSpeed,function(value)
    rainbowSpeed=math.clamp(tonumber(value) or 3,1,10); SetCfg("gunsRainbowSpeed",rainbowSpeed)
end)

env.VisualsV2Runtime.RegisterReset(function()
    enabledToggle:Set(false); rainbowToggle:Set(false)
    enabled=false; rainbow=false; tintColor=Color3.fromRGB(255,255,255); rainbowSpeed=3
    env.VisualsV2Runtime.GunsKnivesEnabled=false
    restoreAll()
    if type(env.VisualsV2Runtime.RefreshToolTint)=="function" then pcall(env.VisualsV2Runtime.RefreshToolTint) end
end)
if enabled then task.defer(refresh) end
end)()

-- =========================================================
-- UTILITIES: GUN+
-- Adapted from drowsynicolas/tuffODHaddons; numeric sliders intentionally omitted.
-- =========================================================

;(function()
local section=mainTab:AddSection("Gun+","Utilities")
local blockAnimations=C("gunPlusBlockAnimations",false)
local equipSound=C("gunPlusEquipSound",false)
local dropForceField=C("gunPlusDropForceField",false)
local dropFireColorEnabled=C("gunPlusDropFireColorEnabled",false)
local forceFieldColor=C("gunPlusForceFieldColor",Color3.fromRGB(255,255,255))
local dropFireColor=C("gunPlusDropFireColor",Color3.fromRGB(255,255,255))
local SOUND_ID="rbxassetid://7158356564"
local START_OFFSET=0.3
local BLOCKED={
    ["123606547020560"]=true,["134826825394657"]=true,
    ["124281955370937"]=true,["127786188145385"]=true,
}
local animConn
local seenGuns=setmetatable({}, {__mode="k"})
local sounds=setmetatable({}, {__mode="k"})
local dropWatchConn
local fireOriginals=setmetatable({}, {__mode="k"})
local FORCE_FIELD_NAME="VisualsV2_GunDropForceField"

local function playSound()
    local char=player.Character
    local hrp=char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local old=sounds[char]
    if old then pcall(function() old:Stop(); old:Destroy() end) end
    local sound=Instance.new("Sound")
    sound.SoundId=SOUND_ID; sound.Volume=1; sound.Parent=hrp
    pcall(function() sound.TimePosition=START_OFFSET end)
    sound:Play(); sounds[char]=sound
    sound.Ended:Once(function()
        if sounds[char]==sound then sounds[char]=nil end
        if sound.Parent then sound:Destroy() end
    end)
end
local function hookGun(tool)
    if not tool or not tool:IsA("Tool") or tool.Name~="Gun" or seenGuns[tool] then return end
    seenGuns[tool]=true
    tool.Equipped:Connect(function() if equipSound then playSound() end end)
    tool.Unequipped:Connect(function() if equipSound then playSound() end end)
end
local function scanGuns(container)
    if not container then return end
    for _,obj in ipairs(container:GetChildren()) do if obj:IsA("Tool") then hookGun(obj) end end
end
local backpack=player:FindFirstChildOfClass("Backpack")
if backpack then
    scanGuns(backpack)
    backpack.ChildAdded:Connect(function(obj) if obj:IsA("Tool") then hookGun(obj) end end)
end
local function watchCharacter(char)
    scanGuns(char)
    char.ChildAdded:Connect(function(obj) if obj:IsA("Tool") then hookGun(obj) end end)
end
if player.Character then watchCharacter(player.Character) end
player.CharacterAdded:Connect(watchCharacter)

local function refreshAnimationLoop()
    if animConn then animConn:Disconnect(); animConn=nil end
    if not blockAnimations then return end
    animConn=RunService.RenderStepped:Connect(function()
        local char=player.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        for _,track in ipairs(hum:GetPlayingAnimationTracks()) do
            local anim=track.Animation
            local id=anim and anim.AnimationId and anim.AnimationId:match("%d+")
            if id and BLOCKED[id] then track:Stop(0) end
        end
    end)
end

local function findForceField(drop)
    return drop and drop:FindFirstChild(FORCE_FIELD_NAME)
end
local function applyForceField(drop)
    if not dropForceField or not drop or drop.Name~="GunDrop" or not drop:IsA("BasePart") then return end
    local sphere=findForceField(drop)
    if not sphere then
        sphere=Instance.new("Part")
        sphere.Name=FORCE_FIELD_NAME
        sphere.Shape=Enum.PartType.Ball
        sphere.Size=Vector3.new(3.5,3.5,3.5)
        sphere.Material=Enum.Material.ForceField
        sphere.Transparency=0.3
        sphere.CanCollide=false; sphere.CanTouch=false; sphere.CanQuery=false; sphere.CastShadow=false; sphere.Massless=true
        sphere.CFrame=drop.CFrame
        sphere.Parent=drop
        local weld=Instance.new("WeldConstraint")
        weld.Name="VisualsV2_GunDropForceFieldWeld"
        weld.Part0=drop; weld.Part1=sphere; weld.Parent=sphere
    end
    sphere.Color=forceFieldColor
end
local function removeForceFields()
    for _,obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name=="GunDrop" then
            local sphere=findForceField(obj); if sphere then sphere:Destroy() end
        end
    end
end
local function applyFire(fire)
    if not dropFireColorEnabled or not fire or not fire:IsA("Fire") then return end
    local parent=fire.Parent
    if not parent or parent.Name~="GunDrop" then return end
    if not fireOriginals[fire] then fireOriginals[fire]={Color=fire.Color,SecondaryColor=fire.SecondaryColor} end
    fire.Color=dropFireColor; fire.SecondaryColor=dropFireColor
end
local function applyDrop(drop)
    if not drop or drop.Name~="GunDrop" or not drop:IsA("BasePart") then return end
    applyForceField(drop)
    local fire=drop:FindFirstChildOfClass("Fire"); if fire then applyFire(fire) end
end
local function restoreFireColors()
    for fire,data in pairs(fireOriginals) do
        if fire and fire.Parent then pcall(function() fire.Color=data.Color; fire.SecondaryColor=data.SecondaryColor end) end
    end
    fireOriginals=setmetatable({}, {__mode="k"})
end
local function applyExistingDrops()
    for _,obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name=="GunDrop" then applyDrop(obj)
        elseif obj:IsA("Fire") and obj.Parent and obj.Parent.Name=="GunDrop" then applyFire(obj) end
    end
end
local function refreshDropWatcher()
    if dropWatchConn then dropWatchConn:Disconnect(); dropWatchConn=nil end
    if not dropForceField and not dropFireColorEnabled then return end
    dropWatchConn=workspace.DescendantAdded:Connect(function(obj)
        if obj:IsA("BasePart") and obj.Name=="GunDrop" then task.defer(function() applyDrop(obj) end)
        elseif obj:IsA("Fire") and obj.Parent and obj.Parent.Name=="GunDrop" then task.defer(function() applyFire(obj) end) end
    end)
    applyExistingDrops()
end

local blockToggle=addToggle(section,"Disable Gun Animations",blockAnimations,function(v)
    blockAnimations=v; SetCfg("gunPlusBlockAnimations",v); refreshAnimationLoop()
end)
local soundToggle=addToggle(section,"Equip/Unequip Gun Sound",equipSound,function(v)
    equipSound=v; SetCfg("gunPlusEquipSound",v)
    if not v then
        for char,sound in pairs(sounds) do pcall(function() sound:Stop(); sound:Destroy() end); sounds[char]=nil end
    end
end)
local ffToggle=addToggle(section,"Gun Force Field",dropForceField,function(v)
    dropForceField=v; SetCfg("gunPlusDropForceField",v)
    if v then refreshDropWatcher() else removeForceFields(); refreshDropWatcher() end
end)
section:AddColorpicker("Force Field Color",forceFieldColor,function(color)
    forceFieldColor=color; SetCfg("gunPlusForceFieldColor",color)
    for _,obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name=="GunDrop" then local sphere=findForceField(obj); if sphere then sphere.Color=color end end
    end
end)
local fireToggle=addToggle(section,"Custom Dropped Gun Fire Color",dropFireColorEnabled,function(v)
    dropFireColorEnabled=v; SetCfg("gunPlusDropFireColorEnabled",v)
    if v then refreshDropWatcher() else restoreFireColors(); refreshDropWatcher() end
end)
section:AddColorpicker("Dropped Gun Fire Color",dropFireColor,function(color)
    dropFireColor=color; SetCfg("gunPlusDropFireColor",color)
    if dropFireColorEnabled then applyExistingDrops() end
end)

refreshAnimationLoop(); refreshDropWatcher()
env.VisualsV2Runtime.RegisterReset(function()
    blockToggle:Set(false); soundToggle:Set(false); ffToggle:Set(false); fireToggle:Set(false)
    blockAnimations=false; equipSound=false; dropForceField=false; dropFireColorEnabled=false
    if animConn then animConn:Disconnect(); animConn=nil end
    if dropWatchConn then dropWatchConn:Disconnect(); dropWatchConn=nil end
    removeForceFields(); restoreFireColors()
    for char,sound in pairs(sounds) do pcall(function() sound:Stop(); sound:Destroy() end); sounds[char]=nil end
end)
end)()

-- =========================================================
-- VISUALS: ESTIMATED SERVER POSITION
-- =========================================================

;(function()
local section=mainTab:AddSection("Estimated Server Pos","Visuals")
local enabled=C("serverPosEnabled",false)
local markerColor=C("serverPosColor",Color3.fromRGB(255,255,255))
local transparency=math.clamp(tonumber(C("serverPosTransparency",2.5)) or 2.5,1,4)
local marker,root,humanoid,heartbeat,healthConn,charConn
local history={}

local function alpha()
    local v=math.clamp(tonumber(transparency) or 2.5,1,4)
    return 0.1+((v-1)/3)*0.75
end
local function destroyMarker()
    if heartbeat then heartbeat:Disconnect(); heartbeat=nil end
    if healthConn then healthConn:Disconnect(); healthConn=nil end
    if marker then marker:Destroy(); marker=nil end
    table.clear(history)
end
local function ping()
    local ok,value=pcall(function() return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue() end)
    return ok and math.clamp(value,10,1000) or 10
end
local function createMarker(char)
    destroyMarker()
    root=char:WaitForChild("HumanoidRootPart")
    humanoid=char:WaitForChild("Humanoid")
    marker=Instance.new("Part")
    marker.Name="VisualsV2_ServerPosition"
    marker.Size=Vector3.new(2,2,1)
    marker.Color=markerColor
    marker.Material=Enum.Material.Plastic
    marker.Transparency=alpha()
    marker.Anchored=true; marker.CanCollide=false; marker.CanTouch=false; marker.CanQuery=false; marker.CastShadow=false
    marker.Parent=workspace
    healthConn=humanoid.HealthChanged:Connect(function(health) if health<=0 then destroyMarker() end end)
    heartbeat=RunService.Heartbeat:Connect(function()
        if not marker or not marker.Parent or not root or not root.Parent then return end
        table.insert(history,{position=root.Position,rotation=root.CFrame-root.Position,time=tick()})
        while #history>120 do table.remove(history,1) end
        local target=tick()-ping()/1000
        local closest=history[1]
        if not closest then return end
        for _,entry in ipairs(history) do if math.abs(entry.time-target)<math.abs(closest.time-target) then closest=entry end end
        marker.CFrame=CFrame.new(closest.position)*closest.rotation
    end)
end
local function enable()
    if not charConn then charConn=player.CharacterAdded:Connect(function(char) task.wait(); if enabled then createMarker(char) end end) end
    if player.Character then createMarker(player.Character) end
end
local function disable()
    if charConn then charConn:Disconnect(); charConn=nil end
    destroyMarker()
end

local enableToggle=addToggle(section,"Show Server Pos",enabled,function(v)
    enabled=v; SetCfg("serverPosEnabled",v); if v then enable() else disable() end
end)
section:AddSlider("Marker Transparency",1,4,transparency,function(v)
    transparency=math.clamp(tonumber(v) or 2.5,1,4); SetCfg("serverPosTransparency",transparency)
    if marker then marker.Transparency=alpha() end
end)
section:AddColorpicker("Marker Color",markerColor,function(color)
    markerColor=color; SetCfg("serverPosColor",color); if marker then marker.Color=color end
end)

env.VisualsV2Runtime.RegisterReset(function()
    enableToggle:Set(false); enabled=false; transparency=2.5; markerColor=Color3.fromRGB(255,255,255); disable()
end)
end)()

-- =========================================================
-- VISUALS: TOOL TINT
-- Highlight-based tint so transparency always has a visible effect.
-- =========================================================

;(function()
local section=mainTab:AddSection("Tool Tint","Visuals")
section:AddParagraph("Tool Tint","Applies a configurable highlight tint to Roblox tools.")
local enabled=C("toolTintEnabled",false)
local tintColor=C("toolTintColor",Color3.fromRGB(255,255,255))
local rainbow=C("toolTintRainbow",false)
local rainbowSpeed=C("toolTintRainbowSpeed",3)
local transparency=C("toolTintTransparency",5)
local rainbowConn
local HIGHLIGHT_NAME="VisualsV2_ToolTint"

local function allTools()
    local result={}
    for _,container in ipairs({player.Character,player:FindFirstChildOfClass("Backpack")}) do
        if container then for _,obj in ipairs(container:GetChildren()) do if obj:IsA("Tool") then table.insert(result,obj) end end end
    end
    return result
end
local function colorNow()
    if rainbow then return Color3.fromHSV((os.clock()*((tonumber(rainbowSpeed) or 3)*0.1))%1,1,1) end
    return tintColor
end
local function fillAlpha()
    local v=math.clamp(tonumber(transparency) or 5,1,10)
    return 0.05+((v-1)/9)*0.85
end
local function removeHighlight(tool)
    if not tool then return end
    local h=tool:FindFirstChild(HIGHLIGHT_NAME)
    if h then h:Destroy() end
end
local function isGunKnife(tool)
    if not tool or not tool:IsA("Tool") then return false end
    local name=tool.Name:lower()
    return name=="gun" or name=="knife"
end

local function apply(tool)
    if not enabled or not tool or not tool:IsA("Tool") then return end
    if env.VisualsV2Runtime.GunsKnivesEnabled and isGunKnife(tool) then
        removeHighlight(tool)
        return
    end
    local h=tool:FindFirstChild(HIGHLIGHT_NAME)
    if not h then
        h=Instance.new("Highlight")
        h.Name=HIGHLIGHT_NAME
        h.Adornee=tool
        h.DepthMode=Enum.HighlightDepthMode.Occluded
        h.OutlineTransparency=1
        h.Parent=tool
    end
    h.FillColor=colorNow()
    h.FillTransparency=fillAlpha()
end
local function applyAll() for _,tool in ipairs(allTools()) do apply(tool) end end
local function restoreAll()
    if rainbowConn then rainbowConn:Disconnect(); rainbowConn=nil end
    for _,tool in ipairs(allTools()) do removeHighlight(tool) end
end
local function refreshAll()
    restoreAll()
    if enabled then applyAll() end
    if enabled and rainbow then rainbowConn=RunService.RenderStepped:Connect(applyAll) end
end
local function watch(container)
    if not container then return end
    container.ChildAdded:Connect(function(obj) if obj:IsA("Tool") and enabled then task.defer(function() apply(obj) end) end end)
end
watch(player:FindFirstChildOfClass("Backpack")); watch(player.Character)
player.CharacterAdded:Connect(function(char) watch(char); if enabled then task.defer(applyAll) end end)

env.VisualsV2Runtime.RefreshToolTint=refreshAll
env.VisualsV2Runtime.RestoreToolTintGunKnife=function()
    for _,tool in ipairs(allTools()) do
        if isGunKnife(tool) then removeHighlight(tool) end
    end
end

local enabledToggle=addToggle(section,"Enable Tool Tint",enabled,function(v)
    enabled=v
    SetCfg("toolTintEnabled",v)
    if v then refreshAll() else restoreAll() end
    if type(env.VisualsV2Runtime.RefreshGunsKnives)=="function" then
        pcall(env.VisualsV2Runtime.RefreshGunsKnives)
    end
end)
section:AddColorpicker("Tool Tint Color",tintColor,function(color)
    tintColor=color; SetCfg("toolTintColor",color); if enabled and not rainbow then applyAll() end
end)
local rainbowToggle=addToggle(section,"Rainbow Tool Tint",rainbow,function(v)
    rainbow=v
    SetCfg("toolTintRainbow",v)
    refreshAll()
    if type(env.VisualsV2Runtime.RefreshGunsKnives)=="function" then
        pcall(env.VisualsV2Runtime.RefreshGunsKnives)
    end
end)
section:AddSlider("Rainbow Speed",1,10,rainbowSpeed,function(v)
    rainbowSpeed=math.clamp(tonumber(v) or 3,1,10); SetCfg("toolTintRainbowSpeed",rainbowSpeed)
end)
section:AddSlider("Tint Transparency",1,10,transparency,function(v)
    transparency=math.clamp(tonumber(v) or 5,1,10); SetCfg("toolTintTransparency",transparency); if enabled then applyAll() end
end)

env.VisualsV2Runtime.RegisterReset(function()
    enabledToggle:Set(false); rainbowToggle:Set(false)
    enabled=false; rainbow=false; tintColor=Color3.fromRGB(255,255,255); rainbowSpeed=3; transparency=5
    restoreAll()
end)
end)()

-- =========================================================
-- VISUALS: CUSTOM CHAT COLORS
-- VISUALS: CUSTOM CHAT COLORS
-- Sound-related controls intentionally excluded.
-- =========================================================

;(function()
local section=mainTab:AddSection("Custom Chat","Visuals")
local enabled=C("chatColorEnabled",false)
local bubbleColor=C("chatBubbleColor",Color3.fromRGB(255,255,255))
local textColor=C("chatTextColor",Color3.fromRGB(0,0,0))
local originalBubble,originalText
local childConn

local function getConfig()
    return TextChatService:FindFirstChildOfClass("BubbleChatConfiguration") or TextChatService:FindFirstChild("BubbleChatConfiguration")
end
local function apply()
    local config=getConfig(); if not config then return end
    if originalBubble==nil then originalBubble=config.BackgroundColor3; originalText=config.TextColor3 end
    config.BackgroundColor3=bubbleColor; config.TextColor3=textColor
end
local function restore()
    local config=getConfig(); if not config then return end
    if originalBubble~=nil then config.BackgroundColor3=originalBubble end
    if originalText~=nil then config.TextColor3=originalText end
end
local function refreshWatcher()
    if childConn then childConn:Disconnect(); childConn=nil end
    if enabled then
        childConn=TextChatService.ChildAdded:Connect(function(child)
            if child:IsA("BubbleChatConfiguration") or child.Name=="BubbleChatConfiguration" then task.defer(apply) end
        end)
        apply()
    end
end

local enableToggle=addToggle(section,"Custom Chat Colors",enabled,function(v)
    enabled=v; SetCfg("chatColorEnabled",v); if v then refreshWatcher() else if childConn then childConn:Disconnect(); childConn=nil end; restore() end
end)
section:AddColorpicker("Chat Bubble Color",bubbleColor,function(color)
    bubbleColor=color; SetCfg("chatBubbleColor",color); if enabled then apply() end
end)
section:AddColorpicker("Chat Text Color",textColor,function(color)
    textColor=color; SetCfg("chatTextColor",color); if enabled then apply() end
end)

env.VisualsV2Runtime.RegisterReset(function()
    enableToggle:Set(false); enabled=false
    if childConn then childConn:Disconnect(); childConn=nil end
    restore()
end)
end)()

-- =========================================================
-- FIREFLY CLUTCH
-- Core behavior rebuilt directly from the attached FFC addon.
-- =========================================================

;(function()
local section=mainTab:AddSection("Firefly Clutch","Utilities")
section:AddParagraph(
    "Firefly Clutch",
    "Firefly Clutch needs to be enabled in the World section of ODH for this to work."
)

local ContextActionService=game:GetService("ContextActionService")
local autoClutch=C("fireflyAutoClutch",false)
local timerSize=math.clamp(tonumber(C("fireflyTimerSize",5)) or 5,1,10)
local COUNTDOWN=2.5
local COOLDOWN=16
local TRIGGER_POINT=0.23
local BURST_DURATION=0.5
local DEFAULT_POS=UDim2.new(0.5,0,0.10,0)

local gui,timerLabel
local countdownConnection,cooldownConnection,blockConnection,jumpBurstConnection
local toolConnection
local watchConnections={}
local isOnCooldown=false
local jumpTriggered=false
local jumpActionBound=false
local cycleStartedAt=nil
local countdownEndsAt=nil
local cooldownEndsAt=nil

local function disconnect(conn)
    if conn then pcall(function() conn:Disconnect() end) end
end

local function clearTimerGuis()
    local pg=player:FindFirstChildOfClass("PlayerGui")
    if not pg then return end
    for _,name in ipairs({"VisualsV2_FireflyTimer","FireflyTimerGui","FireflyCooldownGui"}) do
        local old=pg:FindFirstChild(name)
        if old and old~=gui then pcall(function() old:Destroy() end) end
    end
end

local function applyTimerSize()
    if not timerLabel then return end
    local width=72+((timerSize-1)*8)
    local height=24+((timerSize-1)*2)
    timerLabel.Size=UDim2.fromOffset(width,height)
    timerLabel.TextSize=math.max(12,math.floor(height*0.65))
end

local function buildTimer()
    if gui and gui.Parent and timerLabel then return end
    clearTimerGuis()

    gui=Instance.new("ScreenGui")
    gui.Name="VisualsV2_FireflyTimer"
    gui.ResetOnSpawn=false
    gui.IgnoreGuiInset=true
    gui.Parent=player:WaitForChild("PlayerGui")

    timerLabel=Instance.new("TextLabel")
    timerLabel.Name="FireflyTimer"
    timerLabel.AnchorPoint=Vector2.new(0.5,0.5)
    timerLabel.Position=loadStoredPosition("fireflyTimerPosition",DEFAULT_POS)
    timerLabel.BackgroundTransparency=1
    timerLabel.BorderSizePixel=0
    timerLabel.TextColor3=Color3.new(0,0,0)
    timerLabel.TextStrokeTransparency=1
    timerLabel.Font=Enum.Font.GothamBold
    timerLabel.Text=""
    timerLabel.Visible=false
    timerLabel.Active=true
    timerLabel.Parent=gui
    applyTimerSize()

    local dragging=false
    local moved=false
    local dragInput,dragStart,startPos

    timerLabel.InputBegan:Connect(function(input)
        if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
        dragging=true
        moved=false
        dragStart=input.Position
        startPos=timerLabel.Position
    end)
    timerLabel.InputChanged:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch then dragInput=input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging or input~=dragInput then return end
        local delta=input.Position-dragStart
        if delta.Magnitude>7 then moved=true end
        timerLabel.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y)
    end)
    UserInputService.InputEnded:Connect(function(input)
        if not dragging then return end
        if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
        dragging=false
        if moved then saveStoredPosition("fireflyTimerPosition",timerLabel.Position) end
    end)
end

local function bindJumpAction()
    if jumpActionBound then return end
    ContextActionService:BindAction(
        "FireflyAutoJump",
        function(_,inputState)
            if inputState==Enum.UserInputState.Begin then
                local char=player.Character
                local humanoid=char and char:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    humanoid.Jump=true
                    if humanoid.FloorMaterial~=Enum.Material.Air then
                        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                    end
                end
            end
            return Enum.ContextActionResult.Pass
        end,
        false,
        Enum.KeyCode.Space
    )
    jumpActionBound=true
end

local function unbindJumpAction()
    if not jumpActionBound then return end
    ContextActionService:UnbindAction("FireflyAutoJump")
    jumpActionBound=false
end

local function fireJump()
    local char=player.Character
    local humanoid=char and char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    humanoid.Jump=true
    if humanoid.FloorMaterial~=Enum.Material.Air then
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
    pcall(function()
        ContextActionService:CallAction("FireflyAutoJump",Enum.UserInputState.Begin)
    end)
end

local function stopJumpBurst()
    disconnect(jumpBurstConnection)
    jumpBurstConnection=nil
end

local function startJumpBurst()
    stopJumpBurst()
    local elapsed=0
    jumpBurstConnection=RunService.Heartbeat:Connect(function(dt)
        elapsed+=dt
        if elapsed>=BURST_DURATION then
            stopJumpBurst()
            return
        end
        fireJump()
    end)
end

local function stopCycle()
    disconnect(countdownConnection)
    disconnect(cooldownConnection)
    disconnect(blockConnection)
    countdownConnection=nil
    cooldownConnection=nil
    blockConnection=nil
    stopJumpBurst()
    isOnCooldown=false
    jumpTriggered=false
    cycleStartedAt=nil
    countdownEndsAt=nil
    cooldownEndsAt=nil
    if timerLabel then timerLabel.Visible=false; timerLabel.Text="" end
end

-- Same activation/cooldown/jump behavior as the attached FFC addon. The only
-- change is that both original timer panels are rendered in one transparent label.
local function startCountdown()
    if not autoClutch then return end
    buildTimer()
    disconnect(countdownConnection)
    countdownConnection=nil
    jumpTriggered=false
    timerLabel.Visible=true

    countdownConnection=RunService.Heartbeat:Connect(function()
        if not countdownEndsAt then return end
        local remaining=countdownEndsAt-os.clock()
        if remaining<=0 then
            disconnect(countdownConnection)
            countdownConnection=nil
            return
        end
        if not jumpTriggered and remaining<=TRIGGER_POINT then
            jumpTriggered=true
            startJumpBurst()
        end
        timerLabel.Text=string.format("%.1fCD",math.max(0,remaining))
    end)
end

local function startCooldownPanel()
    buildTimer()
    disconnect(cooldownConnection)
    cooldownConnection=nil
    cooldownConnection=RunService.Heartbeat:Connect(function()
        if not cycleStartedAt or not cooldownEndsAt then return end
        local now=os.clock()
        if countdownEndsAt and now<countdownEndsAt then return end
        local remaining=cooldownEndsAt-now
        if remaining<=0 then
            timerLabel.Text="Active"
            task.delay(0.6,function()
                if timerLabel and not isOnCooldown then timerLabel.Visible=false; timerLabel.Text="" end
            end)
            disconnect(cooldownConnection)
            cooldownConnection=nil
            return
        end
        timerLabel.Visible=true
        timerLabel.Text=string.format("%.1fCD",remaining)
    end)
end

local function startBlockTimer()
    isOnCooldown=true
    disconnect(blockConnection)
    blockConnection=nil
    blockConnection=RunService.Heartbeat:Connect(function()
        if cooldownEndsAt and os.clock()>=cooldownEndsAt then
            isOnCooldown=false
            disconnect(blockConnection)
            blockConnection=nil
        end
    end)
end

local function startOriginalCycle()
    if not autoClutch or isOnCooldown then return end
    buildTimer()
    cycleStartedAt=os.clock()
    countdownEndsAt=cycleStartedAt+COUNTDOWN
    cooldownEndsAt=cycleStartedAt+COOLDOWN
    startCountdown()
    startCooldownPanel()
    startBlockTimer()
end

local function connectToTool(tool)
    if not tool or not tool:IsA("Tool") or tool.Name~="Fireflies" then return end
    if toolConnection then disconnect(toolConnection); toolConnection=nil end
    toolConnection=tool.Activated:Connect(function()
        if not autoClutch or isOnCooldown then return end
        startOriginalCycle()
    end)
end

local function watchContainer(container)
    if not container then return end
    local tool=container:FindFirstChild("Fireflies")
    if tool then connectToTool(tool) end
    table.insert(watchConnections,container.ChildAdded:Connect(function(child)
        if child.Name=="Fireflies" and child:IsA("Tool") then connectToTool(child) end
    end))
end

local function hookTool()
    watchContainer(player:FindFirstChildOfClass("Backpack"))
    watchContainer(player.Character)
    table.insert(watchConnections,player.ChildAdded:Connect(function(child)
        if child:IsA("Backpack") then watchContainer(child) end
    end))
    table.insert(watchConnections,player.CharacterAdded:Connect(function(char)
        -- Do not reset an active cooldown/timer on respawn. Rebuild only if the
        -- PlayerGui was recreated and then keep the same timestamps.
        task.wait(0.2)
        buildTimer()
        watchContainer(char)
    end))
end

local function unhookTool()
    if toolConnection then disconnect(toolConnection); toolConnection=nil end
    for _,conn in ipairs(watchConnections) do disconnect(conn) end
    table.clear(watchConnections)
    disconnect(countdownConnection); countdownConnection=nil
    disconnect(cooldownConnection); cooldownConnection=nil
    disconnect(blockConnection); blockConnection=nil
    stopJumpBurst()
    unbindJumpAction()
    isOnCooldown=false
    jumpTriggered=false
    cycleStartedAt=nil
    countdownEndsAt=nil
    cooldownEndsAt=nil
    if timerLabel then timerLabel.Visible=false; timerLabel.Text="" end
end

local autoToggle=addToggle(section,"Auto Firefly Clutch",autoClutch,function(state)
    autoClutch=state
    SetCfg("fireflyAutoClutch",state)
    if state then
        buildTimer()
        bindJumpAction()
        unhookTool()
        -- unhookTool clears the jump binding, so bind again after cleanup.
        bindJumpAction()
        hookTool()
    else
        unhookTool()
    end
end)

section:AddSlider("Firefly Timer Size",1,10,timerSize,function(value)
    timerSize=math.clamp(tonumber(value) or 5,1,10)
    SetCfg("fireflyTimerSize",timerSize)
    applyTimerSize()
end)

section:AddButton("Reset Firefly Timer POS",function()
    PositionData["fireflyTimerPosition"]={xs=DEFAULT_POS.X.Scale,xo=DEFAULT_POS.X.Offset,ys=DEFAULT_POS.Y.Scale,yo=DEFAULT_POS.Y.Offset}
    saveConfig()
    if timerLabel then timerLabel.Position=DEFAULT_POS end
end)

env.VisualsV2Runtime.RegisterReset(function()
    autoToggle:Set(false)
    autoClutch=false
    unhookTool()
    if gui then gui:Destroy(); gui=nil; timerLabel=nil end
end)

buildTimer()
if autoClutch then
    bindJumpAction()
    hookTool()
end
end)()

-- =========================================================
-- SCREEN
-- =========================================================

;(function()
local screenSection = mainTab:AddSection("Screen", "Visuals")
local stretchScreenEnabled = C("stretchScreenEnabled", false)
local STRETCH_FACTOR = 0.65

local stretchToggle = addToggle(screenSection, "Stretch Screen", stretchScreenEnabled, function(state)
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

env.VisualsV2Runtime.RegisterReset(function()
    stretchToggle:Set(false)
    stretchScreenEnabled = false
end)

end)()

-- =========================================================
-- WORLD
-- =========================================================

;(function()
local worldSection=mainTab:AddSection("Environment","World")

-- Environment behavior restored from the attached Nexium source. The only UI
-- adaptation retained is the saved Time of Day preset dropdown requested earlier.
local savedFogStart=Lighting.FogStart
local savedFogEnd=Lighting.FogEnd
local savedFogColor=Lighting.FogColor
local fullbrightEnabled=C("fullbrightEnabled",false)
local ambientColor=C("ambientColor",Lighting.Ambient)
local exposure=C("exposure",Lighting.ExposureCompensation)
local fogEnabled=false
local applyFog=nil

local TIME_PRESETS={
    ["Default"]=12,
    ["Morning"]=8,
    ["Day"]=12,
    ["Afternoon"]=15,
    ["Evening"]=18,
    ["Night"]=21,
    ["Midnight"]=0,
}
local TIME_PRESET_NAMES={"Default","Morning","Day","Afternoon","Evening","Night","Midnight"}
local timePreset=C("timePreset","Default")
if TIME_PRESETS[timePreset]==nil then timePreset="Default" end

local function applyTimePreset()
    if fullbrightEnabled then return end
    local value=TIME_PRESETS[timePreset] or 12
    Lighting.ClockTime=value
    pcall(function()
        local hour=math.floor(value)%24
        local minute=math.floor((value-hour)*60+0.5)%60
        Lighting.TimeOfDay=string.format("%02d:%02d:00",hour,minute)
    end)
end

local function applyFullbright()
    Lighting.Brightness=2
    Lighting.ClockTime=14
    Lighting.FogEnd=100000
    Lighting.GlobalShadows=false
    Lighting.Ambient=Color3.fromRGB(255,255,255)
    Lighting.OutdoorAmbient=Color3.fromRGB(255,255,255)
end

local function disableFullbright()
    -- Match Nexium's working off-state, while preserving this add-on's selected
    -- ambient/exposure/preset values.
    Lighting.Brightness=1
    Lighting.GlobalShadows=true
    Lighting.FogEnd=savedFogEnd
    Lighting.Ambient=ambientColor
    Lighting.OutdoorAmbient=ambientColor
    Lighting.ExposureCompensation=exposure
    applyTimePreset()
end

local fullbrightToggle=addToggle(worldSection,"Fullbright",fullbrightEnabled,function(state)
    fullbrightEnabled=state
    SetCfg("fullbrightEnabled",state)
    if state then
        applyFullbright()
    else
        disableFullbright()
        if fogEnabled and applyFog then applyFog() end
    end
end)

worldSection:AddColorpicker("Ambient Color",ambientColor,function(color)
    ambientColor=color
    SetCfg("ambientColor",color)
    if not fullbrightEnabled then
        Lighting.Ambient=color
        Lighting.OutdoorAmbient=color
    end
end)

addDropdown(worldSection,"Time of Day Preset",TIME_PRESET_NAMES,timePreset,function(value)
    timePreset=value
    SetCfg("timePreset",value)
    applyTimePreset()
end)

worldSection:AddSlider("Exposure",-2,5,exposure,function(value)
    exposure=value
    SetCfg("exposure",value)
    Lighting.ExposureCompensation=value
end)

if fullbrightEnabled then applyFullbright() else disableFullbright() end

local fogSection=mainTab:AddSection("Fog","World")
fogEnabled=C("fogEnabled",false)
local fogRainbow=C("fogRainbow",false)
local fogColor=C("fogColor",Color3.fromRGB(255,255,255))
local fogStart=math.max(0,tonumber(C("fogStart",0)) or 0)
local fogEnd=math.max(50,tonumber(C("fogEnd",50)) or 50)

applyFog=function()
    Lighting.FogStart=fogStart
    Lighting.FogEnd=math.max(fogStart+1,fogEnd)
    Lighting.FogColor=fogRainbow and Color3.fromHSV((os.clock()%5)/5,1,1) or fogColor
end

local fogToggle=addToggle(fogSection,"Enable Beautiful Fog",fogEnabled,function(state)
    fogEnabled=state
    SetCfg("fogEnabled",state)
    if state then
        if not fullbrightEnabled then applyFog() end
    else
        Lighting.FogStart=savedFogStart
        Lighting.FogEnd=savedFogEnd
        Lighting.FogColor=savedFogColor
    end
end)

local rainbowFogToggle=addToggle(fogSection,"Rainbow Fog",fogRainbow,function(state)
    fogRainbow=state
    SetCfg("fogRainbow",state)
    if fogEnabled and not fullbrightEnabled then applyFog() end
end)

fogSection:AddSlider("Fog Distance",50,2000,fogEnd,function(value)
    fogEnd=value
    SetCfg("fogEnd",value)
    if fogEnabled and not fullbrightEnabled then applyFog() end
end)

fogSection:AddSlider("Fog Start",0,500,fogStart,function(value)
    fogStart=value
    SetCfg("fogStart",value)
    if fogEnabled and not fullbrightEnabled then applyFog() end
end)

fogSection:AddColorpicker("Fog Color",fogColor,function(color)
    fogColor=color
    SetCfg("fogColor",color)
    if fogEnabled and not fogRainbow and not fullbrightEnabled then applyFog() end
end)

RunService.RenderStepped:Connect(function()
    if fogEnabled and fogRainbow and not fullbrightEnabled then
        Lighting.FogColor=Color3.fromHSV((os.clock()%5)/5,1,1)
    end
end)

-- Skybox dropdown. Nexium entries retain their original asset IDs. Additional
-- six-face presets are kept only when they do not duplicate a Nexium name.
local skyboxSection=mainTab:AddSection("Skyboxes","Visuals")
local currentSky=Lighting:FindFirstChildOfClass("Sky")
env.VisualsV2OriginalSky=currentSky and currentSky:Clone() or false
local originalSky=env.VisualsV2OriginalSky

local skyCheckConnection
local selectedSkybox=C("selectedSkybox","Default")

local SKYBOX_PRESETS={
    ["Orange Skybox"]="627302570",
    ["FPS+ Skybox"]="582303304",
    ["Space Skybox"]="15619750970",
    ["Green Skybox"]="348361280",
    ["Blue Skybox"]="130093177270069",
    ["Purple Skybox"]="83555979203508",
    ["Red Skybox"]="401666131",
    ["HD Skybox"]="16823410580",
    ["Night Skybox"]="12064636",
    ["Galactic Skybox"]="10542194896",
    ["Winter Skybox"]="96628448286151",
    ["Saturn Skybox"]="1898754079",
    ["Outrun Skybox"]="3441770362",
    ["Cyan Space Skybox"]="367149630",
    ["City Skybox"]="117205995214134",
    ["Green Skybox 2.0"]="16823294549",
    ["Obama Skybox (Joke)"]="2362934358",
    ["SpongeBob Skybox"]="114523453023009",
    ["Purple Nebula Skybox"]="230057997",
    ["Bart Skybox"]="119891349513795",
    ["Sunless Blue Sky"]="591067775",
    ["Weirdcore Eye Skybox"]="11372740893",
    ["Minecraft Skybox"]="5087871978",
    ["Frutiger Aero Skybox"]="97046110924083",
    ["Cyberpunk Skybox"]="13689001090",
    ["Dark Red Castle Skybox"]="15832476802",
    ["Cartoon Skybox"]="107689530722429",
    ["Error Skybox"]="13710730784",
    ["Abyssal Blues Skybox"]="16269853692",
    ["Earth Skybox"]="266878339",
    ["Black & White Fade Skybox"]="6213224205",
    ["Purple Skybox 2"]="8107887936",
    ["Green Nebula Space"]="89018019804256",
    ["HD Rainbow Skybox"]="18915196644",
    ["Meadow Skybox"]="848241313",
    ["Pink Sky Skybox"]="107689530722174",
    ["Venus Skybox V2"]="110450592899174",

    ["Realistic Sky"]={"144933338","144931530","144933262","144933244","144933299","144931564"},
    ["Purple Nighty #1"]={"159454299","159454296","159454293","159454286","159454300","159454288"},
    ["Purple Nighty #2"]={"14543264135","14543358958","14543257810","14543275895","14543280890","14543371676"},
    ["Sunset"]={"15502525195","15502522797","15502524520","15502522129","15502523711","15502526102"},
    ["Nighty Sky"]={"168387023","168387089","168387054","168534432","168387190","168387135"},
    ["Sunset Sky"]={"458016711","458016826","458016532","458016655","458016782","458016792"},
    ["Night Fog"]={"1370717244","1370717336","1370717438","1370717567","1370717698","1370717782"},
    ["Blood Moon"]={"401664839","401664862","401664960","401664881","401664901","401664936"},
    ["Pink Blossom"]={"271042516","271077243","271042556","271042310","271042467","271077958"},
    ["Purple Sunset"]={"264908339","264907909","264909420","264909758","264908886","264907379"},
    ["Void Sky"]={"16262356578","16262358026","16262360469","16262362003","16262363873","16262366016"},
    ["Purple Night"]={"5084575798","5084575916","5103949679","5103948542","5103948784","5084576400"},
    ["Realistic Moon"]={"2670643994","2670643365","2670643214","2670643070","2670644173","2670644331"},
}

if selectedSkybox~="Default" and SKYBOX_PRESETS[selectedSkybox]==nil then
    selectedSkybox="Default"
    ConfigData["selectedSkybox"]="Default"
end

local SKYBOX_NAMES={
    "Default",
    "Orange Skybox","FPS+ Skybox","Space Skybox","Green Skybox","Blue Skybox",
    "Purple Skybox","Red Skybox","HD Skybox","Night Skybox","Galactic Skybox",
    "Winter Skybox","Saturn Skybox","Outrun Skybox","Cyan Space Skybox","City Skybox",
    "Green Skybox 2.0","Obama Skybox (Joke)","SpongeBob Skybox","Purple Nebula Skybox",
    "Bart Skybox","Sunless Blue Sky","Weirdcore Eye Skybox","Minecraft Skybox",
    "Frutiger Aero Skybox","Cyberpunk Skybox","Dark Red Castle Skybox","Cartoon Skybox",
    "Error Skybox","Abyssal Blues Skybox","Earth Skybox",
    "Black & White Fade Skybox","Purple Skybox 2","Green Nebula Space","HD Rainbow Skybox",
    "Meadow Skybox","Pink Sky Skybox","Venus Skybox V2",
    "Realistic Sky","Purple Nighty #1","Purple Nighty #2","Sunset","Nighty Sky",
    "Sunset Sky","Night Fog","Blood Moon","Pink Blossom","Purple Sunset",
    "Void Sky","Purple Night","Realistic Moon",
}

local function clearSky()
    for _,obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("Sky") then obj:Destroy() end
    end
end

local function restoreSky()
    clearSky()
    if typeof(originalSky)=="Instance" then
        originalSky:Clone().Parent=Lighting
    end
end

local function markSky(sky,name)
    if sky then pcall(function() sky:SetAttribute("VisualsV2SkyboxPreset",name) end) end
end

local function applySingleAsset(assetId,name)
    clearSky()

    local ok,asset=pcall(function()
        return game:GetObjects("rbxassetid://"..tostring(assetId))[1]
    end)

    if ok and asset then
        if asset:IsA("Sky") then
            markSky(asset,name)
            asset.Parent=Lighting
            return true
        end

        local nested=asset:FindFirstChildWhichIsA("Sky",true)
        if nested then
            local sky=nested:Clone()
            markSky(sky,name)
            sky.Parent=Lighting
            pcall(function() asset:Destroy() end)
            return true
        end

        pcall(function() asset:Destroy() end)
    end

    -- Original Nexium fallback.
    local sky=Instance.new("Sky")
    local id="rbxassetid://"..tostring(assetId)
    sky.SkyboxBk=id
    sky.SkyboxDn=id
    sky.SkyboxFt=id
    sky.SkyboxLf=id
    sky.SkyboxRt=id
    sky.SkyboxUp=id
    markSky(sky,name)
    sky.Parent=Lighting
    return true
end

local function applySixFace(ids,name)
    clearSky()
    local sky=Instance.new("Sky")
    sky.SkyboxBk="rbxassetid://"..ids[1]
    sky.SkyboxDn="rbxassetid://"..ids[2]
    sky.SkyboxFt="rbxassetid://"..ids[3]
    sky.SkyboxLf="rbxassetid://"..ids[4]
    sky.SkyboxRt="rbxassetid://"..ids[5]
    sky.SkyboxUp="rbxassetid://"..ids[6]
    markSky(sky,name)
    sky.Parent=Lighting
    return true
end

local function applySelectedSkybox()
    if selectedSkybox=="Default" or SKYBOX_PRESETS[selectedSkybox]==nil then
        restoreSky()
        return
    end

    local data=SKYBOX_PRESETS[selectedSkybox]
    if type(data)=="table" then
        applySixFace(data,selectedSkybox)
    else
        applySingleAsset(data,selectedSkybox)
    end
end

local function refreshSkyWatcher()
    if skyCheckConnection then
        skyCheckConnection:Disconnect()
        skyCheckConnection=nil
    end

    if selectedSkybox=="Default" then return end

    skyCheckConnection=Lighting.ChildAdded:Connect(function(child)
        if child:IsA("Sky") then
            task.defer(function()
                local current=Lighting:FindFirstChildOfClass("Sky")
                local tag
                pcall(function() tag=current and current:GetAttribute("VisualsV2SkyboxPreset") end)
                if tag~=selectedSkybox then
                    applySelectedSkybox()
                end
            end)
        end
    end)
end

addDropdown(skyboxSection,"Skybox",SKYBOX_NAMES,selectedSkybox,function(value)
    selectedSkybox=value
    SetCfg("selectedSkybox",value)
    applySelectedSkybox()
    refreshSkyWatcher()
end)

task.defer(function()
    applySelectedSkybox()
    refreshSkyWatcher()
end)

if fogEnabled and not fullbrightEnabled then applyFog() end

env.VisualsV2Runtime.RegisterReset(function()
    fullbrightToggle:Set(false)
    fogToggle:Set(false)
    rainbowFogToggle:Set(false)
    fullbrightEnabled=false
    fogEnabled=false
    fogRainbow=false
    if skyCheckConnection then skyCheckConnection:Disconnect(); skyCheckConnection=nil end
    restoreSky()
    fullbrightEnabled=false
    disableFullbright()
end)
end)()

-- =========================================================
-- MISCELLANEOUS
-- =========================================================

;(function()
local miscSection=mainTab:AddSection("Miscellaneous","Settings")
addToggle(miscSection,"Lock Big Button POS",lockBigButtonPos,function(state)
    lockBigButtonPos=state
    SetCfg("lockBigButtonPos",state)
end)
addToggle(miscSection,"Lock Bind Button POS",lockBindButtonPos,function(state)
    lockBindButtonPos=state
    SetCfg("lockBindButtonPos",state)
    BindableButtons:SetLocked("VisualsV2_SpeedBind",state)
end)
end)()

-- Reapply local cosmetic state after respawn.
local function onCharacterAdded(char)
    task.wait(1)
    characterOriginal=setmetatable({}, {__mode="k"})
    if trailEnabled then createTrail() end
    if ffEnabled then applyForceField(); refreshForceFieldConnection() end
    if skinTrailEnabled then applySkinTrail(); refreshSkinTrailRainbowConnection() end
    if auraEnabled then applyAura() end
    if headlessEnabled then applyCharacterVisuals() end
    setupJumpCircles(char)
    task.delay(0.5,setupSpeedButtons)
end
if player.Character then task.defer(function() onCharacterAdded(player.Character) end) end
player.CharacterAdded:Connect(onCharacterAdded)

saveConfig()

saveConfig()
shared.Notify("Visions V2 loaded",2)
