-- ludexioso_visuals
-- ODH add-on port based on the provided Nexium Hub source.

local shared = odh_shared_plugins

local Players = game:GetService('Players')
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService('HttpService')
local RunService = game:GetService('RunService')
local Lighting = game:GetService('Lighting')
local TweenService = game:GetService('TweenService')
local UIS = game:GetService('UserInputService')

local player = LocalPlayer
local camera = workspace.CurrentCamera

local CFG_FOLDER = 'ludexioso_visuals'
local CFG_FILE = CFG_FOLDER .. '/config/main.json'
local ConfigData = {}

local function EnsureFolders()
    if not isfolder(CFG_FOLDER) then
        makefolder(CFG_FOLDER)
    end
    if not isfolder(CFG_FOLDER .. '/config') then
        makefolder(CFG_FOLDER .. '/config')
    end
end

local function SaveConfig()
    EnsureFolders()
    pcall(function()
        writefile(CFG_FILE, HttpService:JSONEncode(ConfigData))
    end)
end

local function LoadConfig()
    EnsureFolders()
    if isfile(CFG_FILE) then
        local ok, res = pcall(function()
            return HttpService:JSONDecode(readfile(CFG_FILE))
        end)
        if ok and type(res) == 'table' then
            ConfigData = res
        end
    end
end

local function C(key, default)
    local val = ConfigData[key]
    if val == nil then
        return default
    end
    if typeof(default) == 'Color3' and type(val) == 'table' then
        return Color3.fromRGB(val[1], val[2], val[3])
    end
    return val
end

local function SetCfg(key, value)
    if typeof(value) == 'Color3' then
        ConfigData[key] = {
            math.floor(value.R * 255),
            math.floor(value.G * 255),
            math.floor(value.B * 255),
        }
    else
        ConfigData[key] = value
    end
    SaveConfig()
end

LoadConfig()

-- One ODH tab, using the repository icon once. Everything else is organized
-- as sections/labels inside this tab.
local MainTab = shared.CreateTab(
    'ludexioso_visuals',
    '/0ludexioso/ludexioso_visuals/refs/heads/main/icon'
)

local SectionCache = {}

local function canonicalSectionName(name)
    if name == 'Skybox Custom' then
        return 'Skyboxes'
    end
    return name
end

local function getRawSection(name)
    name = canonicalSectionName(name)
    if not SectionCache[name] then
        SectionCache[name] = MainTab:AddSection(name, '')
    end
    return SectionCache[name]
end

local function wrapSection(raw)
    local proxy = {}

    function proxy:AddSubheading(text)
        if text and text ~= '' then
            raw:AddLabel('— ' .. tostring(text) .. ' —')
        end
    end

    function proxy:Toggle(options)
        local title = options.Title or 'Toggle'
        local desired = options.Value
        if desired == nil then
            desired = options.Default
        end
        desired = desired == true

        local current = false
        local suppressInitial = false
        local toggleFn

        toggleFn = raw:AddToggle(title, function(state)
            current = state == true
            if suppressInitial then
                suppressInitial = false
                return
            end
            if options.Callback then
                options.Callback(current)
            end
        end)

        if desired then
            suppressInitial = true
            toggleFn()
            current = true
        end

        local control = {}
        function control:Set(value)
            value = value == true
            if value ~= current then
                toggleFn()
            end
        end
        return control
    end

    function proxy:Slider(options)
        local value = options.Value or {}
        local minimum = value.Min or 0
        local maximum = value.Max or 100
        local default = value.Default
        if default == nil then
            default = minimum
        end
        local step = options.Step
        local control = raw:AddSlider(options.Title or 'Slider', minimum, maximum, default, function(v)
            if step and step > 0 then
                v = math.floor((v / step) + 0.5) * step
            end
            if options.Callback then
                options.Callback(v)
            end
        end)
        return control
    end

    function proxy:Colorpicker(options)
        local default = options.Default or Color3.new(1, 1, 1)
        return raw:AddColorpicker(options.Title or 'Color', default, function(color)
            if options.Callback then
                options.Callback(color)
            end
        end)
    end

    function proxy:Dropdown(options)
        local values = options.Values or {}
        local default = options.Value
        local suppressInitial = default ~= nil
        local control = raw:AddDropdown(options.Title or 'Dropdown', values, function(selected)
            if suppressInitial and selected == default then
                suppressInitial = false
                return
            end
            suppressInitial = false
            if options.Callback then
                options.Callback(selected)
            end
        end)
        if default ~= nil and control and control.Select then
            pcall(function()
                control:Select(default)
            end)
        end
        return control
    end

    function proxy:Button(options)
        return raw:AddButton(options.Title or 'Button', function()
            if options.Callback then
                options.Callback()
            end
        end)
    end

    function proxy:Keybind(options)
        return raw:AddKeybind(options.Title or 'Keybind', options.Value or 'U', function()
            if options.Callback then
                options.Callback()
            end
        end)
    end

    function proxy:Paragraph(options)
        return raw:AddParagraph(options.Title or '', options.Desc or '')
    end

    function proxy:Select()
        -- ODH already owns the active tab.
    end

    return proxy
end

local function wrapTab(title)
    local raw = getRawSection(title)
    local sectionProxy = wrapSection(raw)
    local tab = {}

    function tab:Section(options)
        if options and options.Title and options.Title ~= '' then
            sectionProxy:AddSubheading(options.Title)
        end
        return sectionProxy
    end

    function tab:Toggle(options) return sectionProxy:Toggle(options) end
    function tab:Slider(options) return sectionProxy:Slider(options) end
    function tab:Colorpicker(options) return sectionProxy:Colorpicker(options) end
    function tab:Dropdown(options) return sectionProxy:Dropdown(options) end
    function tab:Button(options) return sectionProxy:Button(options) end
    function tab:Keybind(options) return sectionProxy:Keybind(options) end
    function tab:Paragraph(options) return sectionProxy:Paragraph(options) end
    function tab:Select() end

    return tab
end

-- Compatibility layer so the original feature code can keep its WindUI-style
-- control declarations while rendering through the ODH add-on API.
local Window = {}
function Window:Tab(options)
    return wrapTab((options and options.Title) or 'General')
end
function Window:SelectTab() end

local WindUI = {}
function WindUI:Notify(options)
    local title = options and options.Title or 'ludexioso_visuals'
    local content = options and (options.Content or options.Text) or ''
    local duration = options and options.Duration or 3
    local message = content ~= '' and (title .. ': ' .. content) or title
    shared.Notify(message, duration)
end

