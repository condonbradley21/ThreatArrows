-- WoW Forever 16001. Display only; no targeting, casting or input.
local driver = CreateFrame("Frame")
local active, elapsed, enabled = {}, 0, true
local defaults = {size=64, offset=20, opacity=65}
local styles={"Forged","Arcane","Sentinel","Wisp"}
local styleCoords={Forged={0,0.5,0,0.5},Arcane={0.5,1,0,0.5},Sentinel={0,0.5,0.5,1},Wisp={0.5,1,0.5,1}}
local defaultColors={secure={0.1,1,0.08},losing={1,0.5,0.06},lost={1,0.08,0.08},unknown={0.55,0.6,0.68}}
local function restricted(value)
    return issecretvalue and issecretvalue(value)
end
local function read(fn, ...)
    if type(fn) ~= "function" then error("Required API unavailable") end
    local value = fn(...)
    if restricted(value) then error("Threat information restricted") end
    return value
end
local function settings()
    if type(ThreatArrowsDB) ~= "table" then ThreatArrowsDB = {} end
    for key, value in pairs(defaults) do
        local n = tonumber(ThreatArrowsDB[key])
        local lo, hi = key == "size" and 24 or (key == "opacity" and 10 or 0), key == "size" and 160 or (key == "opacity" and 100 or 150)
        ThreatArrowsDB[key] = n and math.max(lo, math.min(hi, n)) or value
    end
    local db=ThreatArrowsDB
    local distance=tonumber(db.maxTauntDistance)
    db.maxTauntDistance=distance and distance==distance and math.floor(math.max(1,math.min(40,distance))+0.5) or 10
    if not styleCoords[db.arrowStyle] then db.arrowStyle="Sentinel" end
    if type(db.colors)~="table" then db.colors={} end
    for key,color in pairs(defaultColors) do
        if type(db.colors[key])~="table" then db.colors[key]={} end
        for i=1,3 do
            local n=tonumber(db.colors[key][i])
            db.colors[key][i]=n and n==n and math.max(0,math.min(1,n)) or color[i]
        end
    end
    return db
end
local function palette(key)
    local db=settings()
    return unpack(db.customColors and db.colors[key] or defaultColors[key])
end
local function applyStyle(arrow)
    local style=settings().arrowStyle
    if arrow.style==style then return end
    arrow.style=style
    arrow.art:SetTexCoord(unpack(styleCoords[style]))
end
local function panelSettings()
    local db=settings()
    local bounds={panelWidth={180,700,330},panelHeight={60,700,294},panelOpacity={0,100,35}}
    for key,b in pairs(bounds) do
        local n=tonumber(db[key]);db[key]=n and math.max(b[1],math.min(b[2],n)) or b[3]
    end
    return db
end
local function makeArrow(plate)
    local arrow = CreateFrame("Frame", nil, plate)
    arrow:EnableMouse(false)
    arrow:SetAlpha(settings().opacity/100)
    arrow:SetFrameLevel(plate:GetFrameLevel()+20)
    arrow.parts = {}
    -- One antialiased texture replaces dozens of one-pixel strips.
    arrow.art=arrow:CreateTexture(nil,"ARTWORK")
    arrow.art:SetTexture("Interface\\AddOns\\ThreatArrows\\Media\\ArrowStyles.tga")
    arrow.art:SetAllPoints()
    arrow.parts={{texture=arrow.art,shade=1}}
    applyStyle(arrow)
    arrow:SetSize(64,64)
    arrow.warningText = arrow:CreateFontString(nil,"OVERLAY")
    arrow.warningText:SetFont("Fonts\\FRIZQT__.TTF",10,"OUTLINE")
    arrow.warningText:SetPoint("TOP",arrow,"BOTTOM",0,-2)
    arrow.warningText:SetText("")
    return arrow
end
local function applyLayout(arrow, bounce)
    local db = settings()
    arrow:SetAlpha(db.opacity/100)
    applyStyle(arrow)
    arrow:SetSize(64,64)
    arrow:SetScale(db.size/64)
    arrow:ClearAllPoints()
    arrow:SetPoint("BOTTOM", arrow:GetParent(), "TOP", 0, (db.offset+(bounce or 0))/(db.size/64))
end
local function selected(unit)
    local ok, value = pcall(read, UnitIsUnit, unit, "target")
    return ok and value == true
end
local function percentage(unit, status)
    if status==2 or status==3 then return {value=100, source="confirmed tank state"} end
    if type(UnitDetailedThreatSituation) ~= "function" then return end
    -- Details Tiny Threat queries target/focus. Prefer target for the selected plate.
    local tokens = selected(unit) and {"target",unit} or {unit}
    for _,token in ipairs(tokens) do
        local ok, tanking, _, scaled, raw = pcall(UnitDetailedThreatSituation, "player", token)
        if ok then
            -- Match Tiny Threat's main-tank guard; raw tank percentages are invalid.
            if not restricted(tanking) and tanking == true then return {value=100, source="tank (Tiny Threat convention)"} end
            if restricted(raw) then return {value=raw, secret=true, source="raw (UI formatted)"} end
            if type(raw)=="number" and raw==raw then return {value=math.max(0,raw), source="raw"} end
            if restricted(scaled) then return {value=scaled, secret=true, source="scaled (UI formatted)"} end
            if type(scaled)=="number" and scaled==scaled then return {value=math.max(0,scaled), source="scaled"} end
        end
    end
    -- A public tanking status is sufficient for the same 100% convention.
    if status==2 or status==3 then return {value=100, source="tank (Tiny Threat convention)"} end
end
local function tauntRange(unit)
    local maximum=settings().maxTauntDistance
    if type(UnitDistanceSquared)=="function" then
        local ok,distance,valid=pcall(UnitDistanceSquared,unit)
        if ok and not restricted(distance) and not restricted(valid) and valid==true
            and type(distance)=="number" and distance==distance and distance>=0 and distance<math.huge then
            return distance<=maximum*maximum
        end
    end
    -- Spell checks only prove a threshold when their reported range supports it.
    -- An unavailable/restricted distance must never become a guessed warning.
    local fn=C_Spell and C_Spell.IsSpellInRange or IsSpellInRange
    if type(fn)~="function" then return end
    for _,spell in ipairs({"Judgement",20271}) do
        local infoOK,minimum,range=pcall(function()
            if C_Spell and C_Spell.GetSpellInfo then
                local info=C_Spell.GetSpellInfo(spell)
                if restricted(info) or type(info)~="table" then return end
                return info.minRange,info.maxRange
            elseif type(GetSpellInfo)=="function" then
                local _,_,_,_,lo,hi=GetSpellInfo(spell)
                return lo,hi
            end
        end)
        if infoOK and not restricted(minimum) and not restricted(range)
            and type(range)=="number" and range>0 and minimum==0 then
            local ok,result=pcall(fn,spell,unit)
            if ok and not restricted(result) then
                if (result==true or result==1) and range<=maximum then return true end
                if (result==false or result==0) and range>=maximum then return false end
            end
        end
    end
end
-- Matches Details' 8-bit percentage ramp, oriented green at full threat.
local function threatRamp(pct)
    local v=math.max(0,math.min(100,pct))
    local r=v<50 and 255 or math.floor(255-(v*2-100)*255/100)
    local g=v>50 and 255 or math.floor(v*2*255/100)
    return r/255,g/255,0
