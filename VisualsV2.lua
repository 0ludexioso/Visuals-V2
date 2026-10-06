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
local TextChatService = game:GetService("TextChatService")

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

-- Runtime reset registry. Reset All Settings clears the file AND turns off
-- currently running effects, while ordinary setting changes are saved at once.
env.VisualsV2Runtime = env.VisualsV2Runtime or {}
env.VisualsV2Runtime.Resetters = {}
env.VisualsV2Runtime.RegisterReset = function(callback)
    if type(callback) == "function" then
        table.insert(env.VisualsV2Runtime.Resetters, callback)
    end
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
    local hatTransparency = C("hatTransparency", 0.3)
    local hatRainbow = C("hatRainbow", false)
    local hatDualColor = C("hatDualColor", false)
    local hatColor = C("hatColor", Color3.fromRGB(0, 255, 255))
    local hatColor1 = C("hatColor1", Color3.fromRGB(0, 255, 255))
    local hatColor2 = C("hatColor2", Color3.fromRGB(255, 0, 255))
    local hatSize = C("hatSize", 1)
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

        hatPart.Transparency = math.clamp(tonumber(hatTransparency) or 0.3, 0, 1)
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
        hat.Transparency = math.clamp(tonumber(hatTransparency) or 0.3, 0, 1)
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

    hatSection:AddSlider("Transparency", 0, 1, hatTransparency, function(value)
        hatTransparency = math.clamp(tonumber(value) or 0.3, 0, 1)
        SetCfg("hatTransparency", hatTransparency)
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

    hatSection:AddSlider("Hat Size", 0.5, 3, hatSize, function(value)
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
        hatTransparency = 0.3
        hatColor = Color3.fromRGB(0, 255, 255)
        hatColor1 = Color3.fromRGB(0, 255, 255)
        hatColor2 = Color3.fromRGB(255, 0, 255)
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
local trailColorStatic = C("trailColorStatic", Color3.fromRGB(0, 255, 255))
local trailGradient1 = C("trailGradient1", Color3.fromRGB(0, 86, 255))
local trailGradient2 = C("trailGradient2", Color3.fromRGB(255, 0, 0))
local trailLifetime = C("trailLifetime", 0.5)
local trailTransparencyStart = C("trailTransparency", 1)
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
        NumberSequenceKeypoint.new(0, math.clamp((tonumber(trailTransparencyStart) or 1) / 5, 0, 1)),
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

trailSection:AddSlider("Trail Lifetime", 0.1, 3, trailLifetime, function(value)
    trailLifetime = value
    SetCfg("trailLifetime", value)
    updateTrail()
end)

trailSection:AddSlider("Trail Transparency", 1, 5, trailTransparencyStart, function(value)
    value = math.clamp(math.floor((tonumber(value) or 1) + 0.5), 1, 5)
    trailTransparencyStart = value
    SetCfg("trailTransparency", value)
    updateTrail()
end)

env.VisualsV2Runtime.RegisterReset(function()
    trailEnableToggle:Set(false)
    trailGradientToggle:Set(false)
    trailRainbowToggle:Set(false)
    trailEnabled = false
    trailIsGradient = false
    trailRainbow = false
    if trailConnection then trailConnection:Disconnect(); trailConnection = nil end
    removeTrail()
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
local skinTrailTransparency = C("skinTrailTransparency", 0.0)
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

skinSection:AddSlider("Skin Trail Lifetime", 0.1, 3.0, skinTrailLife, function(value)
    skinTrailLife = value
    SetCfg("skinTrailLife", value)
    if skinTrailEnabled then updateSkinTrail() end
end)

skinSection:AddSlider("Skin Transparency", 0.0, 4.0, skinTrailTransparency, function(value)
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

    -- These two are restored to the original Nexium implementation.
    if auraType == "Pink Aura" or auraType == "Super Sayien" then
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
env.VisualsV2Runtime.RegisterReset(function()
    jumpEnableToggle:Set(false)
    jumpRainbowToggle:Set(false)
    jumpCirclesEnabled = false
    jumpCircleRainbow = false
    local char = player.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if humanoid and jumpConnection then pcall(function() jumpConnection:Disconnect() end) end
end)

-- =========================================================
-- COSMETIC: CHARACTER
-- =========================================================

local characterSection = mainTab:AddSection("Character", "Cosmetic")
-- Migrate the previous single Korblox setting to the right-leg setting.
local korbloxRightEnabled = C("korbloxRightEnabled", C("korbloxEnabled", false))
local korbloxLeftEnabled = C("korbloxLeftEnabled", false)
local headlessEnabled = C("headlessEnabled", false)
local characterOriginal = setmetatable({}, {__mode = "k"})

characterSection:AddParagraph(
    "Character Appearance",
    "Headless and Korblox are local/client-sided appearance changes. Other players will not see them"
)

local function rememberCharacterObject(obj)
    if not obj or characterOriginal[obj] then return end
    if obj:IsA("BasePart") then
        local data = {
            Transparency = obj.Transparency,
            LocalTransparencyModifier = obj.LocalTransparencyModifier,
        }
        if obj:IsA("MeshPart") then
            pcall(function() data.MeshId = obj.MeshId end)
            pcall(function() data.TextureID = obj.TextureID end)
        end
        characterOriginal[obj] = data
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
        if obj:IsA("MeshPart") then
            if data.MeshId ~= nil then pcall(function() obj.MeshId = data.MeshId end) end
            if data.TextureID ~= nil then pcall(function() obj.TextureID = data.TextureID end) end
        end
    elseif obj:IsA("Decal") then
        pcall(function() obj.Transparency = data.Transparency end)
    end
end

local function applyKorbloxVisual(char, side, enabled)
    local upper = char and char:FindFirstChild(side .. "UpperLeg")
    local lower = char and char:FindFirstChild(side .. "LowerLeg")
    local foot = char and char:FindFirstChild(side .. "Foot")

    for _, part in ipairs({upper, lower, foot}) do
        if part then rememberCharacterObject(part) end
    end

    if not enabled then
        for _, part in ipairs({upper, lower, foot}) do
            if part then restoreCharacterObject(part) end
        end
        return
    end

    local meshData
    if side == "Right" then
        meshData = {
            {upper, "rbxassetid://902942096", "rbxassetid://902843398"},
            {lower, "rbxassetid://902942093", "rbxassetid://902843398"},
            {foot,  "rbxassetid://902942089", "rbxassetid://902843398"},
        }
    else
        -- Client-side left-leg counterpart. Keep all three parts visible so
        -- enabling it does not make the whole leg disappear.
        meshData = {
            {upper, "rbxassetid://101851582", "rbxassetid://101851582"},
            {lower, "rbxassetid://101851582", "rbxassetid://101851582"},
            {foot,  "rbxassetid://101851582", "rbxassetid://101851582"},
        }
    end

    for _, entry in ipairs(meshData) do
        local part, meshId, textureId = entry[1], entry[2], entry[3]
        if part and part:IsA("MeshPart") then
            pcall(function() part.MeshId = meshId end)
            pcall(function() part.TextureID = textureId end)
            part.Transparency = 0
            part.LocalTransparencyModifier = 0
        end
    end
end

local function applyCharacterVisuals()
    local char = player.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not char or not humanoid then return end
    if humanoid.RigType ~= Enum.HumanoidRigType.R15 then return end

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
                if headlessEnabled then obj.Transparency = 1 else restoreCharacterObject(obj) end
            end
        end
    end

    applyKorbloxVisual(char, "Right", korbloxRightEnabled)
    applyKorbloxVisual(char, "Left", korbloxLeftEnabled)
end

-- Keep the two Korblox controls directly next to each other in the section.
local korbloxRightToggle = addToggle(characterSection, "Korblox - Right Leg", korbloxRightEnabled, function(state)
    korbloxRightEnabled = state
    SetCfg("korbloxRightEnabled", state)
    applyCharacterVisuals()
end)

local korbloxLeftToggle = addToggle(characterSection, "Korblox - Left Leg", korbloxLeftEnabled, function(state)
    korbloxLeftEnabled = state
    SetCfg("korbloxLeftEnabled", state)
    applyCharacterVisuals()
end)

local headlessToggle = addToggle(characterSection, "Headless", headlessEnabled, function(state)
    headlessEnabled = state
    SetCfg("headlessEnabled", state)
    applyCharacterVisuals()
end)

env.VisualsV2Runtime.RegisterReset(function()
    korbloxRightToggle:Set(false)
    korbloxLeftToggle:Set(false)
    headlessToggle:Set(false)
    korbloxRightEnabled = false
    korbloxLeftEnabled = false
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
local speedButtonWidth = C("speedButtonWidth", 120)
local speedButtonHeight = C("speedButtonHeight", 44)
local speedButtonColor = C("speedButtonColor", Color3.fromRGB(0, 0, 0))
local speedButtonTransparency = C("speedButtonTransparency", 3.6) -- UI 1-5
if tonumber(speedButtonTransparency) and speedButtonTransparency < 1 then speedButtonTransparency = 1 + (speedButtonTransparency * 4) end
local speedButtonOutlineColor = C("speedButtonOutlineColor", Color3.fromRGB(255, 255, 255))
local speedButtonOutlineTransparency = C("speedButtonOutlineTransparency", 0.25)
local speedBindButtonVisible = C("speedBindButtonVisible", false)
local speedBindButtonSize = C("speedBindButtonSize", 5) -- UI 1-10
if tonumber(speedBindButtonSize) and speedBindButtonSize < 1 then speedBindButtonSize = 5 end
local speedBindButtonTransparency = C("speedBindButtonTransparency", 1) -- UI 1-5
if tonumber(speedBindButtonTransparency) and speedBindButtonTransparency < 1 then speedBindButtonTransparency = 1 + (speedBindButtonTransparency * 4) end
local lockBigButtonPos = C("lockBigButtonPos", false)
local lockBindButtonPos = C("lockBindButtonPos", false)
local speedGui, speedButton, speedButtonStroke, speedToggle
local BIG_BUTTON_DEFAULT = UDim2.new(0.5, -60, 0.22, 0)
local BIND_BUTTON_DEFAULT = UDim2.new(0.10, 0, 0.72, 0)

local function loadStoredPosition(key, fallback)
    local data = C(key, nil)
    if type(data) ~= "table" then return fallback end
    return UDim2.new(
        tonumber(data.XS) or fallback.X.Scale,
        tonumber(data.XO) or fallback.X.Offset,
        tonumber(data.YS) or fallback.Y.Scale,
        tonumber(data.YO) or fallback.Y.Offset
    )
end

local function saveStoredPosition(key, pos)
    SetCfg(key, {XS=pos.X.Scale, XO=pos.X.Offset, YS=pos.Y.Scale, YO=pos.Y.Offset})
end

local function fiveStepTransparency(value)
    return math.clamp(((tonumber(value) or 1) - 1) / 4, 0, 1)
end

-- Bindable Buttons API used by the plugin's visual editor and SG button.
local BindableButtons = {Buttons={}, Values={}, Connections={}, Locked={}}
local BIND_SHAPES = {
    [0]="rbxassetid://86221076925479",
    [1]="rbxassetid://96242665417546",
    [2]="rbxassetid://97129189935336",
    [3]="rbxassetid://76165862027868",
    [4]="rbxassetid://125868092127496",
}
local BIND_NORMAL_COLOR = ColorSequence.new(Color3.fromRGB(120,120,120))
local BIND_ACTIVE_COLOR = ColorSequence.new(Color3.fromRGB(255,255,255))

local function getBindStorage()
    local parent
    pcall(function() if gethui then parent = gethui() end end)
    if not parent then pcall(function() parent = game:GetService("CoreGui") end) end
    if not parent then parent = player:WaitForChild("PlayerGui") end
    local storage = parent:FindFirstChild("@bindstorage")
    if not storage then
        storage = Instance.new("ScreenGui")
        storage.Name = "@bindstorage"
        storage.ResetOnSpawn = false
        storage.IgnoreGuiInset = true
        storage.Parent = parent
    end
    return storage
end

function BindableButtons:DeleteBButton(id)
    local list = self.Connections[id]
    if list then for _, c in ipairs(list) do pcall(function() c:Disconnect() end) end end
    local button = self.Buttons[id]
    if button then pcall(function() button:Destroy() end) end
    self.Buttons[id], self.Values[id], self.Connections[id], self.Locked[id] = nil, nil, nil, nil
end
function BindableButtons:SetShape(id, shape)
    local b=self.Buttons[id]; if b and BIND_SHAPES[shape] then b.Image=BIND_SHAPES[shape] end
end
function BindableButtons:SetLocked(id, state) self.Locked[id]=not not state end
function BindableButtons:SetVisible(id, state) local b=self.Buttons[id]; if b then b.Visible=not not state end end
function BindableButtons:SetText(id, text) local b=self.Buttons[id]; local l=b and b:FindFirstChild("@Text"); if l then l.Text=tostring(text or "") end end
function BindableButtons:SetPosition(id, pos) local b=self.Buttons[id]; if b then b.Position=pos end end
function BindableButtons:GetPosition(id) local b=self.Buttons[id]; return b and b.Position or nil end
function BindableButtons:SetSize(id, level)
    local b=self.Buttons[id]; if not b then return end
    level=math.clamp(tonumber(level) or 5,1,10)
    local px=36+((level-1)*7)
    b.Size=UDim2.fromOffset(px,px)
end
function BindableButtons:SetTransparency(id, level)
    local b=self.Buttons[id]; if not b then return end
    b.ImageTransparency=fiveStepTransparency(level)
end
function BindableButtons:SetValue(id, state, runCallback)
    local value=self.Values[id]; local b=self.Buttons[id]; if not value or not b then return end
    state=not not state
    if value.Value~=state then
        value.Value=state
        if runCallback then
            local callbacks=b:GetAttribute("VisualsV2_CallbackMode")
        end
    end
    local stroke=b:FindFirstChild("@Stroke")
    if stroke and stroke:IsA("UIGradient") then stroke.Color=state and BIND_ACTIVE_COLOR or BIND_NORMAL_COLOR end
end

function BindableButtons.AddBButton(id, text, onCallback, offCallback, onMoved)
    local storage=getBindStorage()
    local old=storage:FindFirstChild(id); if old then old:Destroy() end
    BindableButtons:DeleteBButton(id)

    local b=Instance.new("ImageButton")
    b.Name=id
    b.AnchorPoint=Vector2.new(0.5,0.5)
    b.BackgroundTransparency=1
    b.BorderSizePixel=0
    b.AutoButtonColor=false
    b.Image=BIND_SHAPES[1]
    b.Parent=storage

    local value=Instance.new("BoolValue")
    value.Name="BindValue"
    value.Value=false
    value.Parent=b

    local label=Instance.new("TextLabel")
    label.Name="@Text"
    label.Size=UDim2.fromScale(0.82,0.82)
    label.Position=UDim2.fromScale(0.5,0.5)
    label.AnchorPoint=Vector2.new(0.5,0.5)
    label.BackgroundTransparency=1
    label.Font=Enum.Font.Jura
    label.Text=tostring(text or "")
    label.TextColor3=Color3.new(1,1,1)
    label.TextScaled=true
    label.TextStrokeTransparency=1
    label.ZIndex=3
    label.Parent=b

    local aspect=Instance.new("UIAspectRatioConstraint")
    aspect.AspectRatio=1
    aspect.Parent=b

    local stroke=Instance.new("UIGradient")
    stroke.Name="@Stroke"
    stroke.Color=BIND_NORMAL_COLOR
    stroke.Parent=b

    BindableButtons.Buttons[id]=b
    BindableButtons.Values[id]=value
    BindableButtons.Connections[id]={}
    BindableButtons.Locked[id]=false

    local dragging=false
    local moved=false
    local dragInput, dragStart, startPos
    local conns=BindableButtons.Connections[id]

    table.insert(conns,b.InputBegan:Connect(function(input)
        if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
        dragging=true; moved=false; dragStart=input.Position; startPos=b.Position
    end))
    table.insert(conns,b.InputChanged:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch then dragInput=input end
    end))
    table.insert(conns,UserInputService.InputChanged:Connect(function(input)
        if not dragging or input~=dragInput or BindableButtons.Locked[id] then return end
        local delta=input.Position-dragStart
        if delta.Magnitude>7 then moved=true end
        b.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y)
    end))
    table.insert(conns,UserInputService.InputEnded:Connect(function(input)
        if not dragging then return end
        if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
        dragging=false
        if moved and not BindableButtons.Locked[id] then
            if onMoved then pcall(onMoved,b.Position) end
        else
            value.Value=not value.Value
            stroke.Color=value.Value and BIND_ACTIVE_COLOR or BIND_NORMAL_COLOR
            if value.Value then pcall(onCallback) else pcall(offCallback) end
        end
    end))

    return value
end

local function updateSpeedButtonStyle()
    if speedButton then
        speedButton.Size=UDim2.fromOffset(speedButtonWidth,speedButtonHeight)
        speedButton.BackgroundColor3=speedButtonColor
        speedButton.BackgroundTransparency=fiveStepTransparency(speedButtonTransparency)
        speedButton.Text=speedEnabled and "ACTIVE" or ""
        speedButton.TextScaled=false
        speedButton.TextSize=math.max(10,math.floor(speedButtonHeight*0.38))
        speedButton.TextStrokeTransparency=1
        speedButton.Visible=speedButtonVisible
    end
    if speedButtonStroke then
        speedButtonStroke.Color=speedButtonOutlineColor
        speedButtonStroke.Transparency=math.clamp(speedButtonOutlineTransparency,0,1)
    end
    local id="VisualsV2_SpeedBind"
    BindableButtons:SetVisible(id,speedBindButtonVisible)
    BindableButtons:SetLocked(id,lockBindButtonPos)
    BindableButtons:SetSize(id,speedBindButtonSize)
    BindableButtons:SetTransparency(id,speedBindButtonTransparency)
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
    local stroke=Instance.new("UIStroke")
    stroke.Thickness=1.5
    stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
    stroke.Parent=big
    speedButtonStroke=stroke
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

speedSection:AddKeybind("Speed Glitch Bind","G",function()
    setSpeedState(not speedEnabled)
end)

addToggle(speedSection,"Show Big Button",speedButtonVisible,function(state)
    speedButtonVisible=state
    SetCfg("speedButtonVisible",state)
    updateSpeedButtonStyle()
end)
addToggle(speedSection,"Show Bindable Button",speedBindButtonVisible,function(state)
    speedBindButtonVisible=state
    SetCfg("speedBindButtonVisible",state)
    updateSpeedButtonStyle()
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
speedSection:AddSlider("Big Button Transparency",1.0,5.0,speedButtonTransparency,function(value)
    speedButtonTransparency=math.clamp(tonumber(value) or 1,1,5)
    SetCfg("speedButtonTransparency",speedButtonTransparency)
    updateSpeedButtonStyle()
end)
speedSection:AddColorpicker("Big Button Outline Color",speedButtonOutlineColor,function(color)
    speedButtonOutlineColor=color; SetCfg("speedButtonOutlineColor",color); updateSpeedButtonStyle()
end)
speedSection:AddSlider("Big Button Outline Transparency",0.0,1.0,speedButtonOutlineTransparency,function(value)
    speedButtonOutlineTransparency=value; SetCfg("speedButtonOutlineTransparency",value); updateSpeedButtonStyle()
end)
speedSection:AddSlider("Bind Button Size",1,10,speedBindButtonSize,function(value)
    speedBindButtonSize=math.clamp(tonumber(value) or 5,1,10)
    SetCfg("speedBindButtonSize",speedBindButtonSize)
    updateSpeedButtonStyle()
end)
speedSection:AddSlider("Bind Button Transparency",1.0,5.0,speedBindButtonTransparency,function(value)
    speedBindButtonTransparency=math.clamp(tonumber(value) or 1,1,5)
    SetCfg("speedBindButtonTransparency",speedBindButtonTransparency)
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
    speedButtonWidth=120
    speedButtonHeight=44
    speedButtonColor=Color3.fromRGB(0,0,0)
    speedButtonTransparency=3.6
    speedButtonOutlineColor=Color3.fromRGB(255,255,255)
    speedButtonOutlineTransparency=0.25
    speedBindButtonSize=5
    speedBindButtonTransparency=1
    if speedButton then
        speedButton.Position=BIG_BUTTON_DEFAULT
        speedButton.Visible=false
    end
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

local distanceToggle = addToggle(espSection, "Enable Distance ESP", distanceEspEnabled, function(state)
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


env.VisualsV2Runtime.RegisterReset(function()
    distanceToggle:Set(false)
    distanceEspEnabled = false
    clearDistanceEsp()
end)


-- =========================================================
-- UTILITIES: SHOOT MURDERER BUTTON
-- Customizes the existing ODH button. Position saves automatically after drag.
-- =========================================================

;(function()
local section=mainTab:AddSection("Shoot Murderer Button","Utilities")
local customEnabled=C("shootCustomizationEnabled",false)
local buttonWidth=C("shootButtonWidth",100)
local buttonHeight=C("shootButtonHeight",40)
local keepGun=C("shootKeepGunEnabled",false)
local allowDrag=C("shootDragEnabled",false)
local hideText=C("shootHideText",false)
local button,scale,oldText,originalSize,originalPosition
local conns={}
local gunConn,gunTask
local dragging=false
local dragInput,dragStart,startPos
local DEFAULT_POS=UDim2.new(0.5,-50,0.5,-20)
local buttonPos=loadStoredPosition("shootMurdButtonPosition",DEFAULT_POS)

local function normalize(value)
    return tostring(value or ""):lower():gsub("%s+","")
end
local function roots()
    local result,seen={},{}
    local function add(root)
        if root and not seen[root] then seen[root]=true; table.insert(result,root) end
    end
    pcall(function() add(game:GetService("CoreGui")) end)
    pcall(function() if gethui then add(gethui()) end end)
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
            task.defer(function()
                if hum.Parent and gun.Parent then pcall(function() hum:EquipTool(gun) end) end
            end)
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
    if oldText~=nil then button.Text=oldText end
end
local function update()
    if not button or not customEnabled then return end
    button.Size=UDim2.new(0,buttonWidth,0,buttonHeight)
    button.Position=buttonPos
    button.Text=hideText and "" or (oldText or "Shoot Murderer")
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
    oldText=button.Text
    originalSize=button.Size
    originalPosition=button.Position
    scale=Instance.new("UIScale"); scale.Parent=button
    update()

    table.insert(conns,button.InputBegan:Connect(function(input)
        if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
        if not customEnabled then return end
        if allowDrag then
            dragging=true; dragInput=input; dragStart=input.Position; startPos=button.Position
        else
            keepEquipped(); animate()
        end
    end))
    table.insert(conns,UserInputService.InputChanged:Connect(function(input)
        if not customEnabled or not allowDrag or not dragging or not button then return end
        if input.UserInputType~=Enum.UserInputType.MouseMovement and input.UserInputType~=Enum.UserInputType.Touch then return end
        if dragInput and dragInput.UserInputType==Enum.UserInputType.Touch and input.UserInputType~=Enum.UserInputType.Touch then return end
        local delta=input.Position-dragStart
        button.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y)
    end))
    table.insert(conns,UserInputService.InputEnded:Connect(function(input)
        if not dragging then return end
        if input==dragInput or input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            dragging=false; dragInput=nil
            if button then
                buttonPos=button.Position
                saveStoredPosition("shootMurdButtonPosition",buttonPos)
            end
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
local textToggle=addToggle(section,"Hide Button Text",hideText,function(v) hideText=v; SetCfg("shootHideText",v); update() end)
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
            root.DescendantAdded:Connect(function(item)
                if isTarget(item) then task.defer(function() bind(item) end) end
            end)
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
-- UTILITIES: GUN+
-- Adapted from drowsynicolas/tuffODHaddons; numeric sliders intentionally omitted.
-- =========================================================

;(function()
local section=mainTab:AddSection("Gun+","Utilities")
local blockAnimations=C("gunPlusBlockAnimations",false)
local equipSound=C("gunPlusEquipSound",false)
local dropForceField=C("gunPlusDropForceField",false)
local dropFireColorEnabled=C("gunPlusDropFireColorEnabled",false)
local forceFieldColor=C("gunPlusForceFieldColor",Color3.fromRGB(0,100,255))
local dropFireColor=C("gunPlusDropFireColor",Color3.fromRGB(0,100,255))
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
local transparency=C("serverPosTransparency",2.5) -- UI 1-5, mapped to Roblox 0-1.
local marker,root,humanoid,heartbeat,healthConn,charConn
local history={}

local function alpha() return math.clamp((tonumber(transparency) or 2.5)/5,0,1) end
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
        for _,entry in ipairs(history) do
            if math.abs(entry.time-target)<math.abs(closest.time-target) then closest=entry end
        end
        marker.CFrame=CFrame.new(closest.position)*closest.rotation
    end)
end
local function enable()
    if not charConn then
        charConn=player.CharacterAdded:Connect(function(char) task.wait(); if enabled then createMarker(char) end end)
    end
    if player.Character then createMarker(player.Character) end
end
local function disable()
    if charConn then charConn:Disconnect(); charConn=nil end
    destroyMarker()
end

local enableToggle=addToggle(section,"Show Server Pos",enabled,function(v)
    enabled=v; SetCfg("serverPosEnabled",v); if v then enable() else disable() end
end)
section:AddSlider("Marker Transparency",1.0,5.0,transparency,function(v)
    transparency=math.clamp(tonumber(v) or 2.5,1,5); SetCfg("serverPosTransparency",transparency)
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
-- One system for guns, knives and any other Tool; supports solid/rainbow tint.
-- =========================================================

;(function()
local section=mainTab:AddSection("Tool Tint","Visuals")
section:AddParagraph("Tool Tint","Applies to guns, knives, and other Roblox tools.")
local enabled=C("toolTintEnabled",false)
local mode=C("toolTintMode","Tool Color")
local tintColor=C("toolTintColor",Color3.fromRGB(255,255,255))
local rainbow=C("toolTintRainbow",false)
local rainbowSpeed=C("toolTintRainbowSpeed",3)
local transparency=C("toolTintTransparency",5) -- Highlight fill transparency UI 1-10.
local originals=setmetatable({}, {__mode="k"})
local seenTools=setmetatable({}, {__mode="k"})
local rainbowConn
local HIGHLIGHT_NAME="VisualsV2_ToolTint"

local function remember(obj)
    if originals[obj] then return end
    local data={}
    pcall(function()
        if obj:IsA("BasePart") then data.Color=obj.Color end
        if obj:IsA("DataModelMesh") then data.VertexColor=obj.VertexColor end
        if obj:IsA("Decal") or obj:IsA("Texture") then data.Color3=obj.Color3 end
        if obj:IsA("SurfaceAppearance") then data.SurfaceColor=obj.Color end
        if obj:IsA("Beam") or obj:IsA("Trail") or obj:IsA("ParticleEmitter") then data.Sequence=obj.Color end
    end)
    if next(data) then originals[obj]=data end
end
local function restoreObject(obj)
    local data=originals[obj]
    if not data or not obj or not obj.Parent then return end
    pcall(function()
        if data.Color then obj.Color=data.Color end
        if data.VertexColor then obj.VertexColor=data.VertexColor end
        if data.Color3 then obj.Color3=data.Color3 end
        if data.SurfaceColor then obj.Color=data.SurfaceColor end
        if data.Sequence then obj.Color=data.Sequence end
    end)
end
local function removeHighlight(tool)
    if not tool then return end
    local h=tool:FindFirstChild(HIGHLIGHT_NAME)
    if h and h:IsA("Highlight") then h:Destroy() end
end
local function setObjectColor(obj,color)
    remember(obj)
    pcall(function()
        if obj:IsA("BasePart") then obj.Color=color
        elseif obj:IsA("DataModelMesh") then obj.VertexColor=Vector3.new(color.R,color.G,color.B)
        elseif obj:IsA("Decal") or obj:IsA("Texture") then obj.Color3=color
        elseif obj:IsA("SurfaceAppearance") then obj.Color=color
        elseif obj:IsA("Beam") or obj:IsA("Trail") or obj:IsA("ParticleEmitter") then obj.Color=ColorSequence.new(color) end
    end)
end
local function restoreTool(tool)
    if not tool then return end
    removeHighlight(tool)
    for _,obj in ipairs(tool:GetDescendants()) do restoreObject(obj) end
end
local function allTools()
    local result={}
    for _,container in ipairs({player.Character,player:FindFirstChildOfClass("Backpack")}) do
        if container then for _,obj in ipairs(container:GetChildren()) do if obj:IsA("Tool") then table.insert(result,obj) end end end
    end
    return result
end
local function colorNow()
    if rainbow then return Color3.fromHSV((os.clock()*(rainbowSpeed*0.1))%1,1,1) end
    return tintColor
end
local function apply(tool)
    if not enabled or not tool or not tool:IsA("Tool") then return end
    local color=colorNow()
    if mode=="Highlight" then
        for _,obj in ipairs(tool:GetDescendants()) do restoreObject(obj) end
        local h=tool:FindFirstChild(HIGHLIGHT_NAME)
        if not h then
            h=Instance.new("Highlight"); h.Name=HIGHLIGHT_NAME; h.Adornee=tool; h.DepthMode=Enum.HighlightDepthMode.Occluded; h.OutlineTransparency=1; h.Parent=tool
        end
        h.FillColor=color; h.FillTransparency=math.clamp((tonumber(transparency) or 5)/10,0,1)
    else
        removeHighlight(tool)
        for _,obj in ipairs(tool:GetDescendants()) do setObjectColor(obj,color) end
    end
end
local function restoreAll()
    if rainbowConn then rainbowConn:Disconnect(); rainbowConn=nil end
    for _,tool in ipairs(allTools()) do restoreTool(tool) end
    for obj in pairs(originals) do restoreObject(obj) end
end
local function applyAll()
    for _,tool in ipairs(allTools()) do apply(tool) end
end
local function updateRainbow()
    if rainbowConn then rainbowConn:Disconnect(); rainbowConn=nil end
    if enabled and rainbow then
        rainbowConn=RunService.RenderStepped:Connect(function() applyAll() end)
    end
end
local function refreshAll()
    for _,tool in ipairs(allTools()) do restoreTool(tool) end
    if enabled then applyAll() end
    updateRainbow()
end
local function hookTool(tool)
    if not tool or not tool:IsA("Tool") or seenTools[tool] then return end
    seenTools[tool]=true
    tool.DescendantAdded:Connect(function() if enabled then task.defer(function() apply(tool) end) end end)
    tool.Equipped:Connect(function() if enabled then apply(tool) end end)
end
local function watch(container)
    if not container then return end
    for _,obj in ipairs(container:GetChildren()) do if obj:IsA("Tool") then hookTool(obj) end end
    container.ChildAdded:Connect(function(obj) if obj:IsA("Tool") then hookTool(obj); if enabled then task.defer(function() apply(obj) end) end end end)
end
watch(player:FindFirstChildOfClass("Backpack")); watch(player.Character)
player.CharacterAdded:Connect(function(char) watch(char); task.defer(function() if enabled then applyAll() end end) end)

local enabledToggle=addToggle(section,"Enable Tool Tint",enabled,function(v)
    enabled=v; SetCfg("toolTintEnabled",v); if v then applyAll(); updateRainbow() else restoreAll() end
end)
addDropdown(section,"Tint Mode",{"Tool Color","Highlight"},mode,function(v)
    mode=v; SetCfg("toolTintMode",v); refreshAll()
end)
section:AddColorpicker("Tool Tint Color",tintColor,function(color)
    tintColor=color; SetCfg("toolTintColor",color); if enabled and not rainbow then applyAll() end
end)
local rainbowToggle=addToggle(section,"Rainbow Tool Tint",rainbow,function(v)
    rainbow=v; SetCfg("toolTintRainbow",v); if enabled then refreshAll() else updateRainbow() end
end)
section:AddSlider("Rainbow Speed",1,10,rainbowSpeed,function(v)
    rainbowSpeed=v; SetCfg("toolTintRainbowSpeed",v)
end)
section:AddSlider("Tint Transparency",1,10,transparency,function(v)
    transparency=math.clamp(tonumber(v) or 5,1,10); SetCfg("toolTintTransparency",transparency); if enabled and mode=="Highlight" then applyAll() end
end)

env.VisualsV2Runtime.RegisterReset(function()
    enabledToggle:Set(false); rainbowToggle:Set(false)
    enabled=false; rainbow=false; mode="Tool Color"; tintColor=Color3.fromRGB(255,255,255); rainbowSpeed=3; transparency=5
    restoreAll()
end)
end)()

-- =========================================================
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
-- VISUALS: BINDABLE BUTTON VISUALS
-- =========================================================

;(function()
local section=mainTab:AddSection("Bindable Button Visuals","Visuals")
local enabled=C("bindVisualEnabled",false)
local gradientEnabled=C("bindVisualGradientEnabled",false)
local buttonColor=C("bindVisualButtonColor",Color3.fromRGB(255,255,255))
local outlineColor=C("bindVisualOutlineColor",Color3.fromRGB(255,255,255))
local grad1=C("bindVisualGradient1",Color3.fromRGB(255,80,80))
local grad2=C("bindVisualGradient2",Color3.fromRGB(120,90,255))
local grad3=C("bindVisualGradient3",Color3.fromRGB(80,220,255))
local originals=setmetatable({}, {__mode="k"})
local storageConnection

local function getAllBindableButtons()
    local result={}
    local seen={}
    for _, b in pairs(BindableButtons.Buttons) do
        if b and b.Parent and not seen[b] then seen[b]=true; table.insert(result,b) end
    end
    local storage=getBindStorage()
    for _, obj in ipairs(storage:GetDescendants()) do
        if (obj:IsA("ImageButton") or obj:IsA("TextButton")) and not seen[obj] then
            seen[obj]=true
            table.insert(result,obj)
        end
    end
    return result
end

local function remember(button)
    if originals[button] then return originals[button] end
    local snap={}
    pcall(function() snap.ImageColor3=button.ImageColor3 end)
    pcall(function() snap.BackgroundColor3=button.BackgroundColor3 end)
    local stroke=button:FindFirstChild("@Stroke")
    if stroke and stroke:IsA("UIGradient") then
        snap.StrokeType="UIGradient"
        snap.StrokeColor=stroke.Color
        snap.StrokeRotation=stroke.Rotation
    elseif stroke and stroke:IsA("UIStroke") then
        snap.StrokeType="UIStroke"
        snap.StrokeColor=stroke.Color
    end
    originals[button]=snap
    return snap
end

local function restore(button)
    local snap=originals[button]
    if not button or not snap then return end
    local grad=button:FindFirstChild("VisualsV2_BindGradient")
    if grad then grad:Destroy() end
    if snap.ImageColor3 then pcall(function() button.ImageColor3=snap.ImageColor3 end) end
    if snap.BackgroundColor3 then pcall(function() button.BackgroundColor3=snap.BackgroundColor3 end) end
    local stroke=button:FindFirstChild("@Stroke")
    if stroke and snap.StrokeColor then
        if stroke:IsA("UIGradient") and snap.StrokeType=="UIGradient" then
            stroke.Color=snap.StrokeColor
            stroke.Rotation=snap.StrokeRotation or 0
        elseif stroke:IsA("UIStroke") and snap.StrokeType=="UIStroke" then
            stroke.Color=snap.StrokeColor
        end
    end
end

local function restoreAll()
    for button in pairs(originals) do
        if button and button.Parent then restore(button) end
    end
end

local function apply(button)
    if not enabled or not button or not button.Parent then return end
    remember(button)

    local oldGrad=button:FindFirstChild("VisualsV2_BindGradient")
    if gradientEnabled then
        pcall(function() button.ImageColor3=Color3.new(1,1,1) end)
        if not oldGrad then
            oldGrad=Instance.new("UIGradient")
            oldGrad.Name="VisualsV2_BindGradient"
            oldGrad.Rotation=0
            oldGrad.Parent=button
        end
        oldGrad.Color=ColorSequence.new({
            ColorSequenceKeypoint.new(0,grad1),
            ColorSequenceKeypoint.new(0.5,grad2),
            ColorSequenceKeypoint.new(1,grad3),
        })
    else
        if oldGrad then oldGrad:Destroy() end
        pcall(function() button.ImageColor3=buttonColor end)
        pcall(function() button.BackgroundColor3=buttonColor end)
    end

    local stroke=button:FindFirstChild("@Stroke")
    if stroke then
        if stroke:IsA("UIGradient") then
            stroke.Color=ColorSequence.new(outlineColor)
            stroke.Rotation=0
        elseif stroke:IsA("UIStroke") then
            stroke.Color=outlineColor
        end
    end
end

local function applyAll()
    if not enabled then return end
    for _, button in ipairs(getAllBindableButtons()) do apply(button) end
end

local visualToggle
visualToggle=addToggle(section,"Enable Bindable Button Visuals",enabled,function(state)
    enabled=state
    SetCfg("bindVisualEnabled",state)
    if state then applyAll() else restoreAll() end
end)

addToggle(section,"Three Color Gradient",gradientEnabled,function(state)
    gradientEnabled=state
    SetCfg("bindVisualGradientEnabled",state)
    if enabled then applyAll() end
end)
section:AddColorpicker("Button / Icon Color",buttonColor,function(color)
    buttonColor=color; SetCfg("bindVisualButtonColor",color); if enabled then applyAll() end
end)
section:AddColorpicker("Outline Color",outlineColor,function(color)
    outlineColor=color; SetCfg("bindVisualOutlineColor",color); if enabled then applyAll() end
end)
section:AddColorpicker("Gradient Color 1",grad1,function(color)
    grad1=color; SetCfg("bindVisualGradient1",color); if enabled and gradientEnabled then applyAll() end
end)
section:AddColorpicker("Gradient Color 2",grad2,function(color)
    grad2=color; SetCfg("bindVisualGradient2",color); if enabled and gradientEnabled then applyAll() end
end)
section:AddColorpicker("Gradient Color 3",grad3,function(color)
    grad3=color; SetCfg("bindVisualGradient3",color); if enabled and gradientEnabled then applyAll() end
end)
section:AddButton("Restore Original Bindable Buttons",function()
    visualToggle:Set(false)
    restoreAll()
end)
section:AddButton("Reset Bindable Button Visuals",function()
    visualToggle:Set(false)
    gradientEnabled=false
    buttonColor=Color3.fromRGB(255,255,255)
    outlineColor=Color3.fromRGB(255,255,255)
    grad1=Color3.fromRGB(255,80,80)
    grad2=Color3.fromRGB(120,90,255)
    grad3=Color3.fromRGB(80,220,255)
    for _, key in ipairs({
        "bindVisualEnabled","bindVisualGradientEnabled","bindVisualButtonColor","bindVisualOutlineColor",
        "bindVisualGradient1","bindVisualGradient2","bindVisualGradient3"
    }) do SetCfg(key,nil) end
    restoreAll()
end)

local storage=getBindStorage()
storageConnection=storage.DescendantAdded:Connect(function(obj)
    if enabled and (obj:IsA("ImageButton") or obj:IsA("TextButton")) then task.defer(function() apply(obj) end) end
end)

env.VisualsV2Runtime.RegisterReset(function()
    visualToggle:Set(false)
    enabled=false
    restoreAll()
end)

end)()

-- =========================================================

-- UTILITIES: FIREFLY CLUTCH
-- =========================================================

;(function()
local section=mainTab:AddSection("Firefly Clutch","Utilities")
local enabled=C("fireflyEnabled",false)
local autoClutch=C("fireflyAutoClutch",false)
local timerSize=C("fireflyTimerSize",5)
local lockTimerPos=C("fireflyLockTimerPos",false)
local COUNTDOWN=2.5
local COOLDOWN=15.0
local TRIGGER_POINT=0.23
local BURST_DURATION=0.5
local DEFAULT_POS=UDim2.new(0.5,0,0.10,0)
local gui,timerButton,toolConnection,phaseConnection,jumpConnection
local watchers={}
local cooldownEnd=0
local clutchEnd=0
local jumpTriggered=false

local function disconnect(conn) if conn then pcall(function() conn:Disconnect() end) end end

local function timerPosition()
    return loadStoredPosition("fireflyTimerPosition",DEFAULT_POS)
end

local function applySize()
    if not timerButton then return end
    local level=math.clamp(tonumber(timerSize) or 5,1,10)
    local px=38+((level-1)*7)
    timerButton.Size=UDim2.fromOffset(px,px)
    timerButton.TextSize=math.max(11,math.floor(px*0.28))
end

local function buildTimer()
    if gui and gui.Parent and timerButton then return end
    gui=Instance.new("ScreenGui")
    gui.Name="VisualsV2_FireflyTimer"
    gui.ResetOnSpawn=false
    gui.IgnoreGuiInset=true
    gui.Parent=player:WaitForChild("PlayerGui")

    timerButton=Instance.new("TextButton")
    timerButton.Name="FireflyTimer"
    timerButton.AnchorPoint=Vector2.new(0.5,0.5)
    timerButton.Position=timerPosition()
    timerButton.BackgroundColor3=Color3.new(1,1,1)
    timerButton.BackgroundTransparency=0.90
    timerButton.BorderSizePixel=0
    timerButton.TextColor3=Color3.new(0,0,0)
    timerButton.TextStrokeTransparency=1
    timerButton.Font=Enum.Font.GothamBold
    timerButton.Text=""
    timerButton.Visible=false
    timerButton.Active=true
    timerButton.AutoButtonColor=false
    timerButton.Parent=gui

    local corner=Instance.new("UICorner")
    corner.CornerRadius=UDim.new(0,4)
    corner.Parent=timerButton
    local stroke=Instance.new("UIStroke")
    stroke.Color=Color3.new(1,1,1)
    stroke.Transparency=0.35
    stroke.Thickness=1
    stroke.Parent=timerButton
    applySize()

    local dragging=false
    local moved=false
    local dragInput,dragStart,startPos
    timerButton.InputBegan:Connect(function(input)
        if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
        dragging=true; moved=false; dragStart=input.Position; startPos=timerButton.Position
    end)
    timerButton.InputChanged:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch then dragInput=input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging or input~=dragInput or lockTimerPos then return end
        local delta=input.Position-dragStart
        if delta.Magnitude>7 then moved=true end
        timerButton.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y)
    end)
    UserInputService.InputEnded:Connect(function(input)
        if not dragging then return end
        if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
        dragging=false
        if moved and not lockTimerPos then saveStoredPosition("fireflyTimerPosition",timerButton.Position) end
    end)
end

local function stopJumpBurst()
    disconnect(jumpConnection); jumpConnection=nil
end
local function jumpOnce()
    local char=player.Character
    local humanoid=char and char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    humanoid.Jump=true
    if humanoid.FloorMaterial~=Enum.Material.Air then humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end
end
local function startJumpBurst()
    stopJumpBurst()
    local elapsed=0
    jumpConnection=RunService.Heartbeat:Connect(function(dt)
        elapsed+=dt
        if elapsed>=BURST_DURATION then stopJumpBurst(); return end
        jumpOnce()
    end)
end

local function stopPhase()
    disconnect(phaseConnection); phaseConnection=nil
    if timerButton then timerButton.Visible=false; timerButton.Text="" end
end

local function startCycle()
    if not enabled then return end
    local now=os.clock()
    if cooldownEnd>now then return end
    buildTimer()
    disconnect(phaseConnection)
    jumpTriggered=false
    clutchEnd=now+COUNTDOWN
    cooldownEnd=0
    timerButton.Visible=true
    timerButton.Text=string.format("%.1fCD",COUNTDOWN)

    phaseConnection=RunService.Heartbeat:Connect(function()
        local current=os.clock()
        if clutchEnd>0 then
            local remaining=math.max(0,clutchEnd-current)
            timerButton.Text=string.format("%.1fCD",remaining)
            if autoClutch and not jumpTriggered and remaining<=TRIGGER_POINT then
                jumpTriggered=true
                startJumpBurst()
            end
            if remaining<=0 then
                clutchEnd=0
                cooldownEnd=current+COOLDOWN
                timerButton.Text=string.format("%.1fCD",COOLDOWN)
            end
        elseif cooldownEnd>0 then
            local remaining=math.max(0,cooldownEnd-current)
            timerButton.Text=string.format("%.1fCD",remaining)
            if remaining<=0 then
                cooldownEnd=0
                stopPhase()
            end
        end
    end)
end

local function clearWatchers()
    disconnect(toolConnection); toolConnection=nil
    for _, c in ipairs(watchers) do disconnect(c) end
    table.clear(watchers)
end
local function connectTool(tool)
    if not tool or not tool:IsA("Tool") or tool.Name~="Fireflies" then return end
    disconnect(toolConnection)
    toolConnection=tool.Activated:Connect(startCycle)
end
local function watchContainer(container)
    if not container then return end
    local tool=container:FindFirstChild("Fireflies")
    if tool and tool:IsA("Tool") then connectTool(tool) end
    table.insert(watchers,container.ChildAdded:Connect(function(child)
        if child:IsA("Tool") and child.Name=="Fireflies" then connectTool(child) end
    end))
end
local function hookTool()
    clearWatchers()
    watchContainer(player:FindFirstChildOfClass("Backpack"))
    watchContainer(player.Character)
    table.insert(watchers,player.ChildAdded:Connect(function(child) if child:IsA("Backpack") then watchContainer(child) end end))
    table.insert(watchers,player.CharacterAdded:Connect(function(char) task.wait(0.2); watchContainer(char) end))
end
local function stopAll()
    clearWatchers(); stopJumpBurst(); stopPhase(); clutchEnd=0; cooldownEnd=0; jumpTriggered=false
    if gui then gui:Destroy(); gui=nil; timerButton=nil end
end

local enabledToggle=addToggle(section,"Enable Firefly Clutch",enabled,function(state)
    enabled=state
    SetCfg("fireflyEnabled",state)
    if state then buildTimer(); hookTool() else stopAll() end
end)
addToggle(section,"Auto Firefly Clutch",autoClutch,function(state)
    autoClutch=state
    SetCfg("fireflyAutoClutch",state)
end)
section:AddSlider("Firefly Timer Size",1,10,timerSize,function(value)
    timerSize=math.clamp(tonumber(value) or 5,1,10)
    SetCfg("fireflyTimerSize",timerSize)
    applySize()
end)
addToggle(section,"Lock Firefly Timer POS",lockTimerPos,function(state)
    lockTimerPos=state
    SetCfg("fireflyLockTimerPos",state)
end)
section:AddButton("Reset Firefly Timer POS",function()
    SetCfg("fireflyTimerPosition",nil)
    if timerButton then timerButton.Position=DEFAULT_POS end
end)

env.VisualsV2Runtime.RegisterReset(function()
    enabledToggle:Set(false)
    enabled=false
    autoClutch=false
    lockTimerPos=false
    timerSize=5
    if timerButton then timerButton.Position=DEFAULT_POS end
    stopAll()
end)

if enabled then task.defer(function() buildTimer(); hookTool() end) end
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
local originalLighting={
    Brightness=Lighting.Brightness,
    ClockTime=Lighting.ClockTime,
    GlobalShadows=Lighting.GlobalShadows,
    Ambient=Lighting.Ambient,
    OutdoorAmbient=Lighting.OutdoorAmbient,
    ExposureCompensation=Lighting.ExposureCompensation,
    FogStart=Lighting.FogStart,
    FogEnd=Lighting.FogEnd,
    FogColor=Lighting.FogColor,
}
local fullbrightEnabled=C("fullbrightEnabled",false)
local ambientColor=C("ambientColor",Lighting.Ambient)
local timeOfDay=C("timeOfDay",Lighting.ClockTime)
local exposure=C("exposure",Lighting.ExposureCompensation)

local function applyTime(value)
    value=math.clamp(tonumber(value) or 12,0,24)
    local hour=math.floor(value)%24
    local minute=math.floor((value-math.floor(value))*60+0.5)%60
    pcall(function() Lighting.TimeOfDay=string.format("%02d:%02d:00",hour,minute) end)
    Lighting.ClockTime=value
end

local fullbrightToggle=addToggle(worldSection,"Fullbright",fullbrightEnabled,function(state)
    fullbrightEnabled=state
    SetCfg("fullbrightEnabled",state)
    if state then
        Lighting.Brightness=2
        Lighting.GlobalShadows=false
        Lighting.Ambient=Color3.new(1,1,1)
        Lighting.OutdoorAmbient=Color3.new(1,1,1)
        Lighting.FogEnd=100000
    else
        Lighting.Brightness=originalLighting.Brightness
        Lighting.GlobalShadows=originalLighting.GlobalShadows
        Lighting.Ambient=ambientColor
        Lighting.OutdoorAmbient=ambientColor
        applyTime(timeOfDay)
    end
end)
worldSection:AddColorpicker("Ambient Color",ambientColor,function(color)
    ambientColor=color; SetCfg("ambientColor",color)
    if not fullbrightEnabled then Lighting.Ambient=color; Lighting.OutdoorAmbient=color end
end)
worldSection:AddSlider("Time of Day",0.0,24.0,timeOfDay,function(value)
    timeOfDay=math.clamp(tonumber(value) or 12,0,24)
    SetCfg("timeOfDay",timeOfDay)
    if not fullbrightEnabled then applyTime(timeOfDay) end
end)
worldSection:AddSlider("Exposure",-2.0,2.0,exposure,function(value)
    exposure=value; SetCfg("exposure",value); Lighting.ExposureCompensation=value
end)

local fogSection=mainTab:AddSection("Fog","World")
local fogEnabled=C("fogEnabled",false)
local fogRainbow=C("fogRainbow",false)
local fogColor=C("fogColor",Color3.fromRGB(200,200,255))
local fogStart=C("fogStart",0)
local fogEnd=C("fogEnd",300)
local function applyFog()
    Lighting.FogStart=fogStart; Lighting.FogEnd=fogEnd; Lighting.FogColor=fogColor
end
local fogToggle=addToggle(fogSection,"Enable Beautiful Fog",fogEnabled,function(state)
    fogEnabled=state; SetCfg("fogEnabled",state)
    if state then applyFog() else Lighting.FogStart=originalLighting.FogStart; Lighting.FogEnd=originalLighting.FogEnd; Lighting.FogColor=originalLighting.FogColor end
end)
local rainbowFogToggle=addToggle(fogSection,"Rainbow Fog",fogRainbow,function(state)
    fogRainbow=state; SetCfg("fogRainbow",state)
end)
fogSection:AddSlider("Fog Distance",50,2000,fogEnd,function(value) fogEnd=value; SetCfg("fogEnd",value); if fogEnabled then applyFog() end end)
fogSection:AddSlider("Fog Start",0,500,fogStart,function(value) fogStart=value; SetCfg("fogStart",value); if fogEnabled then applyFog() end end)
fogSection:AddColorpicker("Fog Color",fogColor,function(color) fogColor=color; SetCfg("fogColor",color); if fogEnabled and not fogRainbow then applyFog() end end)
RunService.RenderStepped:Connect(function()
    if fogEnabled and fogRainbow then Lighting.FogColor=Color3.fromHSV((os.clock()%5)/5,1,1) end
end)

-- Skyboxes use individual toggles so exactly one selection can be persisted.
local skyboxSection=mainTab:AddSection("Skyboxes","Visuals")
local originalSky=Lighting:FindFirstChildOfClass("Sky")
originalSky=originalSky and originalSky:Clone() or nil
local function clearSky() for _, obj in ipairs(Lighting:GetChildren()) do if obj:IsA("Sky") then obj:Destroy() end end end
local function restoreSky() clearSky(); if originalSky then originalSky:Clone().Parent=Lighting end end
local function singleAsset(id)
    clearSky()
    local ok,asset=pcall(function() return game:GetObjects("rbxassetid://"..tostring(id))[1] end)
    if ok and asset and asset:IsA("Sky") then asset.Parent=Lighting; return end
    local sky=Instance.new("Sky")
    local assetId="rbxassetid://"..tostring(id)
    sky.SkyboxBk=assetId; sky.SkyboxDn=assetId; sky.SkyboxFt=assetId; sky.SkyboxLf=assetId; sky.SkyboxRt=assetId; sky.SkyboxUp=assetId
    sky.Parent=Lighting
end
local function sixFace(ids)
    clearSky()
    local sky=Instance.new("Sky")
    sky.SkyboxBk="rbxassetid://"..ids[1]; sky.SkyboxDn="rbxassetid://"..ids[2]; sky.SkyboxFt="rbxassetid://"..ids[3]
    sky.SkyboxLf="rbxassetid://"..ids[4]; sky.SkyboxRt="rbxassetid://"..ids[5]; sky.SkyboxUp="rbxassetid://"..ids[6]
    sky.Parent=Lighting
end

local presets={
    {"Orange Skybox","627302570"},{"FPS+ Skybox","582303304"},{"Space Skybox","15619750970"},{"Green Skybox","348361280"},
    {"Blue Skybox","130093177270069"},{"Purple Skybox","83555979203508"},{"Red Skybox","401666131"},{"HD Skybox","16823410580"},
    {"Night Skybox","12064636"},{"Galactic Skybox","10542194896"},{"Winter Skybox","96628448286151"},{"Saturn Skybox","1898754079"},
    {"Outrun Skybox","3441770362"},{"Cyan Space Skybox","367149630"},{"City Skybox","117205995214134"},{"Green Skybox 2.0","16823294549"},
    {"SpongeBob Skybox","114523453023009"},{"Purple Nebula Skybox","230057997"},{"Sunless Blue Sky","591067775"},{"Minecraft Skybox","5087871978"},
    {"Frutiger Aero Skybox","97046110924083"},{"Cyberpunk Skybox","13689001090"},{"Dark Red Castle Skybox","15832476802"},{"Cartoon Skybox","107689530722429"},
    {"Abyssal Blues Skybox","16269853692"},{"Earth Skybox","266878339"},{"Black & White Fade Skybox","6213224205"},{"Purple Skybox 2","8107887936"},
    {"Green Nebula Space","89018019804256"},{"HD Rainbow Skybox","18915196644"},{"Meadow Skybox","848241313"},{"Pink Sky Skybox","107689530722174"},
    {"Venus Skybox V2","110450592899174"},
    {"Better ODH - Minecraft Sky",{"8735166756","8735166707","8735231668","8735166755","8735166751","8735166729"}},
    {"Better ODH - Realistic Sky",{"144933338","144931530","144933262","144933244","144933299","144931564"}},
    {"Better ODH - Purple Nighty #1",{"159454299","159454296","159454293","159454286","159454300","159454288"}},
    {"Better ODH - Purple Nighty #2",{"14543264135","14543358958","14543257810","14543275895","14543280890","14543371676"}},
    {"Better ODH - Sunset",{"15502525195","15502522797","15502524520","15502522129","15502523711","15502526102"}},
    {"Better ODH - Nighty Sky",{"168387023","168387089","168387054","168534432","168387190","168387135"}},
    {"Better ODH - Sunset Sky",{"458016711","458016826","458016532","458016655","458016782","458016792"}},
    {"Better ODH - Night Fog",{"1370717244","1370717336","1370717438","1370717567","1370717698","1370717782"}},
    {"Better ODH - Blood Moon",{"401664839","401664862","401664960","401664881","401664901","401664936"}},
    {"Better ODH - Spongebob",{"15962101128","15970246218","15962101128","15962101128","15962101128","15962901054"}},
    {"Better ODH - Pink Blossom",{"271042516","271077243","271042556","271042310","271042467","271077958"}},
    {"Better ODH - Purple Sunset",{"264908339","264907909","264909420","264909758","264908886","264907379"}},
    {"Better ODH - Half-Life 2",{"9000922368","9000922033","9000921543","9000920853","9000920563","9000920353"}},
    {"Better ODH - Void Sky",{"16262356578","16262358026","16262360469","16262362003","16262363873","16262366016"}},
    {"Better ODH - Purple Night",{"5084575798","5084575916","5103949679","5103948542","5103948784","5084576400"}},
    {"Better ODH - Pink Sky",{"271042516","271077243","271042556","271042310","271042467","271077958"}},
    {"Better ODH - Realistic Moon",{"2670643994","2670643365","2670643214","2670643070","2670644173","2670644331"}},
}
local selected=C("selectedSkybox",nil)
if selected=="Default" then selected=nil end
local toggles={}
local changing=false
local function applyPreset(name)
    for _, entry in ipairs(presets) do
        if entry[1]==name then
            if type(entry[2])=="table" then sixFace(entry[2]) else singleAsset(entry[2]) end
            return true
        end
    end
    return false
end
for _, entry in ipairs(presets) do
    local name=entry[1]
    toggles[name]=addToggle(skyboxSection,name,false,function(state)
        if changing then return end
        if state then
            local previous=selected
            selected=name
            if previous and previous~=name and toggles[previous] then
                changing=true; toggles[previous]:Set(false); changing=false
            end
            SetCfg("selectedSkybox",name)
            applyPreset(name)
        elseif selected==name then
            selected=nil
            SetCfg("selectedSkybox",nil)
            restoreSky()
        end
    end)
end
if selected and toggles[selected] then task.defer(function() toggles[selected]:Set(true) end) else selected=nil end

env.VisualsV2Runtime.RegisterReset(function()
    fullbrightToggle:Set(false)
    fogToggle:Set(false)
    rainbowFogToggle:Set(false)
    if selected and toggles[selected] then changing=true; toggles[selected]:Set(false); changing=false end
    selected=nil
    restoreSky()
    Lighting.Brightness=originalLighting.Brightness
    Lighting.ClockTime=originalLighting.ClockTime
    Lighting.GlobalShadows=originalLighting.GlobalShadows
    Lighting.Ambient=originalLighting.Ambient
    Lighting.OutdoorAmbient=originalLighting.OutdoorAmbient
    Lighting.ExposureCompensation=originalLighting.ExposureCompensation
    Lighting.FogStart=originalLighting.FogStart
    Lighting.FogEnd=originalLighting.FogEnd
    Lighting.FogColor=originalLighting.FogColor
end)

end)()

-- =========================================================

-- MISCELLANEOUS
-- =========================================================

;(function()
local miscSection=mainTab:AddSection("Miscellaneous","Settings")
local bigLockToggle=addToggle(miscSection,"Lock Big Button POS",lockBigButtonPos,function(state)
    lockBigButtonPos=state
    SetCfg("lockBigButtonPos",state)
end)
local bindLockToggle=addToggle(miscSection,"Lock Bind Button POS",lockBindButtonPos,function(state)
    lockBindButtonPos=state
    SetCfg("lockBindButtonPos",state)
    BindableButtons:SetLocked("VisualsV2_SpeedBind",state)
end)

miscSection:AddButton("Reset All Settings",function()
    configResetting=true
    for _, resetter in ipairs(env.VisualsV2Runtime.Resetters or {}) do
        pcall(resetter)
    end
    bigLockToggle:Set(false)
    bindLockToggle:Set(false)
    lockBigButtonPos=false
    lockBindButtonPos=false
    ConfigData={}
    ensureConfigFolder()
    if type(exists)=="function" and type(deleteFile)=="function" then
        local ok,found=pcall(exists,CFG_FILE)
        if ok and found then pcall(deleteFile,CFG_FILE) end
    end
    if type(write)=="function" then pcall(function() write(CFG_FILE,"{}") end) end
    configResetting=false
    shared.Notify("Visuals V2 reset to defaults. Nothing is enabled.",2)
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
    if korbloxRightEnabled or korbloxLeftEnabled or headlessEnabled then applyCharacterVisuals() end
    setupJumpCircles(char)
    task.delay(0.5,setupSpeedButtons)
end
if player.Character then task.defer(function() onCharacterAdded(player.Character) end) end
player.CharacterAdded:Connect(onCharacterAdded)

shared.Notify("Visuals V2 loaded",2)