local function _initCosmetic()
    local trailEnabled = C('trailEnabled', false)
    local trailIsGradient = C('trailIsGradient', false)
    local trailLifetime = C('trailLifetime', 0.5)
    local trailTransparencyStart = C('trailTransparencyStart', 0)
    local trailRainbow = C('trailRainbow', false)
    local trailColorStatic = C('trailColorStatic', Color3.fromRGB(0, 255, 255))
    local trailGradient1 = C('trailGradient1', Color3.fromRGB(0, 86, 255))
    local trailGradient2 = C('trailGradient2', Color3.fromRGB(255, 0, 0))
    local skinTrailEnabled = C('skinTrailEnabled', false)
    local skinTrailColor = C('skinTrailColor', Color3.fromRGB(255, 0, 0))
    local skinTrailLife = C('skinTrailLife', 0.5)
    local ffEnabled = C('ffEnabled', false)
    local ffColor = C('ffColor', Color3.fromRGB(128, 128, 128))
    local ffRainbow = C('ffRainbow', false)
    local originalColors = {}
    local ffConnection
    local auraEnabled = C('auraEnabled', false)
    local auraType = C('auraType', 'Godly')
    local customAuraID = C('customAuraID', '')
    local currentAuraModel = nil
    local auraEffects = {}
    local AuraModels = {
        Godly = 'rbxassetid://16699750981',
        ['Super Sayien'] = 'rbxassetid://116109508364297',
        ['North Star'] = 'rbxassetid://83945069652732',
        ['Blue Lord'] = 'rbxassetid://10974316799',
        ['Pink Aura'] = 'rbxassetid://115980859615239',
        ['Angel Wing'] = 'rbxassetid://90022969696073',
        ['Sweet Heart'] = 'rbxassetid://91724768175470',
        ['Ethereal Aura'] = 'rbxassetid://97041568674250',
    }
    local trailParts = {}
    local trailConnection
    local auraConnection

    local function removeTrail(char)
        if trailParts[char] then
            trailParts[char]:Destroy()

            trailParts[char] = nil
        end
        if char and char:FindFirstChild('HumanoidRootPart') then
            local torso = char.HumanoidRootPart

            if torso:FindFirstChild('TrailAttach0') then
                torso.TrailAttach0:Destroy()
            end
            if torso:FindFirstChild('TrailAttach1') then
                torso.TrailAttach1:Destroy()
            end
        end
    end
    local function addTrail(character)
        local torso = character:WaitForChild('HumanoidRootPart', 5)

        if not torso then
            return
        end

        removeTrail(character)

        local a0 = Instance.new('Attachment', torso)

        a0.Name = 'TrailAttach0'
        a0.Position = Vector3.new(0, 2, 0)

        local a1 = Instance.new('Attachment', torso)

        a1.Name = 'TrailAttach1'
        a1.Position = Vector3.new(0, -2, 0)

        local trail = Instance.new('Trail')

        trail.Attachment0 = a0
        trail.Attachment1 = a1
        trail.Lifetime = trailLifetime
        trail.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, trailTransparencyStart),
            NumberSequenceKeypoint.new(1, 1),
        })
        trail.Color = trailIsGradient and ColorSequence.new(trailGradient1, trailGradient2) or (trailRainbow and ColorSequence.new(Color3.fromHSV(tick() % 5 / 5, 1, 1)) or ColorSequence.new(trailColorStatic))
        trail.LightEmission = 0.2
        trail.Enabled = true
        trail.Parent = character
        trailParts[character] = trail
    end
    local function updateTrails()
        for char, trail in pairs(trailParts)do
            if trail and trail.Parent and char == player.Character then
                trail.Lifetime = trailLifetime
                trail.Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, trailTransparencyStart),
                    NumberSequenceKeypoint.new(1, 1),
                })

                if trailIsGradient then
                    trail.Color = ColorSequence.new(trailGradient1, trailGradient2)
                else
                    trail.Color = trailRainbow and ColorSequence.new(Color3.fromHSV(tick() % 5 / 5, 1, 1)) or ColorSequence.new(trailColorStatic)
                end
            end
        end
    end
    local function saveOriginalColors(char)
        originalColors[char] = {}

        for _, part in pairs(char:GetDescendants())do
            if part:IsA('BasePart') and part.Name ~= 'Hat' then
                originalColors[char][part] = {
                    Color = part.Color,
                    Material = part.Material,
                }
            end
        end
    end
    local function applyForceField(char)
        saveOriginalColors(char)

        for _, part in pairs(char:GetDescendants())do
            if part:IsA('BasePart') and part.Name ~= 'Hat' then
                part.Color = ffColor
                part.Material = Enum.Material.ForceField
            end
        end
    end
    local function updateForceField()
        if player.Character and ffEnabled then
            for _, part in pairs(player.Character:GetDescendants())do
                if part:IsA('BasePart') and part.Name ~= 'Hat' and part.Material == Enum.Material.ForceField then
                    part.Color = ffRainbow and Color3.fromHSV(tick() % 5 / 5, 1, 1) or ffColor
                end
            end
        end
    end
    local function removeForceField(char)
        if originalColors[char] then
            for part, data in pairs(originalColors[char])do
                if part and part.Parent and part:IsA('BasePart') then
                    part.Color = data.Color
                    part.Material = data.Material
                end
            end

            originalColors[char] = {}
        end
    end
    local function toggleSkinTrail(enabled)
        local character = player.Character

        if not character then
            return
        end

        local hrp = character:FindFirstChild('HumanoidRootPart')

        if not hrp then
            return
        end

        for _, v in pairs(character:GetChildren())do
            if v:IsA('BasePart') and v ~= hrp then
                if enabled then
                    if not v:FindFirstChild('SkinTrail') then
                        local trail = Instance.new('Trail')

                        trail.Name = 'SkinTrail'
                        trail.Texture = 'rbxassetid://1390780157'
                        trail.Parent = v

                        local p1 = Instance.new('Attachment', v)

                        p1.Name = 'SkinPointer1'

                        local p2 = Instance.new('Attachment', hrp)

                        p2.Name = 'SkinPointer2'
                        trail.Attachment0 = p1
                        trail.Attachment1 = p2
                        trail.Color = ColorSequence.new(skinTrailColor, skinTrailColor)
                        trail.Lifetime = skinTrailLife
                    end
                else
                    if v:FindFirstChild('SkinTrail') then
                        v.SkinTrail:Destroy()
                    end
                    if v:FindFirstChild('SkinPointer1') then
                        v.SkinPointer1:Destroy()
                    end
                end
            end
        end

        if not enabled then
            for _, obj in pairs(hrp:GetChildren())do
                if obj.Name == 'SkinPointer2' then
                    obj:Destroy()
                end
            end
        end
    end
    local function updateSkinTrail()
        local character = player.Character

        if not character then
            return
        end

        for _, v in pairs(character:GetDescendants())do
            if v:IsA('Trail') and v.Name == 'SkinTrail' then
                v.Color = ColorSequence.new(skinTrailColor, skinTrailColor)
                v.Lifetime = skinTrailLife
            end
        end
    end
    local function loadModel(id)
        local s, r = pcall(function()
            return game:GetObjects(id)[1]
        end)

        if not s then
            return nil
        end

        return r
    end
    local function disableAura()
        for _, v in pairs(auraEffects)do
            if v and v.Parent then
                v:Destroy()
            end
        end

        auraEffects = {}
    end
    local function enableAura(char)
        disableAura()

        if not currentAuraModel then
            return
        end

        local tempModel = currentAuraModel:Clone()

        for _, obj in pairs(tempModel:GetDescendants())do
            if not obj:IsA('BasePart') then
                local clone = obj:Clone()
                local parentName = obj.Parent and obj.Parent.Name
                local target = char:FindFirstChild(parentName) or char:FindFirstChildWhichIsA('BasePart')

                if target and not target:FindFirstChild(clone.Name) then
                    clone.Parent = target

                    table.insert(auraEffects, clone)
                end
            end
        end

        tempModel:Destroy()
    end
    local function updateAuraLogic()
        local idToLoad = customAuraID ~= '' and 'rbxassetid://' .. customAuraID:gsub('%D', '') or AuraModels[auraType]

        if not idToLoad then
            return
        end

        local newModel = loadModel(idToLoad)

        if newModel then
            currentAuraModel = newModel

            if auraEnabled and player.Character then
                enableAura(player.Character)
            end
        end
    end

    warn('cosmetic tab loaded')

    local CosmeticTab = Window:Tab({
        Title = 'Cosmetic',
        Icon = 'sparkles',
        ShowTabTitle = true,
        Border = true,
    })

    })

    local trailSection = CosmeticTab:Section({
        Title = 'Trail',
        Desc = '',
        Icon = 'footprints',
        Opened = true,
        Box = true,
        BoxBorder = true,
    })

    trailSection:Toggle({
        Title = 'Enable Trail',
        Desc = '',
        Type = 'Toggle',
        Value = C('trailEnabled', false),
        Icon = 'footprints',
        Callback = function(value)
            SetCfg('trailEnabled', value)

            trailEnabled = value

            if value and player.Character then
                addTrail(player.Character)

                if trailConnection then
                    trailConnection:Disconnect()
                end

                trailConnection = RunService.Heartbeat:Connect(updateTrails)
            else
                if player.Character then
                    removeTrail(player.Character)
                end
                if trailConnection then
                    trailConnection:Disconnect()

                    trailConnection = nil
                end
            end
        end,
    })
    trailSection:Toggle({
        Title = 'Use Gradient Mode',
        Desc = '',
        Type = 'Toggle',
        Value = C('trailIsGradient', false),
        Icon = 'layers',
        Callback = function(value)
            SetCfg('trailIsGradient', value)

            trailIsGradient = value

            if trailEnabled and player.Character then
                addTrail(player.Character)
            end
        end,
    })
    trailSection:Toggle({
        Title = 'Rainbow (Simple Mode)',
        Desc = '',
        Type = 'Toggle',
        Value = C('trailRainbow', false),
        Icon = 'palette',
        Callback = function(value)
            SetCfg('trailRainbow', value)

            trailRainbow = value

            updateTrails()
        end,
    })
    trailSection:Colorpicker({
        Title = 'Static Color',
        Desc = '',
        Default = C('trailColorStatic', Color3.fromRGB(0, 255, 255)),
        Transparency = 0,
        Callback = function(color, transparency)
            SetCfg('trailColorStatic', color)

            trailColorStatic = color

            updateTrails()
        end,
    })
    trailSection:Colorpicker({
        Title = 'Gradient Color 1',
        Desc = '',
        Default = C('trailGradient1', Color3.fromRGB(0, 86, 255)),
        Transparency = 0,
        Callback = function(color, transparency)
            SetCfg('trailGradient1', color)

            trailGradient1 = color

            updateTrails()
        end,
    })
    trailSection:Colorpicker({
        Title = 'Gradient Color 2',
        Desc = '',
        Default = C('trailGradient2', Color3.fromRGB(255, 0, 0)),
        Transparency = 0,
        Callback = function(color, transparency)
            SetCfg('trailGradient2', color)

            trailGradient2 = color

            updateTrails()
        end,
    })
    trailSection:Slider({
        Title = 'Trail Lifetime',
        Desc = '',
        Value = {
            Min = 0.1,
            Max = 3,
            Default = C('trailLifetime', 0.5),
        },
        Step = 0.1,
        IsTextbox = true,
        Callback = function(value)
            SetCfg('trailLifetime', value)

            trailLifetime = value

            updateTrails()
        end,
    })
    trailSection:Slider({
        Title = 'Trail Transparency Start',
        Desc = '',
        Value = {
            Min = 0,
            Max = 1,
            Default = C('trailTransparencyStart', 0),
        },
        Step = 0.01,
        IsTextbox = true,
        Callback = function(value)
            SetCfg('trailTransparencyStart', value)

            trailTransparencyStart = value

            updateTrails()
        end,
    })

    local skinSection = CosmeticTab:Section({
        Title = 'Skin',
        Desc = '',
        Icon = 'notebook',
        Opened = true,
        Box = true,
        BoxBorder = true,
    })

    skinSection:Toggle({
        Title = 'Enable ForceField',
        Desc = '',
        Type = 'Toggle',
        Value = C('ffEnabled', false),
        Icon = 'shield',
        Callback = function(value)
            SetCfg('ffEnabled', value)

            ffEnabled = value

            if player.Character then
                if value then
                    applyForceField(player.Character)

                    if ffConnection then
                        ffConnection:Disconnect()
                    end

                    ffConnection = RunService.Heartbeat:Connect(updateForceField)
                else
                    if ffConnection then
                        ffConnection:Disconnect()

                        ffConnection = nil
                    end

                    removeForceField(player.Character)
                end
            end
        end,
    })
    skinSection:Toggle({
        Title = 'Rainbow ForceField',
        Desc = '',
        Type = 'Toggle',
        Value = C('ffRainbow', false),
        Icon = 'palette',
        Callback = function(value)
            SetCfg('ffRainbow', value)

            ffRainbow = value

            updateForceField()
        end,
    })
    skinSection:Colorpicker({
        Title = 'ForceField Color',
        Desc = '',
        Default = C('ffColor', Color3.fromRGB(128, 128, 128)),
        Transparency = 0,
        Callback = function(color, transparency)
            SetCfg('ffColor', color)

            ffColor = color

            if ffEnabled and not ffRainbow and player.Character then
                applyForceField(player.Character)
            end
        end,
    })
    skinSection:Toggle({
        Title = 'Enable Skin Trail',
        Desc = '',
        Type = 'Toggle',
        Value = C('skinTrailEnabled', false),
        Icon = 'footprints',
        Callback = function(value)
            SetCfg('skinTrailEnabled', value)

            skinTrailEnabled = value

            toggleSkinTrail(value)
        end,
    })
    skinSection:Colorpicker({
        Title = 'Skin Trail Color',
        Desc = '',
        Default = C('skinTrailColor', Color3.fromRGB(255, 0, 0)),
        Transparency = 0,
        Callback = function(color, transparency)
            SetCfg('skinTrailColor', color)

            skinTrailColor = color

            if skinTrailEnabled then
                updateSkinTrail()
            end
        end,
    })
    skinSection:Slider({
        Title = 'Skin Trail Lifetime',
        Desc = '',
        Value = {
            Min = 0.1,
            Max = 3,
            Default = C('skinTrailLife', 0.5),
        },
        Step = 0.1,
        IsTextbox = true,
        Callback = function(value)
            SetCfg('skinTrailLife', value)

            skinTrailLife = value

            if skinTrailEnabled then
                updateSkinTrail()
            end
        end,
    })

    local auraSection = CosmeticTab:Section({
        Title = 'Auras',
        Desc = '',
        Icon = 'clover',
        Opened = true,
        Box = true,
        BoxBorder = true,
    })

    auraSection:Toggle({
        Title = 'Enable Local Aura',
        Desc = '',
        Type = 'Toggle',
        Value = C('auraEnabled', false),
        Icon = 'clover',
        Callback = function(value)
            SetCfg('auraEnabled', value)

            auraEnabled = value

            if value then
                if not currentAuraModel then
                    updateAuraLogic()
                end
                if player.Character then
                    enableAura(player.Character)
                end
            else
                disableAura()
            end
        end,
    })

    local auraList = {}

    for k in pairs(AuraModels)do
        table.insert(auraList, k)
    end

    auraSection:Dropdown({
        Title = 'Aura Type',
        Desc = '',
        Values = auraList,
        Value = C('auraType', 'Godly'),
        SearchBarEnabled = true,
        Callback = function(selected)
            SetCfg('auraType', selected)

            auraType = selected
            customAuraID = ''

            if auraEnabled then
                updateAuraLogic()
            end
        end,
    })

    })

    local jumpCirclesEnabled = C('jumpCirclesEnabled', false)
    local jumpCircleColor = C('jumpCircleColor', Color3.fromRGB(0, 255, 255))
    local jumpCircleRainbow = C('jumpCircleRainbow', false)
    local jumpCircleSize = C('jumpCircleSize', 6)
    local jumpCircleTransparency = C('jumpCircleTransparency', 0.35)
    local jumpCircleLifetime = C('jumpCircleLifetime', 0.8)

    local function createJumpCircle(position)
        local ring = Instance.new('Part')

        ring.Name = 'JumpCircle'
        ring.Anchored = true
        ring.CanCollide = false
        ring.CastShadow = false
        ring.Material = Enum.Material.Neon
        ring.Transparency = jumpCircleTransparency
        ring.Color = jumpCircleRainbow and Color3.fromHSV(tick() % 5 / 5, 1, 1) or jumpCircleColor
        ring.Size = Vector3.new(1, 1, 1)
        ring.CFrame = CFrame.new(position) * CFrame.Angles(math.rad(90), 0, 0)

        local mesh = Instance.new('SpecialMesh')

        mesh.MeshType = Enum.MeshType.FileMesh
        mesh.MeshId = 'rbxassetid://3270017'
        mesh.Scale = Vector3.new(jumpCircleSize, jumpCircleSize, 0.15)
        mesh.Parent = ring
        ring.Parent = workspace

        local sizeTween = TweenService:Create(mesh, TweenInfo.new(jumpCircleLifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Scale = Vector3.new(jumpCircleSize + 4, jumpCircleSize + 4, 0.15),
        })
        local fadeTween = TweenService:Create(ring, TweenInfo.new(jumpCircleLifetime), {Transparency = 1})

        sizeTween:Play()
        fadeTween:Play()
        task.delay(jumpCircleLifetime, function()
            if ring then
                ring:Destroy()
            end
        end)
    end
    local function setupJumpCircles(character)
        local humanoid = character:WaitForChild('Humanoid')
        local hrp = character:WaitForChild('HumanoidRootPart')
        local wasInAir = false
        local debounce = false

        RunService.RenderStepped:Connect(function()
            if not jumpCirclesEnabled then
                return
            end
            if not humanoid or humanoid.Health <= 0 then
                return
            end

            local state = humanoid:GetState()

            if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then
                wasInAir = true
            end
            if wasInAir and humanoid.FloorMaterial ~= Enum.Material.Air and not debounce then
                debounce = true
                wasInAir = false

                local pos = hrp.Position - Vector3.new(0, 2.8, 0)

                createJumpCircle(pos)
                task.delay(0.15, function()
                    debounce = false
                end)
            end
        end)
    end

    if player.Character then
        setupJumpCircles(player.Character)
    end

    player.CharacterAdded:Connect(function(char)
        task.wait(1)
        setupJumpCircles(char)
    end)

    local jumpSection = CosmeticTab:Section({
        Title = 'Jump Circles',
        Icon = 'circle',
        Opened = true,
        Box = true,
        BoxBorder = true,
    })

    jumpSection:Toggle({
        Title = 'Enable Jump Circles',
        Value = C('jumpCirclesEnabled', false),
        Callback = function(state)
            SetCfg('jumpCirclesEnabled', state)

            jumpCirclesEnabled = state
        end,
    })
    jumpSection:Toggle({
        Title = 'Rainbow',
        Value = C('jumpCircleRainbow', false),
        Callback = function(state)
            SetCfg('jumpCircleRainbow', state)

            jumpCircleRainbow = state
        end,
    })
    jumpSection:Slider({
        Title = 'Circle Size',
        Value = {
            Min = 2,
            Max = 15,
            Default = C('jumpCircleSize', 6),
        },
        Step = 0.5,
        Callback = function(value)
            SetCfg('jumpCircleSize', value)

            jumpCircleSize = value
        end,
    })
    jumpSection:Slider({
        Title = 'Transparency',
        Value = {
            Min = 0,
            Max = 1,
            Default = C('jumpCircleTransparency', 0.35),
        },
        Step = 0.05,
        Callback = function(value)
            SetCfg('jumpCircleTransparency', value)

            jumpCircleTransparency = value
        end,
    })
    jumpSection:Slider({
        Title = 'Lifetime',
        Value = {
            Min = 0.1,
            Max = 5,
            Default = C('jumpCircleLifetime', 0.8),
        },
        Step = 0.1,
        Callback = function(value)
            SetCfg('jumpCircleLifetime', value)

            jumpCircleLifetime = value
        end,
    })
    jumpSection:Colorpicker({
        Title = 'Circle Color',
        Default = C('jumpCircleColor', Color3.fromRGB(0, 255, 255)),
        Callback = function(color)
            SetCfg('jumpCircleColor', color)

            jumpCircleColor = color
        end,
    })

    local function reapplyVisuals(char)
        task.wait(1)

        if trailEnabled then
            addTrail(char)

            if not trailConnection then
                trailConnection = RunService.Heartbeat:Connect(updateTrails)
            end
        end
        if ffEnabled then
            applyForceField(char)

            if not ffConnection then
                ffConnection = RunService.Heartbeat:Connect(updateForceField)
            end
        end
        if auraEnabled then
            if not currentAuraModel then
                updateAuraLogic()
            end

            enableAura(char)
        end
        if skinTrailEnabled then
            toggleSkinTrail(true)
        end
    end

    player.CharacterAdded:Connect(reapplyVisuals)

    if player.Character then
        reapplyVisuals(player.Character)
    end

    local cosmeticSection = CosmeticTab:Section({
        Title = 'Character',
        Desc = '',
        Icon = 'sparkles',
        Opened = true,
        Box = true,
        BoxBorder = true,
    })
    local korbloxEnabled = C('korbloxEnabled', false)
    local headlessEnabled = C('headlessEnabled', false)

    getgenv().Mscuaz_Korblox = korbloxEnabled
    getgenv().Mscuaz_Headless = headlessEnabled

    local function applyKorbloxHeadless()
        local character = player.Character

        if not character then
            return
        end

        local humanoid = character:FindFirstChildOfClass('Humanoid')

        if not humanoid then
            return
        end
        if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
            warn('Korblox & Headless works only on R15.')

            return
        end

        getgenv().Mscuaz_Korblox = korbloxEnabled
        getgenv().Mscuaz_Headless = headlessEnabled
        getgenv().MscuazScriptIsTheBest = 'MscuazScripter'

        loadstring(game:HttpGet('https://raw.githubusercontent.com/gwnrdt/Try/refs/heads/main/Headless%26Korblox.lua'))()
    end

    cosmeticSection:Toggle({
        Title = 'Korblox [Only Mobile + R15]',
        Value = C('korbloxEnabled', false),
        Callback = function(state)
            SetCfg('korbloxEnabled', state)

            korbloxEnabled = state

            if state then
                applyKorbloxHeadless()
            else
                getgenv().Mscuaz_Korblox = false
            end
        end,
    })
    cosmeticSection:Toggle({
        Title = 'Headless',
        Value = C('headlessEnabled', false),
        Callback = function(state)
            SetCfg('headlessEnabled', state)

            headlessEnabled = state

            if state then
                applyKorbloxHeadless()
            else
                getgenv().Mscuaz_Headless = false
            end
        end,
    })
    player.CharacterAdded:Connect(function(char)
        task.wait(1)

        if korbloxEnabled or headlessEnabled then
            applyKorbloxHeadless()
        end
    end)

    if player.Character then
        task.spawn(function()
            task.wait(1)

            if korbloxEnabled or headlessEnabled then
                applyKorbloxHeadless()
            end
        end)
    end