end
local function mobThreatColor(unit,pct,fallback)
    if settings().customColors then return unpack(fallback) end
    local ok,status=pcall(read,UnitThreatSituation,"player",unit)
    if ok and (status==2 or status==3) and type(UnitDetailedThreatSituation)=="function" then
        local highest,seen=0,false
        local raid=type(IsInRaid)=="function" and IsInRaid()
        local count=raid and 40 or 4
        for i=1,count do
            for _,member in ipairs({(raid and "raid" or "party")..i,(raid and "raidpet" or "partypet")..i}) do
                local existsOK,exists=pcall(read,UnitExists,member)
                local selfOK,isSelf=pcall(read,UnitIsUnit,member,"player")
                if existsOK and exists and (not selfOK or not isSelf) then
                    local good,tanking,_,scaled,raw=pcall(UnitDetailedThreatSituation,member,unit)
                    if good and not restricted(tanking) and tanking~=true then
                        local value=raw
                        if restricted(value) or type(value)~="number" then value=scaled end
                        if not restricted(value) and type(value)=="number" then highest=math.max(highest,value);seen=true end
                    end
                end
            end
        end
        if seen then return math.min(1,highest/100),math.min(1,math.abs(highest-100)/100),0 end
    end
    if pct and not pct.secret then return threatRamp(pct.value) end
    return unpack(fallback)
end
local function stateColor(status)
    if settings().customColors then
        return palette(status==3 and "secure" or (status==2 and "losing" or (status~=nil and "lost" or "unknown")))
    end
    if status==3 then return 0.1,1,0.08 end
    if status==2 then return 1,0.5,0.06 end
    if status~=nil then return 1,0.08,0.08 end
    return 0.55,0.6,0.68
end
local function classify(unit)
    if not read(UnitExists, unit) or not read(UnitCanAttack, "player", unit)
        or read(UnitIsPlayer, unit) or read(UnitIsDeadOrGhost, unit) then return end
    local ok, status = pcall(read, UnitThreatSituation, "player", unit)
    if not read(UnitAffectingCombat, unit) then
        if selected(unit) then return palette("unknown") end
        return
    end
    if not ok then status=nil end
    local pct = percentage(unit,status)
    if pct and not pct.secret and not settings().customColors then
        local t = math.min(100,pct.value)/100
        return math.min(1,2*(1-t)), math.min(1,2*t), 0.06, pct
    end
    -- Restricted numbers go directly to the UI, never through addon arithmetic.
    -- State colors remain available even when percentage math is restricted.
    if status==nil then
        local known,mobStatus=pcall(read,UnitThreatSituation,unit)
        if known and mobStatus~=nil then status=0 end
    end
    local r,g,b=stateColor(status)
    return r,g,b,pct
end
local function formatPercent(text,pct)
    local displayed=false
    if pct then displayed=pcall(text.SetFormattedText,text,"%.0f%%",pct.value) end
    if not displayed then text:SetText("?") end
end
local function warningAlpha(arrow)
    return arrow.warning and (0.65+0.35*math.cos((arrow.warningPhase or 0)*math.pi*2/0.8)) or 1
end
local function update(unit, arrow)
    local previousWarning=arrow.warning
    arrow.engaged=false; arrow.warning=nil
    if not enabled then arrow:Hide(); arrow.targeted=false; return end
    local ok, r,g,b,pct = pcall(classify, unit)
    if not ok or not r then arrow:Hide(); arrow.targeted=false; return end
    applyStyle(arrow)
    for _,part in ipairs(arrow.parts) do
        part.texture:SetVertexColor(r*part.shade,g*part.shade,b*part.shade,1)
    end
    arrow.percentageSource=pct and pct.source or "unavailable"
    arrow.pct=pct; arrow.tint={r,g,b}
    local combatOK,combat=pcall(read,UnitAffectingCombat,unit)
    arrow.engaged=combatOK and combat==true
    local stateOK,state=pcall(read,UnitThreatSituation,"player",unit)
    if arrow.engaged and stateOK then
        if state==2 then arrow.warning="LOSING"
        elseif state==0 or state==1 then arrow.warning="LOST"
        elseif state==nil then
            local known,mobState=pcall(read,UnitThreatSituation,unit)
            if known and mobState~=nil then arrow.warning="LOST" end
        end
    end
    if arrow.warning then
        local wr,wg,wb=palette(arrow.warning=="LOSING" and "losing" or "lost")
        arrow.warningText:SetText(arrow.warning)
        arrow.warningText:SetTextColor(wr,wg,wb,1)
    else arrow.warningText:SetText("") end
    if arrow.warning~=previousWarning then arrow.warningPhase=0 end
    arrow.art:SetAlpha(warningAlpha(arrow))
    local target = selected(unit)
    if target~=arrow.targeted then arrow.phase=0 end
    arrow.targeted=target
    if not target then applyLayout(arrow) end
    if settings().arrowsHidden then arrow:Hide() else arrow:Show() end
end
local function remove(unit)
    local arrow = active[unit]
    if arrow then arrow:Hide(); arrow.targeted=false; arrow.phase=0; active[unit] = nil end
end
local function add(unit)
    remove(unit)
    if not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then return end
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate or (plate.IsForbidden and plate:IsForbidden()) then return end
    local arrow = plate.ThreatArrowsOverlay
    if not arrow then arrow = makeArrow(plate); plate.ThreatArrowsOverlay = arrow end
    active[unit] = arrow
    applyLayout(arrow)
    update(unit, arrow)
end
-- Display-only threat roster. Rows deliberately have no click/target handlers.
local panel=CreateFrame("Frame","ThreatArrowsThreatPanel",UIParent)
panel:SetSize(330,294)
panel:SetResizable(true)
panel:SetResizeBounds(180,60,700,700)
panel:SetFrameStrata("MEDIUM")
panel:SetMovable(true); panel:SetClampedToScreen(true)
panel:EnableMouse(true); panel:RegisterForDrag("LeftButton")
panel:EnableMouseWheel(true)
local panelHovered=false
local panelBG=panel:CreateTexture(nil,"BACKGROUND")
panelBG:SetAllPoints(); panelBG:SetColorTexture(0.025,0.035,0.05,0)
local titleBar=panel:CreateTexture(nil,"BORDER")
titleBar:SetColorTexture(0.015,0.015,0.045,0.95)
titleBar:SetPoint("TOPLEFT",panel,"TOPLEFT",0,0)
titleBar:SetPoint("TOPRIGHT",panel,"TOPRIGHT",0,0);titleBar:SetHeight(18)
local titleIcon=panel:CreateTexture(nil,"ARTWORK")
titleIcon:SetTexture("Interface\\Icons\\INV_Shield_06")
titleIcon:SetSize(16,16);titleIcon:SetPoint("TOPLEFT",panel,"TOPLEFT",2,-1)
local heading=panel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
heading:SetFont("Fonts\\ARIALN.TTF",10,"OUTLINE")
heading:SetTextColor(1,1,1,1)
heading:SetPoint("TOPLEFT",21,-4);heading:SetText("Threat Watch")
local footer=panel:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
footer:SetPoint("BOTTOMLEFT",8,6)
footer:SetFont("Fonts\\ARIALN.TTF",9,"OUTLINE")
footer:SetTextColor(0.65,0.65,0.65,1)
local lockButton=CreateFrame("Button","ThreatArrowsPanelLock",panel)
lockButton:SetSize(16,16);lockButton:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-3,-1)
lockButton:SetScale(0.8)
-- Draw a padlock with built-in textures so it works without external artwork.
local lockParts={}
local function lockRect(x,y,w,h)
    local t=lockButton:CreateTexture(nil,"ARTWORK")
    t:SetTexture("Interface\\Buttons\\WHITE8X8")
    t:SetPoint("TOPLEFT",lockButton,"TOPLEFT",x,-y);t:SetSize(w,h)
    t:SetVertexColor(0.7,0.7,0.7,1)
    lockParts[#lockParts+1]=t
    return t
end
lockRect(5,9,11,9)
lockRect(7,4,2,6)
lockRect(7,3,7,2)
local shackleRight=lockRect(12,4,2,6)
local keyhole=lockRect(10,12,2,4);keyhole:SetVertexColor(0.1,0.08,0.04,1)
lockButton:SetScript("OnEnter",function(self)
    if GameTooltip then
        GameTooltip:SetOwner(self,"ANCHOR_TOP")
        GameTooltip:SetText(settings().panelLocked and "Unlock Threat Watch" or "Lock Threat Watch")
        GameTooltip:Show()
    end
end)
lockButton:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
local arrowToggle=CreateFrame("Button","ThreatArrowsArrowToggle",panel)
arrowToggle:SetSize(18,18);arrowToggle:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-25,0)
local arrowToggleParts={}
local function toggleStrip(x,y,w,h)
    local t=arrowToggle:CreateTexture(nil,"ARTWORK")
    t:SetColorTexture(0.2,1,0.25,1)
    t:SetPoint("TOPLEFT",arrowToggle,"TOPLEFT",x,-y);t:SetSize(w,h)
    arrowToggleParts[#arrowToggleParts+1]=t
end
toggleStrip(7,3,3,6)
for i=0,4 do toggleStrip(4+i,9+i,9-i*2,1) end
arrowToggle:SetScript("OnEnter",function(self)
    if GameTooltip then
        GameTooltip:SetOwner(self,"ANCHOR_TOP")
        GameTooltip:SetText(settings().arrowsHidden and "Show overhead arrows" or "Hide overhead arrows")
        GameTooltip:Show()
    end
end)
arrowToggle:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
local grip=CreateFrame("Button","ThreatArrowsPanelResize",panel)
grip:SetSize(14,14);grip:SetPoint("BOTTOMRIGHT",panel,"BOTTOMRIGHT",0,0)
local function styleGrip(button,mirror)
    button:SetSize(16,16)
    local t=button:CreateTexture(nil,"ARTWORK")
    t:SetAllPoints();t:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    t:SetVertexColor(0.7,0.7,0.7,0.85)
    if mirror then t:SetTexCoord(1,0,0,1) end
end
styleGrip(grip,false)
local leftGrip=CreateFrame("Button","ThreatArrowsPanelResizeLeft",panel)
leftGrip:SetPoint("BOTTOMLEFT",panel,"BOTTOMLEFT",0,0);styleGrip(leftGrip,true)
local bottomLock=CreateFrame("Button","ThreatArrowsPanelBottomLock",panel)
bottomLock:SetSize(36,16);bottomLock:SetPoint("BOTTOMRIGHT",panel,"BOTTOMRIGHT",-19,0)
local bottomLockText=bottomLock:CreateFontString(nil,"OVERLAY")
bottomLockText:SetFont("Fonts\\ARIALN.TTF",10,"")
bottomLockText:SetTextColor(0.65,0.65,0.65,0.9);bottomLockText:SetAllPoints()
-- Opacity belongs in Options > AddOns, not the combat meter header.
local options=CreateFrame("Frame","ThreatArrowsOptionsPanel",UIParent)
options.name="Threat Arrows"
options:Hide()
local optionsTitle=options:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
optionsTitle:SetPoint("TOPLEFT",16,-16);optionsTitle:SetText("Threat Arrows")
local optionsHelp=options:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
optionsHelp:SetPoint("TOPLEFT",16,-49);optionsHelp:SetText("Threat Watch appearance. Changes apply immediately and are saved.")
local opacityText=options:CreateFontString(nil,"OVERLAY","GameFontNormal")
opacityText:SetPoint("TOPLEFT",16,-88)
local opacitySlider=CreateFrame("Slider","ThreatArrowsPanelOpacity",options,"OptionsSliderTemplate")
opacitySlider:SetPoint("TOPLEFT",options,"TOPLEFT",20,-119)
opacitySlider:SetSize(240,16);opacitySlider:SetMinMaxValues(0,100);opacitySlider:SetValueStep(5)
opacitySlider:SetObeyStepOnDrag(true)
local optionsHint=options:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
optionsHint:SetPoint("TOPLEFT",16,-170)
optionsHint:SetText("Lower opacity makes the background more transparent. Text stays readable.\nMove and resize the meter while unlocked; use its Lock button to keep it in place.")
local settingsCategory
local function registerOptions()
    if settingsCategory then return end
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        settingsCategory=Settings.RegisterCanvasLayoutCategory(options,"Threat Arrows")
        Settings.RegisterAddOnCategory(settingsCategory)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(options);settingsCategory=options
    end
end
local function openOptions()
    registerOptions()
    if Settings and Settings.OpenToCategory and settingsCategory and settingsCategory.GetID then
        Settings.OpenToCategory(settingsCategory:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then InterfaceOptionsFrame_OpenToCategory(options)
    else print("Open Options > AddOns > Threat Arrows.") end
end
local minimapButton
local function positionMinimapButton()
    if not minimapButton then return end
    local db=settings()
    local angle=tonumber(db.minimapAngle)
    if not angle or angle~=angle then angle=225 end
    db.minimapAngle=angle%360
    local radians=db.minimapAngle*math.pi/180
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER",Minimap,"CENTER",math.cos(radians)*(Minimap:GetWidth()/2+8),math.sin(radians)*(Minimap:GetHeight()/2+8))
end
if Minimap then
    minimapButton=CreateFrame("Button","ThreatArrowsMinimapButton",Minimap)
    minimapButton:SetSize(32,32);minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetFrameLevel(Minimap:GetFrameLevel()+10)
    minimapButton:RegisterForClicks("LeftButtonUp","RightButtonUp")
    minimapButton:RegisterForDrag("LeftButton")
    minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local icon=minimapButton:CreateTexture(nil,"ARTWORK")
    icon:SetTexture("Interface\\Icons\\INV_Shield_06")
    icon:SetSize(20,20);icon:SetPoint("CENTER",minimapButton,"CENTER",0,0)
    local border=minimapButton:CreateTexture(nil,"OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54,54);border:SetPoint("TOPLEFT",minimapButton,"TOPLEFT",0,0)
    minimapButton:SetScript("OnClick",function(_,button)
        if button=="RightButton" then
            local db=settings();db.panelHidden=not db.panelHidden
            -- The existing toggle handles the render on the next display tick.
        else openOptions() end
    end)
    minimapButton:SetScript("OnEnter",function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self,"ANCHOR_LEFT");GameTooltip:SetText("Threat Arrows")
        GameTooltip:AddLine("Left-click: appearance settings",1,1,1)
        GameTooltip:AddLine("Right-click: show/hide Threat Watch",1,1,1)
        GameTooltip:AddLine("Drag: move around minimap",0.8,0.8,0.8)
        GameTooltip:Show()
    end)
    minimapButton:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
    minimapButton:SetScript("OnDragStart",function(self)
        if GameTooltip then GameTooltip:Hide() end
        self:SetScript("OnUpdate",function()
            local x,y=GetCursorPosition()
            local cx,cy=Minimap:GetCenter();local scale=Minimap:GetEffectiveScale()
            if not cx or not cy or not scale or scale<=0 then return end
            settings().minimapAngle=math.atan2(y/scale-cy,x/scale-cx)*180/math.pi
            positionMinimapButton()
        end)
    end)
    minimapButton:SetScript("OnDragStop",function(self) self:SetScript("OnUpdate",nil) end)
    minimapButton:SetPoint("TOPRIGHT",Minimap,"TOPRIGHT",0,0)
    minimapButton:Show()
end
local rows,scroll={},0
local targetRowPhase=0
local resizing=false
local positionLoaded=false
local function positionPanel()
    if positionLoaded then return end
    panel:ClearAllPoints()
    local db=panelSettings();panel:SetSize(db.panelWidth,db.panelHeight); local saved=db.panelPosition
    if type(saved)=="table" and type(saved.x)=="number" and type(saved.y)=="number" then
        panel:SetPoint("CENTER",UIParent,"CENTER",saved.x,saved.y)
    else panel:SetPoint("CENTER",UIParent,"CENTER",300,-100) end
    positionLoaded=true
end
local function savePanelPosition()
    local x,y=panel:GetCenter(); local ux,uy=UIParent:GetCenter()
    if x and y and ux and uy then settings().panelPosition={x=x-ux,y=y-uy} end
end
panel:SetScript("OnDragStart",function() if not settings().panelLocked then panel:StartMoving() end end)
panel:SetScript("OnDragStop",function() panel:StopMovingOrSizing();savePanelPosition() end)
grip:SetScript("OnMouseDown",function(_,button)
    if button=="LeftButton" and not settings().panelLocked then resizing=true;panel:StartSizing("BOTTOMRIGHT") end
end)
grip:SetScript("OnMouseUp",function()
    if not resizing then return end
    resizing=false;panel:StopMovingOrSizing()
    local db=panelSettings();db.panelWidth=panel:GetWidth();db.panelHeight=panel:GetHeight()
    savePanelPosition()
end)
leftGrip:SetScript("OnMouseDown",function(_,button)
    if button=="LeftButton" and not settings().panelLocked then resizing=true;panel:StartSizing("BOTTOMLEFT") end
end)
leftGrip:SetScript("OnMouseUp",grip:GetScript("OnMouseUp"))
local function makeRow(index)
    local row=CreateFrame("StatusBar",nil,panel)
    row:SetSize(310,16); row:SetPoint("TOPLEFT",panel,"TOPLEFT",0,-19-(index-1)*17)
    row:SetMinMaxValues(0,100)
    row:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    row:SetOrientation("HORIZONTAL")
    row.bg=row:CreateTexture(nil,"BACKGROUND");row.bg:SetAllPoints()
    row.stripe=row:CreateTexture(nil,"ARTWORK");row.stripe:SetSize(2,16);row.stripe:SetPoint("LEFT",row,"LEFT",0,0)
    row.selectionBorder={}
    for _,edge in ipairs({"TOP","BOTTOM","LEFT","RIGHT"}) do
        local t=row:CreateTexture(nil,"OVERLAY")
        t:SetColorTexture(0.82,0.96,1,0.95)
        if edge=="TOP" or edge=="BOTTOM" then
            t:SetHeight(1);t:SetPoint(edge.."LEFT",row,edge.."LEFT",0,0);t:SetPoint(edge.."RIGHT",row,edge.."RIGHT",0,0)
        else
            t:SetWidth(1);t:SetPoint("TOP"..edge,row,"TOP"..edge,0,0);t:SetPoint("BOTTOM"..edge,row,"BOTTOM"..edge,0,0)
        end
        t:Hide();row.selectionBorder[#row.selectionBorder+1]=t
    end
    row.chevrons={}
    local function selectionStrip(side,x,y,w,h,r,g,b)
        local t=row:CreateTexture(nil,"OVERLAY")
        t:SetColorTexture(r,g,b,1)
        t:SetSize(w,h)
        t:SetPoint(side==1 and "LEFT" or "RIGHT",row,side==1 and "LEFT" or "RIGHT",side*x,y)
        t:Hide();row.chevrons[#row.chevrons+1]=t
    end
    for _,side in ipairs({1,-1}) do
        -- Solid inward arrow: outlined shaft and broad tapered head.
        selectionStrip(side,2,0,6,6,0.02,0.04,0.06)
        selectionStrip(side,3,0,5,4,0.55,0.9,1)
        for step=0,5 do
            local height=12-step*2
            selectionStrip(side,7+step,0,1,height,0.02,0.04,0.06)
            if height>2 then selectionStrip(side,7+step,0,1,height-2,0.65-step*0.04,0.94-step*0.03,1-step*0.02) end
        end
    end
    row.health=CreateFrame("StatusBar",nil,row)
    row.health:SetSize(36,7);row.health:SetPoint("RIGHT",row,"RIGHT",-66,0)
    row.health:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    row.health:SetMinMaxValues(0,100);row.health:SetValue(0)
    local healthBG=row.health:CreateTexture(nil,"BACKGROUND")
    healthBG:SetAllPoints();healthBG:SetColorTexture(0.025,0.035,0.05,0.8)
    local crossBG=row:CreateTexture(nil,"ARTWORK")
    crossBG:SetColorTexture(0.025,0.03,0.025,0.9)
    crossBG:SetSize(10,10);crossBG:SetPoint("RIGHT",row.health,"LEFT",-2,0)
    row.healthCross={}
    for _,shape in ipairs({{2,6},{6,2}}) do
        local t=row:CreateTexture(nil,"OVERLAY")
        t:SetColorTexture(0.85,0.75,0.48,1);t:SetSize(shape[1],shape[2])
        t:SetPoint("CENTER",crossBG,"CENTER",0,0);row.healthCross[#row.healthCross+1]=t
    end
    row.healthBorder={}
    for _,edge in ipairs({"TOP","BOTTOM","LEFT","RIGHT"}) do
        local t=row.health:CreateTexture(nil,"OVERLAY")
        t:SetColorTexture(0.45,0.4,0.29,1)
        if edge=="TOP" or edge=="BOTTOM" then
            t:SetHeight(1);t:SetPoint(edge.."LEFT",row.health,edge.."LEFT",-1,edge=="TOP" and 1 or -1)
            t:SetPoint(edge.."RIGHT",row.health,edge.."RIGHT",1,edge=="TOP" and 1 or -1)
        else
            t:SetWidth(1);t:SetPoint("TOP"..edge,row.health,"TOP"..edge,edge=="LEFT" and -1 or 1,1)
            t:SetPoint("BOTTOM"..edge,row.health,"BOTTOM"..edge,edge=="LEFT" and -1 or 1,-1)
        end
        row.healthBorder[#row.healthBorder+1]=t
    end
    local sheen=row.health:CreateTexture(nil,"OVERLAY")
    sheen:SetColorTexture(1,1,1,0.16);sheen:SetHeight(2)
    sheen:SetPoint("TOPLEFT",row.health,"TOPLEFT",0,0);sheen:SetPoint("TOPRIGHT",row.health,"TOPRIGHT",0,0)
    row.healthIconBG=crossBG
    row.rangeMark=row:CreateFontString(nil,"OVERLAY")
    row.rangeMark:SetFont("Fonts\\ARIALN.TTF",8,"OUTLINE")
    row.rangeMark:SetPoint("LEFT",row,"LEFT",15,0)
    row.rangeMark:SetText("T")
    row.name=row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    row.name:SetPoint("LEFT",row,"LEFT",24,0);row.name:SetWidth(174);row.name:SetJustifyH("LEFT")
    row.state=row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    row.state:SetPoint("RIGHT",row,"RIGHT",-115,0)
    row.percent=row:CreateFontString(nil,"OVERLAY","GameFontNormal")
    row.percent:SetPoint("RIGHT",row,"RIGHT",-15,0)
    row.name:SetFont("Fonts\\FRIZQT__.TTF",10,"OUTLINE")
    row.name:SetShadowColor(0,0,0,1);row.name:SetShadowOffset(1,-1)
    row.state:SetFont("Fonts\\FRIZQT__.TTF",9,"OUTLINE")
    row.state:SetShadowColor(0,0,0,1);row.state:SetShadowOffset(1,-1)
    row.percent:SetFont("Fonts\\FRIZQT__.TTF",10,"OUTLINE")
    row.percent:SetShadowColor(0,0,0,1);row.percent:SetShadowOffset(1,-1)
    row.percent:SetTextColor(1,0.87,0.5,1)
    return row
end
local function renderPanel()
    positionPanel()
    if not enabled or settings().panelHidden then panel:Hide();return end
    local db=panelSettings()
    panelBG:SetColorTexture(0.025,0.035,0.05,panelHovered and db.panelOpacity/100 or 0)
    for _,part in ipairs(arrowToggleParts) do
        if db.arrowsHidden then part:SetColorTexture(0.4,0.4,0.4,0.65)
        else part:SetColorTexture(0.2,1,0.25,1) end
    end
    shackleRight:ClearAllPoints()
    shackleRight:SetPoint("TOPLEFT",lockButton,"TOPLEFT",12,db.panelLocked and -4 or 0)
    for _,part in ipairs(lockParts) do part:SetAlpha(db.panelLocked and 1 or 0.75) end
    if db.panelLocked or not panelHovered then grip:Hide();leftGrip:Hide() else grip:Show();leftGrip:Show() end
    bottomLockText:SetText(db.panelLocked and "unlock" or "lock")
    if panelHovered then bottomLock:Show() else bottomLock:Hide() end
    opacityText:SetText("Threat Watch background opacity: "..math.floor(db.panelOpacity).."%")
    if opacitySlider:GetValue()~=db.panelOpacity then opacitySlider:SetValue(db.panelOpacity) end
    local capacity=math.max(1,math.floor((panel:GetHeight()-39)/17))
    local entries={}
    for unit,arrow in pairs(active) do
        if arrow.engaged then entries[#entries+1]={unit=unit,arrow=arrow} end
    end
    table.sort(entries,function(a,b)
        return (tonumber(a.unit:match("(%d+)$")) or 0)<(tonumber(b.unit:match("(%d+)$")) or 0)
    end)
    scroll=math.max(0,math.min(scroll,math.max(0,#entries-capacity)))
    local count=math.min(capacity,#entries-scroll)
    for i=1,count do
        local entry=entries[i+scroll];local arrow=entry.arrow
        local row=rows[i];if not row then row=makeRow(i);rows[i]=row end
        row:SetWidth(panel:GetWidth())
        local compact=panel:GetWidth()<280
        row.name:SetWidth(math.max(60,panel:GetWidth()-(compact and 123 or 235)))
        if compact then row.state:Hide() else row.state:Show() end
        row.unit=entry.unit
        row.selected=arrow.targeted
        for _,mark in ipairs(row.chevrons) do if arrow.targeted then mark:Show() else mark:Hide() end end
        row.health:SetStatusBarColor(0.5,0.5,0.5,1)
        local fraction
        local healthOK=pcall(function()
            if type(UnitHealthPercent)~="function" then error("No normalized health API") end
            fraction=UnitHealthPercent(entry.unit,false)
            if not restricted(fraction) and type(fraction)~="number" then error("No health percent") end
            row.health:SetMinMaxValues(0,1);row.health:SetValue(fraction)
        end)
        if not healthOK then
            healthOK=pcall(function()
                local hp=UnitHealth(entry.unit);local maximum=UnitHealthMax(entry.unit)
                if not restricted(maximum) and (type(maximum)~="number" or maximum<=0) then error("No health maximum") end
                if not restricted(hp) and type(hp)~="number" then error("No health") end
                row.health:SetMinMaxValues(0,maximum);row.health:SetValue(hp)
                if not restricted(hp) and not restricted(maximum) then fraction=hp/maximum end
            end)
        end
        -- Color is optional: a failed curve must never hide a valid health fill.
        if healthOK then
            pcall(function()
                if not restricted(fraction) and type(fraction)=="number" then
                    local t=math.max(0,math.min(1,fraction))
                    row.health:SetStatusBarColor(math.min(1,2*(1-t)),math.min(1,2*t),0.08,1)
                elseif restricted(fraction) and C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor then
                    if not row.healthCurve then
                        local curve=C_CurveUtil.CreateColorCurve()
                        curve:AddPoint(0,CreateColor(1,0,0.08,1))
                        curve:AddPoint(0.5,CreateColor(1,1,0.08,1))
                        curve:AddPoint(1,CreateColor(0,1,0.08,1))
                        row.healthCurve=curve
                    end
                    -- UnitHealthPercent evaluates the curve inside the engine.
                    -- A generic curve Evaluate may reject restricted input.
                    local nativeOK=pcall(function()
                        local color=UnitHealthPercent(entry.unit,false,row.healthCurve)
                        row.health:SetStatusBarColor(color:GetRGB())
                    end)
                    if nativeOK then return end
                    if row.healthCurve.EvaluateUnpacked then
                        row.health:SetStatusBarColor(row.healthCurve:EvaluateUnpacked(fraction))
                    else
                        local color=row.healthCurve:Evaluate(fraction)
                        row.health:SetStatusBarColor(color:GetRGBA())
                    end
                end
            end)
        end
        if healthOK then row.health:Show();row.healthIconBG:Show()
        else row.health:SetValue(0);row.health:Hide();row.healthIconBG:Hide() end
        for _,part in ipairs(row.healthCross) do if healthOK then part:Show() else part:Hide() end end
        for _,edge in ipairs(row.selectionBorder) do
            if arrow.targeted then edge:Show() else edge:Hide() end
        end
        local ok,name=pcall(read,UnitName,entry.unit)
        if not ok or type(name)~="string" then name="Enemy" end
        local id=entry.unit:match("(%d+)$") or ""
        row.name:SetText(name.." #"..id)
        row.bg:SetColorTexture(0.03,0.04,0.05,panelHovered and db.panelOpacity/100 or 0)
        if arrow.targeted then
            local alpha=0.38+0.24*(0.5+0.5*math.sin(targetRowPhase*math.pi*2/1.4))
            row:SetStatusBarColor(0.08,0.35,1,alpha)
        end
        row.name:SetTextColor(1,arrow.targeted and 0.92 or 0.94,arrow.targeted and 0.65 or 0.85,1)
        local r,g,b=mobThreatColor(entry.unit,arrow.pct,arrow.tint or {0.55,0.6,0.68})
        row.threatColor={r,g,b}
        if arrow.targeted then row.stripe:SetColorTexture(0.35,0.9,1,1) else row.stripe:SetColorTexture(r,g,b,1) end
        if arrow.targeted then
            row:SetStatusBarColor(0.08,0.35,1,0.38+0.24*(0.5+0.5*math.sin(targetRowPhase*math.pi*2/1.4)))
        else row:SetStatusBarColor(r,g,b,0.55) end
        row.inTauntRange=tauntRange(entry.unit)
        if row.inTauntRange==false then
            row.rangeMark:SetText("T");row.rangeMark:SetTextColor(1,0.15,0.08,1)
            row.state:SetText("OUT OF RANGE");row.state:SetTextColor(1,0.15,0.08,1)
        elseif row.inTauntRange==true then
            row.rangeMark:SetText("T");row.rangeMark:SetTextColor(0.2,1,0.3,1)
            row.state:SetText(arrow.targeted and "TARGET" or (arrow.warning or ""))
        else
            row.rangeMark:SetText("?");row.rangeMark:SetTextColor(0.6,0.6,0.6,1)
            row.state:SetText(arrow.targeted and "TARGET" or (arrow.warning or ""))
        end
        row.state:SetTextColor(arrow.targeted and 1 or r,arrow.targeted and 0.9 or g,arrow.targeted and 0.3 or b,1)
        if row.inTauntRange==false then row.state:SetTextColor(1,0.15,0.08,1) end
        -- Native StatusBar accepts restricted values; never calculate a width in Lua.
        local filled=false
        if arrow.pct then filled=pcall(row.SetValue,row,arrow.pct.value) end
        if not filled then row:SetValue(0) end
        formatPercent(row.percent,arrow.pct)
        row:Show()
    end
    for i=count+1,#rows do rows[i].unit=nil;rows[i].selected=false;rows[i]:Hide() end
    if not panelHovered or #entries==0 then footer:SetText("")
    else footer:SetText((scroll+1).."–"..(scroll+count).." / "..#entries.." mobs") end
    panel:Show()
end
arrowToggle:SetScript("OnClick",function()
    local db=settings();db.arrowsHidden=not db.arrowsHidden
    for unit,arrow in pairs(active) do update(unit,arrow) end
    renderPanel()
end)
lockButton:SetScript("OnClick",function()
    local db=panelSettings();db.panelLocked=not db.panelLocked
    if db.panelLocked then panel:StopMovingOrSizing();resizing=false end
    renderPanel()
end)
options:SetScript("OnShow",function()
    opacitySlider:SetValue(panelSettings().panelOpacity)
end)
options.OnCommit=function() end
options.OnDefault=function() panelSettings().panelOpacity=35;renderPanel() end
options.OnRefresh=function() opacitySlider:SetValue(panelSettings().panelOpacity) end
bottomLock:SetScript("OnClick",lockButton:GetScript("OnClick"))
opacitySlider:SetScript("OnValueChanged",function(_,value)
    panelSettings().panelOpacity=math.max(0,math.min(100,value));renderPanel()
end)
panel:SetScript("OnSizeChanged",function(_,width,height)
    if positionLoaded then
        local db=panelSettings();db.panelWidth=width;db.panelHeight=height
        renderPanel()
    end
end)
local function setPanelHovered(value)
    panelHovered=value
    renderPanel()
end
panel:SetScript("OnEnter",function() setPanelHovered(true) end)
panel:SetScript("OnLeave",function()
    setPanelHovered(panel.IsMouseOver and panel:IsMouseOver() or false)
end)
leftGrip:SetScript("OnEnter",function() setPanelHovered(true) end)
leftGrip:SetScript("OnLeave",function() setPanelHovered(panel.IsMouseOver and panel:IsMouseOver() or false) end)
bottomLock:SetScript("OnEnter",function() setPanelHovered(true) end)
bottomLock:SetScript("OnLeave",function() setPanelHovered(panel.IsMouseOver and panel:IsMouseOver() or false) end)
grip:SetScript("OnEnter",function() setPanelHovered(true) end)
grip:SetScript("OnLeave",function() setPanelHovered(panel.IsMouseOver and panel:IsMouseOver() or false) end)
arrowToggle:HookScript("OnEnter",function() setPanelHovered(true) end)
arrowToggle:HookScript("OnLeave",function() setPanelHovered(panel.IsMouseOver and panel:IsMouseOver() or false) end)
lockButton:HookScript("OnEnter",function() setPanelHovered(true) end)
lockButton:HookScript("OnLeave",function() setPanelHovered(panel.IsMouseOver and panel:IsMouseOver() or false) end)
panel:SetScript("OnMouseWheel",function(_,delta) scroll=scroll-delta;renderPanel() end)
local function refresh()
    for unit,arrow in pairs(active) do update(unit,arrow) end
    renderPanel()
end

-- Appearance controls live in the existing AddOns settings, with real texture previews.
local styleButtons,colorFields={},{}
local rangeLabel=options:CreateFontString(nil,"OVERLAY","GameFontNormal")
rangeLabel:SetPoint("TOPLEFT",286,-88)
local rangeSlider=CreateFrame("Slider","ThreatArrowsMaxTauntDistance",options,"OptionsSliderTemplate")
rangeSlider:SetSize(180,16);rangeSlider:SetPoint("TOPLEFT",286,-119)
rangeSlider:SetMinMaxValues(1,40);rangeSlider:SetValueStep(1);rangeSlider:SetObeyStepOnDrag(true)
local rangeHint=options:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
rangeHint:SetPoint("TOPLEFT",286,-147);rangeHint:SetWidth(180);rangeHint:SetJustifyH("LEFT")
rangeHint:SetText("Warning only. ? = range unavailable.")
local function syncRange()
    local distance=settings().maxTauntDistance
    rangeLabel:SetText("Max taunt distance: "..distance.." yd")
    if rangeSlider:GetValue()~=distance then rangeSlider:SetValue(distance) end
end
rangeSlider:SetScript("OnValueChanged",function(_,n)
    if type(n)~="number" or n~=n then return end
    settings().maxTauntDistance=math.floor(math.max(1,math.min(40,n))+0.5)
    syncRange();refresh()
end)
local modeButton=CreateFrame("Button","ThreatArrowsColorMode",options,"UIPanelButtonTemplate")
modeButton:SetSize(300,24);modeButton:SetPoint("TOPLEFT",16,-339)
local function syncAppearance()
    syncRange()
    local db=settings()
    modeButton:SetText(db.customColors and "Colors: Custom threat states" or "Colors: Original threat gradient")
    for name,button in pairs(styleButtons) do
        button.caption:SetText((db.arrowStyle==name and "|cffffd166[ " or "|cffffffff")..name..(db.arrowStyle==name and " ]|r" or "|r"))
        button.preview.art:SetVertexColor(unpack(db.customColors and db.colors.secure or defaultColors.secure))
        -- Every card previews its own style, independently of the selected style.
        button.preview.art:SetTexCoord(unpack(styleCoords[name]))
    end
    for key,field in pairs(colorFields) do
        local c=db.colors[key]
        field:SetText(string.format("%02X%02X%02X",math.floor(c[1]*255+0.5),math.floor(c[2]*255+0.5),math.floor(c[3]*255+0.5)))
        field.swatch:SetColorTexture(c[1],c[2],c[3],1)
    end
end
local styleTitle=options:CreateFontString(nil,"OVERLAY","GameFontNormal")
styleTitle:SetPoint("TOPLEFT",16,-218);styleTitle:SetText("Arrow style (click to select)")
for i,name in ipairs(styles) do
    local button=CreateFrame("Button","ThreatArrowsStyle"..name,options)
    button:SetSize(90,92);button:SetPoint("TOPLEFT",16+(i-1)*96,-240)
    button.preview=makeArrow(button);button.preview:SetPoint("TOP",button,"TOP",0,0)
    button.preview:SetAlpha(1)
    button.preview:Show()
    button.caption=button:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    button.caption:SetPoint("BOTTOM",button,"BOTTOM",0,6)
    button:SetScript("OnClick",function() settings().arrowStyle=name;refresh();syncAppearance() end)
    styleButtons[name]=button
end
modeButton:SetScript("OnClick",function()
    local db=settings();db.customColors=not db.customColors;refresh();syncAppearance()
end)
-- HSV wheel: radius controls saturation, angle controls hue, slider controls value.
local colorPicker=CreateFrame("Frame","ThreatArrowsColorWheel",UIParent)
colorPicker:SetSize(360,400);colorPicker:SetPoint("CENTER",UIParent,"CENTER",0,0)
colorPicker:SetFrameStrata("DIALOG");colorPicker:SetClampedToScreen(true);colorPicker:EnableMouse(true)
local pickerBG=colorPicker:CreateTexture(nil,"BACKGROUND")
pickerBG:SetAllPoints();pickerBG:SetColorTexture(0.035,0.04,0.055,1)
local pickerTitle=colorPicker:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
pickerTitle:SetPoint("TOPLEFT",16,-16)
local wheel=CreateFrame("Button","ThreatArrowsColorWheelSurface",colorPicker)
wheel:SetSize(240,240);wheel:SetPoint("TOPLEFT",16,-52)
local wheelArt=wheel:CreateTexture(nil,"ARTWORK")
wheelArt:SetAllPoints();wheelArt:SetTexture("Interface\\AddOns\\ThreatArrows\\Media\\ColorWheel.tga")
local marker=CreateFrame("Frame",nil,wheel);marker:SetSize(16,16);marker:EnableMouse(false)
for _,part in ipairs({{4,16,0},{16,4,0},{2,12,1},{12,2,1}}) do
    local t=marker:CreateTexture(nil,"OVERLAY")
    t:SetSize(part[1],part[2]);t:SetPoint("CENTER",marker,"CENTER",0,0)
    t:SetColorTexture(part[3],part[3],part[3],1)
end
local brightness=CreateFrame("Slider","ThreatArrowsColorBrightness",colorPicker,"OptionsSliderTemplate")
brightness:SetSize(240,16);brightness:SetPoint("TOPLEFT",16,-321)
brightness:SetMinMaxValues(0,100);brightness:SetValueStep(1);brightness:SetObeyStepOnDrag(true)
local brightnessLabel=colorPicker:CreateFontString(nil,"OVERLAY","GameFontNormal")
brightnessLabel:SetPoint("TOPLEFT",16,-300)
local sample=makeArrow(colorPicker);sample:SetPoint("TOPLEFT",colorPicker,"TOPLEFT",276,-115)
sample:SetAlpha(1);sample:Show()
local sampleLabel=colorPicker:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
sampleLabel:SetPoint("TOP",sample,"BOTTOM",0,-8);sampleLabel:SetText("Preview")
local pickerKey,originalColor,originalMode,hue,saturation,value
local dragging=false
local function hsvToRGB(h,s,v)
    local sector=math.floor(h*6);local f=h*6-sector
    local p,q,t=v*(1-s),v*(1-f*s),v*(1-(1-f)*s)
    local rgb={{v,t,p},{q,v,p},{p,v,t},{p,q,v},{t,p,v},{v,p,q}}
    return unpack(rgb[sector%6+1])
end
local function updateColorWheel()
    if not pickerKey then return end
    local r,g,b=hsvToRGB(hue,saturation,value)
    local db=settings();db.colors[pickerKey]={r,g,b};db.customColors=true
    marker:ClearAllPoints();marker:SetPoint("CENTER",wheel,"CENTER",math.cos(hue*2*math.pi)*saturation*118,math.sin(hue*2*math.pi)*saturation*118)
    wheelArt:SetVertexColor(value,value,value,1)
    brightnessLabel:SetText("Brightness: "..math.floor(value*100+0.5).."%")
    applyStyle(sample);sample.art:SetVertexColor(r,g,b,1)
    refresh();syncAppearance()
end
local function sampleWheelCursor(clamp)
    local cx,cy=wheel:GetCenter();local scale=wheel:GetEffectiveScale()
    if not cx or not cy or not scale or scale<=0 then return false end
    local x,y=GetCursorPosition();local dx,dy=(x/scale-cx)/118,(y/scale-cy)/118
    local radius=math.sqrt(dx*dx+dy*dy)
    if radius>1 and not clamp then return false end
    if radius>0 then hue=(math.atan2(dy,dx)/(2*math.pi))%1 end
    saturation=math.min(1,radius);updateColorWheel();return true
end
wheel:SetScript("OnMouseDown",function(_,button)
    if button=="LeftButton" and pickerKey then dragging=sampleWheelCursor(false) end
end)
wheel:SetScript("OnMouseUp",function() dragging=false end)
colorPicker:SetScript("OnUpdate",function()
    if dragging then
        if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then dragging=false
        else sampleWheelCursor(true) end
    end
end)
brightness:SetScript("OnValueChanged",function(_,n)
    if not pickerKey then return end
    value=math.max(0,math.min(1,n/100));updateColorWheel()
end)
colorPicker:SetScript("OnHide",function()
    dragging=false
    if pickerKey then
        local db=settings();db.colors[pickerKey]=originalColor;db.customColors=originalMode
        pickerKey=nil;refresh();syncAppearance()
    end
end)
colorPicker:Hide()
if type(UISpecialFrames)=="table" then table.insert(UISpecialFrames,"ThreatArrowsColorWheel") end
options:HookScript("OnHide",function() colorPicker:Hide() end)
local function openColorWheel(key)
    colorPicker:Hide() -- Cancel an unfinished edit before switching states.
    for _,field in pairs(colorFields) do field:ClearFocus() end
    local db=settings();local c=db.colors[key]
    originalColor={c[1],c[2],c[3]};originalMode=db.customColors
    local maximum,minimum=math.max(c[1],c[2],c[3]),math.min(c[1],c[2],c[3])
    local delta=maximum-minimum
    hue=0;saturation=maximum>0 and delta/maximum or 0;value=maximum
    if delta>0 then
        if maximum==c[1] then hue=((c[2]-c[3])/delta)%6
        elseif maximum==c[2] then hue=(c[3]-c[1])/delta+2
        else hue=(c[1]-c[2])/delta+4 end
        hue=hue/6
    end
    pickerTitle:SetText(key:sub(1,1):upper()..key:sub(2).." arrow color")
    -- Set the slider before enabling callbacks; opening preserves the saved mode.
    brightness:SetValue(value*100);pickerKey=key
    marker:ClearAllPoints();marker:SetPoint("CENTER",wheel,"CENTER",math.cos(hue*2*math.pi)*saturation*118,math.sin(hue*2*math.pi)*saturation*118)
    wheelArt:SetVertexColor(value,value,value,1)
    brightnessLabel:SetText("Brightness: "..math.floor(value*100+0.5).."%")
    applyStyle(sample);sample.art:SetVertexColor(c[1],c[2],c[3],1)
    colorPicker:Show()
end
local done=CreateFrame("Button","ThreatArrowsColorDone",colorPicker,"UIPanelButtonTemplate")
done:SetSize(110,24);done:SetPoint("BOTTOMLEFT",16,16);done:SetText("Done")
done:SetScript("OnClick",function() pickerKey=nil;colorPicker:Hide() end)
local cancel=CreateFrame("Button","ThreatArrowsColorCancel",colorPicker,"UIPanelButtonTemplate")
cancel:SetSize(110,24);cancel:SetPoint("BOTTOMRIGHT",-16,16);cancel:SetText("Cancel")
cancel:SetScript("OnClick",function() colorPicker:Hide() end)
local colorHelp=options:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
colorHelp:SetPoint("TOPLEFT",16,-373)
colorHelp:SetText("Click a swatch for the color circle, or enter RRGGBB and press Enter.")
for i,key in ipairs({"secure","losing","lost","unknown"}) do
    local label=options:CreateFontString(nil,"OVERLAY","GameFontNormal")
    label:SetPoint("TOPLEFT",16,-405-(i-1)*30)
    label:SetText(key:sub(1,1):upper()..key:sub(2))
    local field=CreateFrame("EditBox","ThreatArrowsColor"..key,options,"InputBoxTemplate")
    field:SetSize(100,24);field:SetPoint("TOPLEFT",options,"TOPLEFT",126,-398-(i-1)*30)
    field:SetAutoFocus(false);field:SetMaxLetters(7)
    field.swatch=options:CreateTexture(nil,"ARTWORK")
    field.swatch:SetSize(20,20);field.swatch:SetPoint("LEFT",field,"RIGHT",10,0)
    local swatchButton=CreateFrame("Button","ThreatArrowsSwatch"..key,options)
    swatchButton:SetAllPoints(field.swatch)
    swatchButton:SetScript("OnClick",function()
        openColorWheel(key)
    end)
    field:SetScript("OnEnterPressed",function(self)
        local hex=(self:GetText() or ""):gsub("^#","")
        if #hex==6 and hex:match("^%x+$") then
            local db=settings();db.colors[key]={tonumber(hex:sub(1,2),16)/255,tonumber(hex:sub(3,4),16)/255,tonumber(hex:sub(5,6),16)/255}
            db.customColors=true;refresh();syncAppearance();self:ClearFocus()
        else
            print("Threat Arrows: enter six hexadecimal digits, for example 33CCFF.")
        end
    end)
    field:SetScript("OnEscapePressed",function(self) self:ClearFocus();syncAppearance() end)
    colorFields[key]=field
end
local resetAppearance=CreateFrame("Button","ThreatArrowsResetAppearance",options,"UIPanelButtonTemplate")
resetAppearance:SetSize(180,24);resetAppearance:SetPoint("TOPLEFT",16,-529)
resetAppearance:SetText("Reset arrow appearance")
resetAppearance:SetScript("OnClick",function()
    colorPicker:Hide()
    local db=settings();db.arrowStyle="Sentinel";db.colors=nil;db.customColors=false
    settings();refresh();syncAppearance()
end)
options:HookScript("OnShow",syncAppearance)
local previousDefault=options.OnDefault
options.OnDefault=function() settings().maxTauntDistance=10;previousDefault();resetAppearance:GetScript("OnClick")() end
options.OnRefresh=function() opacitySlider:SetValue(panelSettings().panelOpacity);syncAppearance() end

driver:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then add(unit)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then remove(unit)
    elseif event == "PLAYER_LOGIN" then registerOptions();positionMinimapButton();refresh()
    elseif event == "PLAYER_ENTERING_WORLD" then registerOptions();positionMinimapButton()
        for token in pairs(active) do remove(token) end
        settings()
        if C_NamePlate and C_NamePlate.GetNamePlates then
            for _,plate in ipairs(C_NamePlate.GetNamePlates()) do
                local token = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
                if token then add(token) end
            end
        end
    else refresh();return end
    renderPanel()
end)
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","NAME_PLATE_UNIT_ADDED","NAME_PLATE_UNIT_REMOVED",
    "UNIT_THREAT_SITUATION_UPDATE","UNIT_THREAT_LIST_UPDATE","UNIT_TARGET","PLAYER_TARGET_CHANGED","PLAYER_REGEN_ENABLED"}) do
    driver:RegisterEvent(event)
end
driver:SetScript("OnUpdate", function(_, delta)
    targetRowPhase=targetRowPhase+delta
    local selectionAlpha=0.38+0.24*(0.5+0.5*math.sin(targetRowPhase*math.pi*2/1.4))
    for _,row in ipairs(rows) do
        if row.selected then row:SetStatusBarColor(0.08,0.35,1,selectionAlpha) end
    end
    for _,arrow in pairs(active) do
        if enabled and arrow.warning then
            arrow.warningPhase=(arrow.warningPhase or 0)+delta
            arrow.art:SetAlpha(warningAlpha(arrow))
        end
        if enabled and arrow.targeted then
            arrow.phase=(arrow.phase or 0)+delta
            applyLayout(arrow, 6*(1-math.cos(arrow.phase*math.pi*2/0.9)))
        end
    end
    elapsed = elapsed+delta
    if elapsed < 0.1 then return end
    elapsed = 0
    refresh()
end)
SLASH_THREATARROWS1 = "/threatarrows"
SLASH_THREATARROWS2 = "/ta"
SlashCmdList.THREATARROWS = function(text)
    local cmd, value = text:match("^%s*(%S*)%s*(.-)%s*$")
    cmd = string.lower(cmd or "")
    local n = tonumber(value)
    if cmd == "status" then
        print("Threat Arrows 2.3.1 | opacity "..settings().opacity.."%")
        for unit,arrow in pairs(active) do
            if selected(unit) then print("Selected arrow percentage source: "..(arrow.percentageSource or "unavailable")) end
        end
        return
    elseif cmd == "options" then
        openOptions()
        return
    elseif cmd == "on" then enabled = true
    elseif cmd == "off" then enabled = false
    elseif cmd == "size" and n and n >=24 and n <=160 then settings().size=n
    elseif cmd == "offset" and n and n >=0 and n <=150 then settings().offset=n
    elseif cmd == "opacity" and n and n>=10 and n<=100 then settings().opacity=n
    elseif cmd == "panel" then
        if value=="show" then settings().panelHidden=false
        elseif value=="hide" then settings().panelHidden=true
        elseif value=="lock" then settings().panelLocked=true;panel:StopMovingOrSizing();resizing=false
        elseif value=="unlock" then settings().panelLocked=false
        elseif value:match("^opacity %d+$") then panelSettings().panelOpacity=math.max(0,math.min(100,tonumber(value:match("%d+"))))
        else print("/ta panel show/hide/lock/unlock | /ta panel opacity 0-100");return end
    elseif cmd == "reset" then ThreatArrowsDB = nil; settings();positionLoaded=false;scroll=0
    else print("Threat Arrows: /ta size 24-160 | /ta offset 0-150 | /ta opacity 10-100 | /ta panel show/hide | /ta options | /ta status | /ta on | /ta off | /ta reset. Enable enemy nameplates (V). Threat %: red -> yellow -> green. Without %: green=secure, orange=insecure, red=lost, gray=unknown. Selected target bounces."); return end
    positionMinimapButton()
    for _,arrow in pairs(active) do applyLayout(arrow) end
    refresh()
end