end

_initCosmetic()

local function _initUtilities()
    local defaultLighting = {
        Brightness = Lighting.Brightness,
        ClockTime = Lighting.ClockTime,
        GlobalShadows = Lighting.GlobalShadows,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        Ambient = Lighting.Ambient,
        FogStart = Lighting.FogStart,
        FogEnd = Lighting.FogEnd,
        FogColor = Lighting.FogColor,
    }
    local DefaultSky = Lighting:FindFirstChildOfClass('Sky')
    local DefaultSkySettings = {}

    if DefaultSky then
        DefaultSkySettings.SkyboxBk = DefaultSky.SkyboxBk
        DefaultSkySettings.SkyboxDn = DefaultSky.SkyboxDn
        DefaultSkySettings.SkyboxFt = DefaultSky.SkyboxFt
        DefaultSkySettings.SkyboxLf = DefaultSky.SkyboxLf
        DefaultSkySettings.SkyboxRt = DefaultSky.SkyboxRt
        DefaultSkySettings.SkyboxUp = DefaultSky.SkyboxUp
    end

    warn('utilities tab loaded')

    local UtilitiesTab = Window:Tab({
        Title = 'Utilities',
        Icon = 'wrench',
        ShowTabTitle = true,
        Border = true,
    })
    local speedSection = UtilitiesTab:Section({
        Title = 'Speed Glitch',
        Desc = '',
        Icon = 'zap',
        Opened = true,
        Box = true,
        BoxBorder = true,
    })
    local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local Humanoid = Character:WaitForChild('Humanoid')
    local HRP = Character:WaitForChild('HumanoidRootPart')
    local speedGlitchEnabled = C('speedGlitchEnabled', false)
    local speedValue = C('speedValue', 50)
    local speedGlitchBind = C('speedGlitchBind', 'G')
    local speedButtonVisible = C('speedButtonVisible', false)
    local speedButtonEditMode = C('speedButtonEditMode', false)
    local speedButtonSize = C('speedButtonSize', 70)
    local speedGui = nil
    local speedButton = nil

    local function SaveSpeedBtnPos(pos, name)
        pcall(function()
            if writefile then
                local folder = 'ludexioso_visuals'

                if not isfolder(folder) then
                    makefolder(folder)
                end

                writefile(folder .. '/' .. name .. 'Pos.json', HttpService:JSONEncode({
                    X = {
                        Scale = pos.X.Scale,
                        Offset = pos.X.Offset,
                    },
                    Y = {
                        Scale = pos.Y.Scale,
                        Offset = pos.Y.Offset,
                    },
                }))
            end
        end)
    end
    local function LoadSpeedBtnPos(name)
        local success, result = pcall(function()
            if readfile and isfile and isfile('ludexioso_visuals/' .. name .. 'Pos.json') then
                return HttpService:JSONDecode(readfile('ludexioso_visuals/' .. name .. 'Pos.json'))
            end
        end)

        if success and result then
            return UDim2.new(result.X.Scale, result.X.Offset, result.Y.Scale, result.Y.Offset)
        end

        return nil
    end
    local function setupSpeedGlitchButton()
        if speedGui then
            speedGui:Destroy()
        end

        local gui = Instance.new('ScreenGui')

        gui.Name = 'SpeedGlitchUI'
        gui.ResetOnSpawn = false
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        gui.Parent = LocalPlayer:WaitForChild('PlayerGui')
        speedGui = gui

        local size = speedButtonSize
        local btnPos = LoadSpeedBtnPos('SpeedGlitch') or UDim2.new(0.5, -size / 2, 0.22, 0)
        local button = Instance.new('TextButton')

        button.Name = 'SpeedGlitchButton'
        button.Parent = gui
        button.Size = UDim2.new(0, size, 0, size)
        button.Position = btnPos
        button.Text = speedButtonEditMode and 'MV' or 'SG'
        button.TextScaled = false
        button.TextSize = math.floor(size * 0.42)
        button.Font = Enum.Font.Code
        button.TextColor3 = Color3.fromRGB(220, 230, 255)
        button.BackgroundTransparency = 1
        button.TextStrokeTransparency = 0.75
        button.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        button.Active = true
        button.AutoButtonColor = false
        button.Visible = speedButtonVisible
        button.ZIndex = 100
        speedButton = button

        local corner = Instance.new('UICorner')

        corner.CornerRadius = UDim.new(0.5, 0)
        corner.Parent = button

        local innerGlow = Instance.new('Frame')

        innerGlow.Name = 'InnerGlow'
        innerGlow.Parent = button
        innerGlow.AnchorPoint = Vector2.new(0.5, 0.5)
        innerGlow.Position = UDim2.new(0.5, 0, 0.5, 0)
        innerGlow.Size = UDim2.new(1, -8, 1, -8)
        innerGlow.BackgroundTransparency = speedButtonEditMode and 0.85 or 0.92
        innerGlow.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        innerGlow.ZIndex = 98

        local innerCorner = Instance.new('UICorner')

        innerCorner.CornerRadius = UDim.new(0.5, 0)
        innerCorner.Parent = innerGlow

        local innerGradient = Instance.new('UIGradient')

        innerGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 60)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 100, 255)),
        })
        innerGradient.Rotation = 45
        innerGradient.Parent = innerGlow

        TweenService:Create(innerGradient, TweenInfo.new(3, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true), {Rotation = 405}):Play()

        local stroke = Instance.new('UIStroke')

        stroke.Thickness = 2.5
        stroke.Color = Color3.fromRGB(255, 255, 255)
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.LineJoinMode = Enum.LineJoinMode.Round
        stroke.Parent = button

        TweenService:Create(stroke, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
            Color = Color3.fromRGB(0, 100, 255),
        }):Play()

        local function PlayClickAnimation()
            local currentSize = button.Size.X.Offset
            local tweenDown = TweenService:Create(button, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, currentSize * 0.85, 0, currentSize * 0.85),
            })
            local tweenUp = TweenService:Create(button, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, currentSize, 0, currentSize),
            })

            tweenDown:Play()
            tweenDown.Completed:Connect(function()
                tweenUp:Play()
            end)

            local ripple = Instance.new('Frame')

            ripple.Name = 'Ripple'
            ripple.Parent = button
            ripple.AnchorPoint = Vector2.new(0.5, 0.5)
            ripple.Position = UDim2.new(0.5, 0, 0.5, 0)
            ripple.Size = UDim2.new(0, 0, 0, 0)
            ripple.BackgroundTransparency = 1
            ripple.ZIndex = 101

            local rippleCorner = Instance.new('UICorner')

            rippleCorner.CornerRadius = UDim.new(0.5, 0)
            rippleCorner.Parent = ripple

            local rippleStroke = Instance.new('UIStroke')

            rippleStroke.Thickness = 2
            rippleStroke.Color = Color3.fromRGB(255, 255, 255)
            rippleStroke.Parent = ripple

            TweenService:Create(ripple, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(1.8, 0, 1.8, 0),
            }):Play()
            TweenService:Create(rippleStroke, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = 1}):Play()
            task.delay(0.5, function()
                if ripple then
                    ripple:Destroy()
                end
            end)

            local originalColor = stroke.Color

            stroke.Color = Color3.fromRGB(80, 150, 255)

            task.delay(0.12, function()
                stroke.Color = originalColor
            end)
        end

        local dragging = false
        local dragStart
        local startPos

        button.InputBegan:Connect(function(input)
            if not speedButtonEditMode then
                return
            end
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = button.Position
            end
        end)
        UIS.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                if dragging and speedButtonEditMode then
                    SaveSpeedBtnPos(button.Position, 'SpeedGlitch')
                end

                dragging = false
            end
        end)
        UIS.InputChanged:Connect(function(input)
            if not speedButtonEditMode then
                return
            end
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart

                button.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
        button.MouseButton1Click:Connect(function()
            if speedButtonEditMode then
                return
            end

            PlayClickAnimation()

            speedGlitchEnabled = not speedGlitchEnabled

            SetCfg('speedGlitchEnabled', speedGlitchEnabled)

            if speedToggle and speedToggle.Set then
                speedToggle:Set(speedGlitchEnabled)
            end

            WindUI:Notify({
                Title = 'Speed Glitch',
                Content = 'Speed Glitch ' .. (speedGlitchEnabled and 'activated \u{1f7e2}' or 'deactivated \u{1f534}'),
                Duration = 2,
            })
        end)

        getgenv().SpeedGlitchPlayAnim = PlayClickAnimation
        getgenv().SpeedGlitchUpdateEditMode = function()
            if not button then
                return
            end

            button.Text = speedButtonEditMode and 'MV' or 'SG'
            button.BackgroundTransparency = speedButtonEditMode and 0.95 or 1
            innerGlow.BackgroundTransparency = speedButtonEditMode and 0.85 or 0.92
        end
        getgenv().SpeedGlitchUpdateVisible = function()
            if button then
                button.Visible = speedButtonVisible
            end
        end
        getgenv().SpeedGlitchUpdateSize = function(newSize)
            if not button then
                return
            end

            button.Size = UDim2.new(0, newSize, 0, newSize)
            button.TextSize = math.floor(newSize * 0.42)
        end
    end

    setupSpeedGlitchButton()
    LocalPlayer.CharacterAdded:Connect(function(char)
        Character = char
        Humanoid = Character:WaitForChild('Humanoid')
        HRP = Character:WaitForChild('HumanoidRootPart')

        task.delay(1, function()
            if speedGui then
                speedGui:Destroy()
            end

            setupSpeedGlitchButton()

            if getgenv().SpeedGlitchUpdateVisible then
                getgenv().SpeedGlitchUpdateVisible()
            end
            if getgenv().SpeedGlitchUpdateEditMode then
                getgenv().SpeedGlitchUpdateEditMode()
            end
        end)
    end)
    RunService.Heartbeat:Connect(function()
        if speedGlitchEnabled and Character and Humanoid and HRP then
            if Humanoid:GetState() == Enum.HumanoidStateType.Climbing then
                return
            end
            if Humanoid.FloorMaterial == Enum.Material.Air then
                local moveDir = Humanoid.MoveDirection

                if moveDir.Magnitude > 0 then
                    local vel = HRP.AssemblyLinearVelocity
                    local newVel = Vector3.new(moveDir.X * speedValue, vel.Y, moveDir.Z * speedValue)

                    HRP.AssemblyLinearVelocity = newVel
                end
            end
        end
    end)

    local speedToggle = speedSection:Toggle({
        Title = 'Enable Speed Glitch',
        Value = C('speedGlitchEnabled', false),
        Callback = function(state)
            SetCfg('speedGlitchEnabled', state)

            speedGlitchEnabled = state
        end,
    })

    speedSection:Slider({
        Title = 'Speed',
        Value = {
            Min = 1,
            Max = 300,
            Default = C('speedValue', 50),
        },
        Step = 1,
        IsTextbox = true,
        Callback = function(value)
            SetCfg('speedValue', value)

            speedValue = value
        end,
    })
    speedSection:Keybind({
        Title = 'Speed Glitch Bind',
        Value = C('speedGlitchBind', 'G'),
        Callback = function()
            speedGlitchEnabled = not speedGlitchEnabled
            SetCfg('speedGlitchEnabled', speedGlitchEnabled)

            if speedToggle and speedToggle.Set then
                speedToggle:Set(speedGlitchEnabled)
            end

            WindUI:Notify({
                Title = 'Speed Glitch',
                Content = 'Speed Glitch ' .. (speedGlitchEnabled and 'enabled' or 'disabled'),
                Duration = 2,
            })
        end,
    })
    speedSection:Toggle({
        Title = 'Show Button',
        Value = C('speedButtonVisible', false),
        Callback = function(state)
            SetCfg('speedButtonVisible', state)

            speedButtonVisible = state

            if getgenv().SpeedGlitchUpdateVisible then
                getgenv().SpeedGlitchUpdateVisible()
            end
        end,
    })
    speedSection:Toggle({
        Title = 'Edit Mode',
        Value = C('speedButtonEditMode', false),
        Callback = function(state)
            SetCfg('speedButtonEditMode', state)

            speedButtonEditMode = state

            if getgenv().SpeedGlitchUpdateEditMode then
                getgenv().SpeedGlitchUpdateEditMode()
            end
        end,
    })
    speedSection:Slider({
        Title = 'Button Size',
        Value = {
            Min = 20,
            Max = 200,
            Default = C('speedButtonSize', 70),
        },
        Step = 1,
        Callback = function(value)
            SetCfg('speedButtonSize', value)

            speedButtonSize = value

            if getgenv().SpeedGlitchUpdateSize then
                getgenv().SpeedGlitchUpdateSize(value)
            end
        end,
    })

    local spinBotEnabled = C('spinBotEnabled', false)
    local spinBotDelay = C('spinBotDelay', 0.1)
    local spinBotThread

    speedSection:Toggle({
        Title = 'Spin Bot',
        Value = C('spinBotEnabled', false),
        Callback = function(state)
            SetCfg('spinBotEnabled', state)

            spinBotEnabled = state

            if state then
                spinBotThread = task.spawn(function()
                    while spinBotEnabled do
                        local char = player.Character
                        local humanoid = char and char:FindFirstChild('Humanoid')

                        if char and char.PrimaryPart and humanoid and humanoid.FloorMaterial == Enum.Material.Air then
                            local randomAngle = math.random(0, 360)

                            char:SetPrimaryPartCFrame(CFrame.new(char.PrimaryPart.Position) * CFrame.Angles(0, math.rad(randomAngle), 0))
                        end

                        task.wait(spinBotDelay)
                    end
                end)
            end
        end,
    })
    speedSection:Slider({
        Title = 'Spin Delay',
        Value = {
            Min = 0.01,
            Max = 1,
            Default = C('spinBotDelay', 0.1),
        },
        Step = 0.01,
        IsTextbox = true,
        Callback = function(value)
            SetCfg('spinBotDelay', value)

            spinBotDelay = value
        end,
    })

    local wallHopEnabled = C('wallHopEnabled', false)
    local wallHopCooldown = false
    local raycastParams = RaycastParams.new()

    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist

    local wallHopSection = UtilitiesTab:Section({
        Title = 'WallHop',
        Desc = '',
        Icon = 'move',
        Opened = true,
        Box = true,
        BoxBorder = true,
    })

    local function getWallRaycastResult()
        local character = player.Character

        if not character then
            return nil
        end

        local hrp = character:FindFirstChild('HumanoidRootPart')

        if not hrp then
            return nil
        end

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

        for _, direction in pairs(directions)do
            local ray = workspace:Raycast(hrp.Position, direction * detectionDistance, raycastParams)

            if ray and ray.Instance then
                if ray.Distance < minDistance then
                    minDistance = ray.Distance
                    closestHit = ray
                end
            end
        end

        return closestHit
    end

    wallHopSection:Toggle({
        Title = 'Enable WallHop',
        Value = C('wallHopEnabled', false),
        Callback = function(state)
            SetCfg('wallHopEnabled', state)

            wallHopEnabled = state
        end,
    })
    UIS.JumpRequest:Connect(function()
        if not wallHopEnabled or wallHopCooldown then
            return
        end

        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass('Humanoid')
        local rootPart = character and character:FindFirstChild('HumanoidRootPart')
        local cam = workspace.CurrentCamera

        if not (humanoid and rootPart and cam) then
            return
        end

        local wallRayResult = getWallRaycastResult()

        if wallRayResult then
            wallHopCooldown = true

            local wallNormal = wallRayResult.Normal
            local horizontalWallNormal = Vector3.new(wallNormal.X, 0, wallNormal.Z).Unit

            if horizontalWallNormal.Magnitude < 0.1 then
                horizontalWallNormal = (rootPart.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit

                if horizontalWallNormal.Magnitude < 0.1 then
                    horizontalWallNormal = Vector3.new(0, 0, -1)
                end
            end

            local baseDirectionAwayFromWall = horizontalWallNormal
            local cameraLook = cam.CFrame.LookVector
            local horizontalCameraLook = Vector3.new(cameraLook.X, 0, cameraLook.Z).Unit

            if horizontalCameraLook.Magnitude < 0.1 then
                horizontalCameraLook = baseDirectionAwayFromWall
            end

            local maxInfluenceAngle = math.rad(40)
            local dot = math.clamp(baseDirectionAwayFromWall:Dot(horizontalCameraLook), -1, 1)
            local angleBetween = math.acos(dot)
            local cross = baseDirectionAwayFromWall:Cross(horizontalCameraLook)
            local rotationSign = math.sign(cross.Y)

            if rotationSign == 0 then
                angleBetween = 0
            end

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
        end
    end)


    local espSection = UtilitiesTab:Section({
        Title = 'Distance ESP',
        Desc = 'Shows only the distance to other players.',
        Icon = 'eye',
        Opened = true,
        Box = true,
        BoxBorder = true,
    })

    local distanceEspEnabled = C('esp_DistEnabled', false)
    local distanceRenderDistance = C('esp_RenderDistance', 200)
    local distanceColor = C('esp_DistColor', Color3.fromRGB(255, 255, 255))
    local distanceTextSize = C('esp_DistTextSize', 5)
    local distanceLabels = {}

    local function destroyDistanceLabel(plr)
        local gui = distanceLabels[plr]
        if gui then
            gui:Destroy()
            distanceLabels[plr] = nil
        end
    end

    local function getDistanceLabel(plr, hrp)
        local gui = distanceLabels[plr]
        if gui and gui.Parent ~= hrp then
            gui:Destroy()
            gui = nil
            distanceLabels[plr] = nil
        end

        if not gui then
            gui = Instance.new('BillboardGui')
            gui.Name = 'LudexiosoDistanceESP'
            gui.AlwaysOnTop = true
            gui.Size = UDim2.new(0, 150, 0, 32)
            gui.StudsOffset = Vector3.new(0, -3, 0)
            gui.Parent = hrp

            local text = Instance.new('TextLabel')
            text.Name = 'DistanceText'
            text.Size = UDim2.fromScale(1, 1)
            text.BackgroundTransparency = 1
            text.TextStrokeTransparency = 0.45
            text.TextStrokeColor3 = Color3.new(0, 0, 0)
            text.Font = Enum.Font.Code
            text.TextXAlignment = Enum.TextXAlignment.Center
            text.TextYAlignment = Enum.TextYAlignment.Center
            text.Parent = gui

            distanceLabels[plr] = gui
        end

        return gui
    end

    local function clearDistanceESP()
        for plr in pairs(distanceLabels) do
            destroyDistanceLabel(plr)
        end
    end

    Players.PlayerRemoving:Connect(function(plr)
        destroyDistanceLabel(plr)
    end)

    RunService.RenderStepped:Connect(function()
        if not distanceEspEnabled then
            for _, gui in pairs(distanceLabels) do
                gui.Enabled = false
            end
            return
        end

        local localCharacter = LocalPlayer.Character
        local localRoot = localCharacter and localCharacter:FindFirstChild('HumanoidRootPart')
        if not localRoot then
            return
        end

        local active = {}

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                local character = plr.Character
                local hrp = character and character:FindFirstChild('HumanoidRootPart')
                local humanoid = character and character:FindFirstChildOfClass('Humanoid')

                if hrp and humanoid and humanoid.Health > 0 then
                    local distance = (localRoot.Position - hrp.Position).Magnitude
                    local gui = getDistanceLabel(plr, hrp)
                    local text = gui:FindFirstChild('DistanceText')

                    gui.MaxDistance = distanceRenderDistance
                    gui.Enabled = distance <= distanceRenderDistance

                    if text then
                        text.Text = tostring(math.floor(distance + 0.5)) .. ' studs'
                        text.TextColor3 = distanceColor
                        text.TextSize = distanceTextSize
                    end

                    active[plr] = true
                end
            end
        end

        for plr in pairs(distanceLabels) do
            if not active[plr] then
                destroyDistanceLabel(plr)
            end
        end
    end)

    espSection:Toggle({
        Title = 'Enable Distance ESP',
        Value = C('esp_DistEnabled', false),
        Callback = function(state)
            SetCfg('esp_DistEnabled', state)
            distanceEspEnabled = state
            if not state then
                clearDistanceESP()
            end
        end,
    })

    espSection:Slider({
        Title = 'Render Distance',
        Value = {
            Min = 50,
            Max = 2000,
            Default = C('esp_RenderDistance', 200),
        },
        Step = 50,
        Callback = function(value)
            SetCfg('esp_RenderDistance', value)
            distanceRenderDistance = value
        end,
    })

    espSection:Colorpicker({
        Title = 'Distance Color',
        Default = C('esp_DistColor', Color3.fromRGB(255, 255, 255)),
        Callback = function(color)
            SetCfg('esp_DistColor', color)
            distanceColor = color
        end,
    })

    espSection:Slider({
        Title = 'Text Size',
        Value = {
            Min = 1,
            Max = 20,
            Default = C('esp_DistTextSize', 5),
        },
        Step = 1,
        Callback = function(value)
            SetCfg('esp_DistTextSize', value)
            distanceTextSize = value
        end,
    })


    local shiftSection = UtilitiesTab:Section({
        Title = 'ShiftLock[only phone!]',
        Desc = '',
        Icon = 'mouse-pointer',
        Opened = true,
        Box = true,
        BoxBorder = true,
    })
    local shiftEnabled = C('shiftEnabled', false)
    local shiftSpinEnabled = C('shiftSpinEnabled', false)
    local shiftSpinSpeed = C('shiftSpinSpeed', 5)
    local shiftSpinDirection = C('shiftSpinDirection', 'Right')
    local shiftCursorWidth = C('shiftCursorWidth', 32)
    local shiftCursorHeight = C('shiftCursorHeight', 32)
    local shiftRotation = 0
    local shiftObjects = {}
    local CursorMap = {
        Green = 'rbxassetid://11927621846',
        Purple = 'rbxassetid://11927593271',
        Blue = 'rbxassetid://11934534450',
        Cyan = 'rbxassetid://11927574847',
        ['Blu notful'] = 'rbxassetid://95871237116034',
        ['Blu star'] = 'rbxassetid://11716557686',
        ['White circle'] = 'rbxassetid://98322941706613',
        ['Spawn roboblox'] = 'rbxassetid://83520160375628',
        ['Angel Sahur'] = 'rbxassetid://128878142732909',
        ['White circles ay blyat'] = 'rbxassetid://116983963395648',
        ['Nikiliss shiftlock'] = 'rbxassetid://134047116604554',
        ['Red circles'] = 'rbxassetid://109913835522060',
        ['Heart 1'] = 'rbxassetid://88440417174442',
        ['Gray circle'] = 'rbxassetid://79184859368119',
        ['Red star'] = 'rbxassetid://73038181685886',
        ['White heart'] = 'rbxassetid://92154647211527',
        ['Black heart'] = 'rbxassetid://111025831598904',
        ['Pink circle'] = 'rbxassetid://81221855342501',
        ['Shooter aim 2'] = 'rbxassetid://124007606116932',
        ['Evil sahur'] = 'rbxassetid://125269217374166',
        ['Shooter aim 3'] = 'rbxassetid://87787133926543',
        ['White dot'] = 'rbxassetid://311756276',
        X = 'rbxassetid://5689419560',
        ['Heart 2'] = 'rbxassetid://11754490336',
    }
    local savedCursorName = C('shiftCursorName', 'Green')
    local shiftSelectedCursor = CursorMap[savedCursorName] or 'rbxassetid://11927621846'
    local DefaultImages = {
        'rbxasset://textures/MouseLockedCursor.png',
        'rbxasset://textures/MouseLockedCursor@2x.png',
    }

    local function ScanShiftLock()
        shiftObjects = {}

        for _, v in pairs(game:GetDescendants())do
            if v:IsA('ImageLabel') or v:IsA('ImageButton') then
                if table.find(DefaultImages, v.Image) or string.find(string.lower(v.Name), 'shift') or string.find(string.lower(v.Name), 'lock') then
                    table.insert(shiftObjects, v)
                end
            end
        end
    end
    local function ApplyShiftSize(v)
        v.Size = UDim2.new(0, math.clamp(shiftCursorWidth, 1, 100), 0, math.clamp(shiftCursorHeight, 1, 100))
        v.ImageTransparency = 0
        v.BackgroundTransparency = 1
        v.ScaleType = Enum.ScaleType.Fit
    end
    local function UpdateShiftLock()
        for _, v in pairs(shiftObjects)do
            if v and v.Parent then
                if shiftEnabled then
                    v.Image = shiftSelectedCursor

                    ApplyShiftSize(v)
                else
                    v.Image = 'rbxasset://textures/MouseLockedCursor.png'
                    v.Rotation = 0
                    v.Size = UDim2.new(0, 32, 0, 32)
                end
            end
        end
    end

    RunService.RenderStepped:Connect(function()
        if shiftSpinEnabled and shiftEnabled then
            if shiftSpinDirection == 'Right' then
                shiftRotation += shiftSpinSpeed
            else
                shiftRotation -= shiftSpinSpeed
            end

            for _, v in pairs(shiftObjects)do
                if v and v.Parent then
                    v.Rotation = shiftRotation

                    ApplyShiftSize(v)
                end
            end
        end
    end)
    game.DescendantAdded:Connect(function(v)
        task.wait(1)

        if v:IsA('ImageLabel') or v:IsA('ImageButton') then
            if table.find(DefaultImages, v.Image) or string.find(string.lower(v.Name), 'shift') or string.find(string.lower(v.Name), 'lock') then
                table.insert(shiftObjects, v)

                if shiftEnabled then
                    v.Image = shiftSelectedCursor

                    ApplyShiftSize(v)
                end
            end
        end
    end)
    ScanShiftLock()
    shiftSection:Toggle({
        Title = 'Enable Custom ShiftLock',
        Value = C('shiftEnabled', false),
        Callback = function(Value)
            SetCfg('shiftEnabled', Value)

            shiftEnabled = Value

            UpdateShiftLock()
        end,
    })
    shiftSection:Dropdown({
        Title = 'Choose Cursor',
        Values = {
            'Green',
            'Purple',
            'Blue',
            'Cyan',
            'Blu notful',
            'Blu star',
            'White circle',
            'Spawn roboblox',
            'Angel Sahur',
            'White circles ay blyat',
            'Nikiliss shiftlock',
            'Red circles',
            'Heart 1',
            'Gray circle',
            'Red star',
            'White heart',
            'Black heart',
            'Pink circle',
            'Shooter aim 2',
            'Evil sahur',
            'Shooter aim 3',
            'White dot',
            'X',
            'Heart 2',
        },
        Value = savedCursorName,
        Callback = function(Value)
            SetCfg('shiftCursorName', Value)

            shiftSelectedCursor = CursorMap[Value]

            UpdateShiftLock()
        end,
    })
    shiftSection:Toggle({
        Title = 'Spin ShiftLock',
        Value = C('shiftSpinEnabled', false),
        Callback = function(Value)
            SetCfg('shiftSpinEnabled', Value)

            shiftSpinEnabled = Value
        end,
    })
    shiftSection:Slider({
        Title = 'Spin Speed',
        Value = {
            Min = 0.1,
            Max = 500,
            Default = C('shiftSpinSpeed', 5),
        },
        Step = 0.1,
        Callback = function(Value)
            SetCfg('shiftSpinSpeed', Value)

            shiftSpinSpeed = Value
        end,
    })
    shiftSection:Dropdown({
        Title = 'Spin Direction',
        Values = {
            'Left',
            'Right',
        },
        Value = C('shiftSpinDirection', 'Right'),
        Callback = function(Value)
            SetCfg('shiftSpinDirection', Value)

            shiftSpinDirection = Value
        end,
    })
    shiftSection:Slider({
        Title = 'Cursor Width',
        Value = {
            Min = 1,
            Max = 100,
            Default = C('shiftCursorWidth', 32),
        },
        Step = 1,
        Callback = function(Value)
            SetCfg('shiftCursorWidth', Value)

            shiftCursorWidth = Value

            UpdateShiftLock()
        end,
    })
    shiftSection:Slider({
        Title = 'Cursor Height',
        Value = {
            Min = 1,
            Max = 100,
            Default = C('shiftCursorHeight', 32),
        },
        Step = 1,
        Callback = function(Value)
            SetCfg('shiftCursorHeight', Value)

            shiftCursorHeight = Value

            UpdateShiftLock()
        end,
    })


    local crosshairEnabled = C('crosshairEnabled', false)
    local crosshairRefreshRate = C('crosshairRefreshRate', 0)
    local crosshairMode = C('crosshairMode', 'mouse')
    local crosshairWidth = C('crosshairWidth', 1.5)
    local crosshairLength = C('crosshairLength', 10)
    local crosshairRadius = C('crosshairRadius', 11)
    local crosshairColor = C('crosshairColor', Color3.fromRGB(199, 110, 255))
    local crosshairSpin = C('crosshairSpin', true)
    local crosshairSpinSpeed = C('crosshairSpinSpeed', 150)
    local crosshairSpinMax = C('crosshairSpinMax', 340)
    local crosshairSpinStyle = C('crosshairSpinStyle', 'Sine')
    local crosshairResize = C('crosshairResize', true)
    local crosshairResizeSpeed = C('crosshairResizeSpeed', 150)
    local crosshairResizeMin = C('crosshairResizeMin', 5)
    local crosshairResizeMax = C('crosshairResizeMax', 22)
    local crosshairDrawings = {}
    local crosshairTexts = {}
    local crosshairConnection = nil

    local function createCrosshairDrawing(class, properties)
        if not Drawing or not Drawing.new then
            return nil
        end

        local drawing = Drawing.new(class)

        if drawing and properties then
            for i, v in next, properties do
                pcall(function()
                    drawing[i] = v
                end)
            end
        end

        return drawing
    end
    local function solveCrosshair(angle, radius)
        return Vector2.new(math.sin(math.rad(angle)) * radius, math.cos(math.rad(angle)) * radius)
    end
    local function initCrosshairDrawings()
        for i = 1, 8 do
            if not crosshairDrawings[i] then
                crosshairDrawings[i] = createCrosshairDrawing('Line')
            end
        end

        if not crosshairTexts[1] then
            crosshairTexts[1] = createCrosshairDrawing('Text', {
                Size = 13,
                Font = 2,
                Outline = true,
                Text = '.',
                Color = Color3.new(1, 1, 1),
            })
        end
        if not crosshairTexts[2] then
            crosshairTexts[2] = createCrosshairDrawing('Text', {
                Size = 13,
                Font = 2,
                Outline = true,
                Text = 'ludexioso_visuals',
                Color = Color3.new(1, 1, 1),
            })
        end
    end
    local function removeCrosshairDrawings()
        for i = 1, 8 do
            if crosshairDrawings[i] then
                crosshairDrawings[i].Visible = false
            end
        end
        for i = 1, 2 do
            if crosshairTexts[i] then
                crosshairTexts[i].Visible = false
            end
        end
    end
    local function startCrosshair()
        if crosshairConnection then
            crosshairConnection:Disconnect()
        end

        initCrosshairDrawings()

        local lastRender = 0

        crosshairConnection = RunService.PostSimulation:Connect(function()
            if not crosshairEnabled then
                removeCrosshairDrawings()

                return
            end

            local _tick = tick()

            if _tick - lastRender > crosshairRefreshRate then
                lastRender = _tick

                local position

                if crosshairMode == 'center' then
                    position = camera.ViewportSize / 2
                elseif crosshairMode == 'mouse' then
                    position = UIS:GetMouseLocation()
                else
                    position = Vector2.new(0, 0)
                end

                local textX = 0

                pcall(function()
                    if crosshairTexts[1] and crosshairTexts[2] then
                        textX = crosshairTexts[1].TextBounds.X + crosshairTexts[2].TextBounds.X
                    end
                end)

                if crosshairTexts[1] then
                    crosshairTexts[1].Visible = true
                    crosshairTexts[1].Position = position + Vector2.new(-textX / 2, crosshairRadius + (crosshairResize and crosshairResizeMax or crosshairLength) + 15)
                end
                if crosshairTexts[2] then
                    crosshairTexts[2].Visible = true
                    crosshairTexts[2].Position = crosshairTexts[1].Position + Vector2.new(crosshairTexts[1].TextBounds.X, 0)
                    crosshairTexts[2].Color = crosshairColor
                end

                for idx = 1, 4 do
                    local outline = crosshairDrawings[idx]
                    local inline = crosshairDrawings[idx + 4]

                    if outline and inline then
                        local angle = (idx - 1) * 90
                        local length = crosshairLength

                        if crosshairSpin then
                            local spinAngle = -_tick * crosshairSpinSpeed % crosshairSpinMax
                            local easingStyle = Enum.EasingStyle[crosshairSpinStyle] or Enum.EasingStyle.Sine

                            angle = angle + TweenService:GetValue(spinAngle / 360, easingStyle, Enum.EasingDirection.InOut) * 360
                        end
                        if crosshairResize then
                            local resizeLength = tick() * crosshairResizeSpeed % 180

                            length = crosshairResizeMin + math.sin(math.rad(resizeLength)) * crosshairResizeMax
                        end

                        inline.Visible = true
                        inline.Color = crosshairColor
                        inline.From = position + solveCrosshair(angle, crosshairRadius)
                        inline.To = position + solveCrosshair(angle, crosshairRadius + length)
                        inline.Thickness = crosshairWidth
                        outline.Visible = true
                        outline.From = position + solveCrosshair(angle, crosshairRadius - 1)
                        outline.To = position + solveCrosshair(angle, crosshairRadius + length + 1)
                        outline.Thickness = crosshairWidth + 1.5
                    end
                end
            end
        end)
    end
    local function stopCrosshair()
        removeCrosshairDrawings()

        if crosshairConnection then
            crosshairConnection:Disconnect()

            crosshairConnection = nil
        end
    end

    if crosshairEnabled then
        startCrosshair()
    end

    local crosshairSection = UtilitiesTab:Section({
        Title = 'Crosshair[only pc](beta lol)',
        Desc = 'Custom drawing crosshair',
        Icon = 'crosshair',
        Opened = true,
        Box = true,
        BoxBorder = true,
    })

    crosshairSection:Toggle({
        Title = 'Enable Crosshair',
        Value = C('crosshairEnabled', false),
        Callback = function(state)
            SetCfg('crosshairEnabled', state)

            crosshairEnabled = state

            if state then
                startCrosshair()
            else
                stopCrosshair()
            end
        end,
    })
    crosshairSection:Dropdown({
        Title = 'Mode',
        Values = {
            'mouse',
            'center',
        },
        Value = C('crosshairMode', 'mouse'),
        Callback = function(selected)
            SetCfg('crosshairMode', selected)

            crosshairMode = selected
        end,
    })
    crosshairSection:Slider({
        Title = 'Width',
        Value = {
            Min = 0.5,
            Max = 5,
            Default = C('crosshairWidth', 1.5),
        },
        Step = 0.1,
        Callback = function(value)
            SetCfg('crosshairWidth', value)

            crosshairWidth = value
        end,
    })
    crosshairSection:Slider({
        Title = 'Length',
        Value = {
            Min = 1,
            Max = 50,
            Default = C('crosshairLength', 10),
        },
        Step = 1,
        Callback = function(value)
            SetCfg('crosshairLength', value)

            crosshairLength = value
        end,
    })
    crosshairSection:Slider({
        Title = 'Radius',
        Value = {
            Min = 0,
            Max = 50,
            Default = C('crosshairRadius', 11),
        },
        Step = 1,
        Callback = function(value)
            SetCfg('crosshairRadius', value)

            crosshairRadius = value
        end,
    })
    crosshairSection:Colorpicker({
        Title = 'Color',
        Default = C('crosshairColor', Color3.fromRGB(199, 110, 255)),
        Callback = function(color)
            SetCfg('crosshairColor', color)

            crosshairColor = color
        end,
    })
    crosshairSection:Toggle({
        Title = 'Spin',
        Value = C('crosshairSpin', true),
        Callback = function(state)
            SetCfg('crosshairSpin', state)

            crosshairSpin = state
        end,
    })
    crosshairSection:Slider({
        Title = 'Spin Speed',
        Value = {
            Min = 0,
            Max = 500,
            Default = C('crosshairSpinSpeed', 150),
        },
        Step = 1,
        Callback = function(value)
            SetCfg('crosshairSpinSpeed', value)

            crosshairSpinSpeed = value
        end,
    })
    crosshairSection:Slider({
        Title = 'Spin Max',
        Value = {
            Min = 0,
            Max = 360,
            Default = C('crosshairSpinMax', 340),
        },
        Step = 1,
        Callback = function(value)
            SetCfg('crosshairSpinMax', value)

            crosshairSpinMax = value
        end,
    })
    crosshairSection:Dropdown({
        Title = 'Spin Style',
        Values = {
            'Linear',
            'Sine',
            'Back',
            'Quad',
            'Quart',
            'Quint',
            'Bounce',
            'Elastic',
            'Exponential',
            'Circular',
            'Cubic',
        },
        Value = C('crosshairSpinStyle', 'Sine'),
        Callback = function(selected)
            SetCfg('crosshairSpinStyle', selected)

            crosshairSpinStyle = selected
        end,
    })
    crosshairSection:Toggle({
        Title = 'Resize',
        Value = C('crosshairResize', true),
        Callback = function(state)
            SetCfg('crosshairResize', state)

            crosshairResize = state
        end,
    })
    crosshairSection:Slider({
        Title = 'Resize Speed',
        Value = {
            Min = 0,
            Max = 500,
            Default = C('crosshairResizeSpeed', 150),
        },
        Step = 1,
        Callback = function(value)
            SetCfg('crosshairResizeSpeed', value)

            crosshairResizeSpeed = value
        end,
    })
    crosshairSection:Slider({
        Title = 'Resize Min',
        Value = {
            Min = 1,
            Max = 50,
            Default = C('crosshairResizeMin', 5),
        },
        Step = 1,
        Callback = function(value)
            SetCfg('crosshairResizeMin', value)

            crosshairResizeMin = value
        end,
    })
    crosshairSection:Slider({
        Title = 'Resize Max',
        Value = {
            Min = 1,
            Max = 50,
            Default = C('crosshairResizeMax', 22),
        },
        Step = 1,
        Callback = function(value)
            SetCfg('crosshairResizeMax', value)

            crosshairResizeMax = value
        end,
    })
end

_initUtilities()

local function _initScreen()
    warn('screen tab loaded')

    local ScreenTab = Window:Tab({
        Title = 'Screen',
        Icon = 'maximize',
        ShowTabTitle = true,
        Border = true,
    })
    local screenIntensity = C('screenIntensity', 0)
    local screenConnection

    if C('screenEffectEnabled', false) then
        screenConnection = RunService.RenderStepped:Connect(function()
            camera.CFrame = camera.CFrame * CFrame.new(0, 0, 0, 1, 0, 0, 0, 0.65 + screenIntensity, 0, 0, 0, 1)
        end)
    end

    ScreenTab:Toggle({
        Title = 'Enable Screen Effect',
        Value = C('screenEffectEnabled', false),
        Callback = function(v)
            SetCfg('screenEffectEnabled', v)

            if v then
                screenConnection = RunService.RenderStepped:Connect(function()
                    camera.CFrame = camera.CFrame * CFrame.new(0, 0, 0, 1, 0, 0, 0, 0.65 + screenIntensity, 0, 0, 0, 1)
                end)
            else
                if screenConnection then
                    screenConnection:Disconnect()

                    screenConnection = nil
                end
            end
        end,
    })
    ScreenTab:Slider({
        Title = 'Screen Stretch',
        Value = {
            Min = 0,
            Max = 0.2,
            Default = C('screenIntensity', 0),
        },
        Step = 0.001,
        IsTextbox = true,
        Callback = function(v)
            SetCfg('screenIntensity', v)

            screenIntensity = v
        end,
    })

    local fovValue = C('fovValue', 70)
    local fovConnection

    local function updateFOV()
        if camera then
            camera.FieldOfView = fovValue
        end
    end

    if C('fovEnabled', false) then
        updateFOV()

        fovConnection = RunService.RenderStepped:Connect(function()
            updateFOV()
        end)
    end

    ScreenTab:Toggle({
        Title = 'Enable Custom FOV',
        Value = C('fovEnabled', false),
        Callback = function(state)
            SetCfg('fovEnabled', state)

            if state then
                updateFOV()

                if fovConnection then
                    fovConnection:Disconnect()
                end

                fovConnection = RunService.RenderStepped:Connect(function()
                    updateFOV()
                end)
            else
                if fovConnection then
                    fovConnection:Disconnect()

                    fovConnection = nil
                end
                if camera then
                    camera.FieldOfView = 70
                end
            end
        end,
    })
    ScreenTab:Slider({
        Title = 'Field of View',
        Value = {
            Min = 30,
            Max = 144,
            Default = C('fovValue', 70),
        },
        Step = 1,
        IsTextbox = true,
        Callback = function(value)
            SetCfg('fovValue', value)

            fovValue = value

            updateFOV()
        end,
    })
end

_initScreen()

local function _initWorld()
    warn('world tab loaded')

    local WorldTab = Window:Tab({
        Title = 'World',
        Icon = 'globe',
        ShowTabTitle = true,
        Border = true,
    })
    local wEnvironment = WorldTab:Section({
        Title = 'Environment',
        Opened = true,
    })
    local isFullbrightEnabled = C('isFullbrightEnabled', false)
    local isFogEnabled = true
    local savedFogEnd = Lighting.FogEnd

    if isFullbrightEnabled then
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
    end

    wEnvironment:Toggle({
        Title = 'Fullbright',
        Default = C('isFullbrightEnabled', false),
        Callback = function(state)
            SetCfg('isFullbrightEnabled', state)

            isFullbrightEnabled = state

            if state then
                Lighting.Brightness = 2
                Lighting.ClockTime = 14
                Lighting.FogEnd = 100000
                Lighting.GlobalShadows = false
                Lighting.Ambient = Color3.fromRGB(255, 255, 255)
            else
                Lighting.Brightness = 1
                Lighting.ClockTime = 12
                Lighting.GlobalShadows = true
                Lighting.Ambient = Color3.fromRGB(127, 127, 127)

                if isFogEnabled then
                    Lighting.FogEnd = savedFogEnd
                end
            end
        end,
    })
    wEnvironment:Colorpicker({
        Title = 'Ambient Color',
        Default = Lighting.Ambient,
        Callback = function(color)
            if not isFullbrightEnabled then
                Lighting.Ambient = color
                Lighting.OutdoorAmbient = color
            end
        end,
    })
    wEnvironment:Slider({
        Title = 'Time of Day',
        Value = {
            Min = 0,
            Max = 24,
            Default = Lighting.ClockTime,
        },
        Step = 0.1,
        Callback = function(v)
            if not isFullbrightEnabled then
                Lighting.ClockTime = v
            end
        end,
    })
    wEnvironment:Slider({
        Title = 'Exposure',
        Value = {
            Min = -2,
            Max = 5,
            Default = Lighting.ExposureCompensation,
        },
        Step = 0.1,
        Callback = function(v)
            Lighting.ExposureCompensation = v
        end,
    })

    local fogEnabled = C('fogEnabled', false)
    local fogRainbow = C('fogRainbow', false)
    local fogColor = C('fogColor', Color3.fromRGB(200, 200, 255))
    local fogStart = C('fogStart', 0)
    local fogEnd = C('fogEnd', 300)
    local fogConnection
    local fogSection = WorldTab:Section({
        Title = 'Fog',
        Desc = '',
        Icon = 'cloud',
        Opened = true,
        Box = true,
        BoxBorder = true,
    })

    local function applyFog()
        Lighting.FogColor = fogColor
        Lighting.FogStart = fogStart
        Lighting.FogEnd = fogEnd
    end
    local function smoothFog()
        if fogConnection then
            fogConnection:Disconnect()
        end

        fogConnection = RunService.RenderStepped:Connect(function()
            if fogEnabled then
                Lighting.FogEnd = Lighting.FogEnd + (fogEnd - Lighting.FogEnd) * 0.05
                Lighting.FogStart = Lighting.FogStart + (fogStart - Lighting.FogStart) * 0.05

                if fogRainbow then
                    local rainbow = Color3.fromHSV((tick() % 5) / 5, 1, 1)

                    Lighting.FogColor = Lighting.FogColor:Lerp(rainbow, 0.08)
                else
                    Lighting.FogColor = Lighting.FogColor:Lerp(fogColor, 0.05)
                end
            end
        end)
    end

    if fogEnabled then
        applyFog()
        smoothFog()
    end

    fogSection:Toggle({
        Title = 'Enable Beautiful Fog',
        Value = C('fogEnabled', false),
        Callback = function(state)
            SetCfg('fogEnabled', state)

            fogEnabled = state

            if state then
                applyFog()
                smoothFog()
            else
                if fogConnection then
                    fogConnection:Disconnect()

                    fogConnection = nil
                end

                Lighting.FogEnd = 100000
                Lighting.FogStart = 0
            end
        end,
    })
    fogSection:Toggle({
        Title = 'Rainbow Fog',
        Value = C('fogRainbow', false),
        Callback = function(state)
            SetCfg('fogRainbow', state)

            fogRainbow = state
        end,
    })
    fogSection:Slider({
        Title = 'Fog Distance',
        Value = {
            Min = 50,
            Max = 2000,
            Default = C('fogEnd', 300),
        },
        Step = 10,
        Callback = function(value)
            SetCfg('fogEnd', value)

            fogEnd = value
        end,
    })
    fogSection:Slider({
        Title = 'Fog Start',
        Value = {
            Min = 0,
            Max = 500,
            Default = C('fogStart', 0),
        },
        Step = 5,
        Callback = function(value)
            SetCfg('fogStart', value)

            fogStart = value
        end,
    })
    fogSection:Colorpicker({
        Title = 'Fog Color',
        Default = C('fogColor', Color3.fromRGB(200, 200, 255)),
        Callback = function(color)
            SetCfg('fogColor', color)

            fogColor = color
        end,
    })
end

_initWorld()

local function _initSkybox()
    warn('skybox custom tab loaded')

    local function applyNewSkybox(assetId)
        for _, obj in pairs(Lighting:GetChildren())do
            if obj:IsA('Sky') then
                obj:Destroy()
            end
        end

        local success, assets = pcall(function()
            return game:GetObjects('rbxassetid://' .. tostring(assetId))[1]
        end)

        if success and assets and assets:IsA('Sky') then
            assets.Parent = Lighting
        else
            local newSky = Instance.new('Sky')
            local id = 'rbxassetid://' .. tostring(assetId)

            newSky.SkyboxBk = id
            newSky.SkyboxDn = id
            newSky.SkyboxFt = id
            newSky.SkyboxLf = id
            newSky.SkyboxRt = id
            newSky.SkyboxUp = id
            newSky.Parent = Lighting
        end
    end

    local lastSkybox = C('lastSkybox', nil)

    if lastSkybox then
        pcall(function()
            applyNewSkybox(lastSkybox)
        end)
    end

    local SkyboxCustomTab = Window:Tab({
        Title = 'Skybox Custom',
        Icon = 'camera',
        ShowTabTitle = true,
        Border = true,
    })

    local function createSkyboxButton(title, assetId)
        SkyboxCustomTab:Button({
            Title = title,
            Desc = '',
            Icon = 'camera',
            Callback = function()
                SetCfg('lastSkybox', assetId)
                applyNewSkybox(assetId)
            end,
        })
    end

    local skyboxList = {
        {
            'Orange Skybox',
            '627302570',
        },
        {
            'FPS+ Skybox',
            '582303304',
        },
        {
            'Space Skybox',
            '15619750970',
        },
        {
            'Green Skybox',
            '348361280',
        },
        {
            'Blue Skybox',
            '130093177270069',
        },
        {
            'Purple Skybox',
            '83555979203508',
        },
        {
            'Red Skybox',
            '401666131',
        },
        {
            'HD Skybox',
            '16823410580',
        },
        {
            'Night Skybox',
            '12064636',
        },
        {
            'Galactic Skybox',
            '10542194896',
        },
        {
            'Winter Skybox',
            '96628448286151',
        },
        {
            'Saturn Skybox',
            '1898754079',
        },
        {
            'Outrun Skybox',
            '3441770362',
        },
        {
            'Cyan Space Skybox',
            '367149630',
        },
        {
            'City Skybox',
            '117205995214134',
        },
        {
            'Green skybox 2.0',
            '16823294549',
        },
        {
            'Obama Skybox(joke)',
            '2362934358',
        },
        {
            'SpongeBob Skybox',
            '114523453023009',
        },
        {
            'Purple Nebula Skybox',
            '230057997',
        },
        {
            'Bart Skybox',
            '119891349513795',
        },
        {
            'Sunless Blue Sky',
            '591067775',
        },
        {
            'Weirdcore Eye Skybox',
            '11372740893',
        },
        {
            'Minecraft Skybox',
            '5087871978',
        },
        {
            'Frutiger Aero Skybox',
            '97046110924083',
        },
        {
            'Cyberpunk Skybox',
            '13689001090',
        },
        {
            'Dark Red Castle Skybox',
            '15832476802',
        },
        {
            'Cartoon Skybox',
            '107689530722429',
        },
        {
            'Skybox HD',
            '16563510624',
        },
        {
            'Error Skybox',
            '13710730784',
        },
        {
            'Abyssal Blues Skybox',
            '16269853692',
        },
        {
            'Earth Skybox',
            '266878339',
        },
        {
            'Black & White Fade Skybox',
            '6213224205',
        },
        {
            'Purple Skybox 2',
            '8107887936',
        },
        {
            'Green Nebula Space',
            '89018019804256',
        },
        {
            'HD Rainbow Skybox',
            '18915196644',
        },
        {
            'Meadow Skybox',
            '848241313',
        },
        {
            'Pink Sky Skybox',
            '107689530722174',
        },
        {
            'Venus Skybox V2',
            '110450592899174',
        },
    }

    for _, data in ipairs(skyboxList)do
        createSkyboxButton(data[1], data[2])
    end

end

_initSkybox()


local miscSection = getRawSection('Miscellaneous')
miscSection:AddButton('Reset Configuration', function()
    ConfigData = {}
    if isfile(CFG_FILE) then
        pcall(function()
            delfile(CFG_FILE)
        end)
    end
    EnsureFolders()
    SaveConfig()
    shared.Notify('Configuration reset. Re-run the add-on to fully apply defaults.', 4)
end)

shared.Notify('ludexioso_visuals loaded', 3)
