-- Lua 5.1+ mock tests. No game client or game input.
local frames={}
local function object(parent)
    return setmetatable({parent=parent, scripts={},shown=false,level=1}, {__index=function(self,key)
        if key:match("^[a-z]") or key=="ThreatArrowsOverlay" or key=="UnitFrame" then return nil end
        if key=="SetSize" then return function(s,w,h) s.width=w;s.height=h end end
        if key=="SetWidth" then return function(s,w) s.width=w end end
        if key=="SetHeight" then return function(s,h) s.height=h end end
        if key=="GetWidth" then return function(s) return s.width or 330 end end
        if key=="GetHeight" then return function(s) return s.height or 294 end end
        if key=="GetValue" then return function(s) return s.value end end
        if key=="SetValue" then return function(s,v) s.value=v end end
        if key=="StartMoving" then return function(s) s.moving=true end end
        if key=="StartSizing" then return function(s) s.sizing=true end end
        if key=="StopMovingOrSizing" then return function(s) s.moving=false;s.sizing=false end end
        if key=="GetCenter" then return function(s) return s.cx or 0,s.cy or 0 end end
        if key=="GetScript" then return function(s,event) return s.scripts[event] end end
        if key=="SetScript" then return function(s,event,fn) s.scripts[event]=fn end end
        if key=="GetParent" then return function(s) return s.parent end end
        if key=="GetFrameLevel" then return function(s) return s.level end end
        if key=="CreateFontString" then return function(s) return object(s) end end
        if key=="SetFormattedText" then return function(s,fmt,v)
            s.formattedValue=v
            if type(v)=="table" and v.secret then s.text="rendered-secret" else s.text=string.format(fmt,v) end
        end end
        if key=="SetText" then return function(s,v) s.text=v end end
        if key=="GetText" then return function(s) return s.text end end
        if key=="SetTexture" then return function(s,v) s.texturePath=v end end
        if key=="SetTexCoord" then return function(s,...) s.coords={...} end end
        if key=="CreateTexture" then return function(s) return object(s) end end
        if key=="Show" then return function(s) local was=s.shown;s.shown=true;if not was and s.scripts.OnShow then s.scripts.OnShow(s) end end end
        if key=="Hide" then return function(s) local was=s.shown;s.shown=false;if was and s.scripts.OnHide then s.scripts.OnHide(s) end end end
        if key=="SetStatusBarColor" then return function(s,...) s.fillColor={...} end end
        if key=="SetColorTexture" then return function(s,...) s.fill={...} end end
        if key=="IsMouseOver" then return function(s) return s.hovered or false end end
        if key=="SetVertexColor" then return function(s,r,g,b) s.color={r,g,b} end end
        if key=="SetAlpha" then return function(s,v) s.alpha=v end end
        if key=="SetScale" then return function(s,v) s.scale=v end end
        if key=="SetPoint" then return function(s,...) s.point={...} end end
        if key=="IsForbidden" then return function() return false end end
        return function() end
    end})
end
UIParent=object()
Minimap=object(UIParent);Minimap:SetSize(140,140)
CreateFrame=function(_,name,parent) local f=object(parent);frames[#frames+1]=f;if name then _G[name]=f end;return f end
SlashCmdList={}
local units,plates={},{}
local target
UnitIsUnit=function(a,b) return b=="target" and a==target end
UnitDetailedThreatSituation=function(_,u)
    if u=="target" then u=target end
    local d=units[u] or {}
    return d.tanking,nil,d.pct,d.raw
end
local function data(u) return units[u] or {} end
UnitName=function(u) return data(u).name or "Sand Crawler" end
UnitExists=function(u) return units[u]~=nil end
UnitCanAttack=function(_,u) return not data(u).friendly end
UnitIsPlayer=function(u) return data(u).player end
UnitIsDeadOrGhost=function(u) return data(u).dead end
UnitAffectingCombat=function(u) return data(u).combat end
UnitThreatSituation=function(a,b) if b then return data(b).status else return data(a).mobStatus end end
issecretvalue=function(v) return type(v)=="table" and v.secret end
C_NamePlate={GetNamePlateForUnit=function(u) return plates[u] end,GetNamePlates=function() local t={} for _,p in pairs(plates) do t[#t+1]=p end return t end}
dofile("app/addons/ThreatArrows/ThreatArrows.lua")
local driver=frames[1]
local function event(e,u) driver.scripts.OnEvent(driver,e,u) end
local function add(u,info) units[u]=info;plates[u]=object();plates[u].namePlateUnitToken=u;event("NAME_PLATE_UNIT_ADDED",u);return plates[u].ThreatArrowsOverlay end
local function tick() driver.scripts.OnUpdate(driver,0.11) end
local function color(a,which) assert(a.shown);assert(a.parts[1].texture.color[which]>=0.95) end
local a=add("nameplate1",{status=3,combat=true});color(a,2);assert(a.alpha==0.65,"slight transparency")
for status=0,1 do units.nameplate1.status=status;tick();color(a,1) end
units.nameplate1={combat=true,mobStatus=3};tick();color(a,1)
units.nameplate1={combat=true};tick();assert(a.shown and a.parts[1].texture.color[1]<0.6,"unknown gray")
units.nameplate1={status=0};tick();assert(not a.shown,"idle hidden")
for _,flag in ipairs({"friendly","player","dead"}) do units.nameplate1={status=3,combat=true};units.nameplate1[flag]=true;tick();assert(not a.shown,flag) end
units.nameplate1={status={secret=true},combat=true};tick();assert(a.shown and a.parts[1].texture.color[1]<0.6,"restricted gray")
units.nameplate1={status=3,combat=true};tick();color(a,2)
local b=add("nameplate2",{status=1,combat=true});color(b,1);color(a,2)
-- Real percentage colors, clamping, and secret fallback.
local function rgb() return a.parts[1].texture.color end
for _,pct in ipairs({0,25,50,75,100,150,-10}) do
    units.nameplate1={combat=true,status=0,pct=pct};tick()
    local t=math.max(0,math.min(100,pct))/100
    assert(a.percentageText==nil and a.pct.value==math.max(0,pct), "arrows keep threat data without percentage text")
    local shade=a.parts[1].shade
    assert(math.abs(rgb()[1]-math.min(1,2*(1-t))*shade)<0.0001)
    assert(math.abs(rgb()[2]-math.min(1,2*t)*shade)<0.0001)
end
units.nameplate1={combat=true,status=1,pct={secret=true}};tick()
assert(a.percentageText==nil and a.pct.secret, "restricted percentage retained for meter only")
assert(rgb()[1]>rgb()[2],"secret percentage uses state fallback")
units.nameplate1={combat=true,status=0,raw=10.8,pct=8.3};tick()
assert(a.pct.value==10.8,"Tiny Threat raw percentage preferred over scaled")
units.nameplate1={combat=true,status=3,tanking=true,raw=255,pct=100};tick()
assert(a.pct.value==100,"tank guard matches Tiny Threat")
local secret=setmetatable({secret=true},{__lt=function() error("secret compared") end,__add=function() error("secret arithmetic") end})
units.nameplate1={combat=true,status=0,raw=secret};tick()
assert(a.percentageText==nil and a.pct.value==secret)
SlashCmdList.THREATARROWS("opacity 40");assert(a.alpha==0.4 and ThreatArrowsDB.opacity==40)
SlashCmdList.THREATARROWS("opacity 101");assert(a.alpha==0.4)
SlashCmdList.THREATARROWS("reset");assert(a.alpha==0.65)
units.nameplate1={combat=true,status=3}
target="nameplate1";event("PLAYER_TARGET_CHANGED");tick()
assert(a.targeted and not b.targeted)
local base=b.point[5];local first=a.point[5];tick()
assert(a.point[5]~=first and b.point[5]==base,"only target bounces")
target="nameplate2";event("PLAYER_TARGET_CHANGED")
assert(not a.targeted and b.targeted and a.point[5]==20,"old target rests immediately")
target=nil;event("PLAYER_TARGET_CHANGED");assert(not b.targeted and b.point[5]==20)
units.nameplate1={combat=false};target="nameplate1";event("PLAYER_TARGET_CHANGED")
assert(a.shown and a.targeted,"idle selected target still marked")
units.nameplate1={combat=true,status=3};target=nil;event("PLAYER_TARGET_CHANGED")
SlashCmdList.THREATARROWS("off");assert(not a.shown and not b.shown)
SlashCmdList.THREATARROWS("on");color(a,2);color(b,1)
SlashCmdList.THREATARROWS("size 96");assert(a.scale==1.5 and ThreatArrowsDB.size==96)
SlashCmdList.THREATARROWS("offset 30");assert(a.point[5]==20)
SlashCmdList.THREATARROWS("size 999");assert(ThreatArrowsDB.size==96)
event("NAME_PLATE_UNIT_REMOVED","nameplate1");assert(not a.shown);tick();assert(not a.shown)
event("NAME_PLATE_UNIT_ADDED","nameplate1");assert(plates.nameplate1.ThreatArrowsOverlay==a);color(a,2)
units.nameplate1=nil;tick();assert(not a.shown,"despawn hidden")
event("PLAYER_ENTERING_WORLD");color(b,1)
SlashCmdList.THREATARROWS("reset");assert(ThreatArrowsDB.size==64 and ThreatArrowsDB.offset==20)
print("PASS: percentage gradient/clamping/secret fallback, selected-only bounce and target switching, threat states 0-3, nil/restricted threat, idle/friendly/player/dead/despawn, simultaneous nameplates, removal/reuse, world entry, size/offset/reset and on/off. No game input.")

-- Panel roster and warnings.
units.nameplate1={combat=true,status=2,name="Same Mob"}
units.nameplate2={combat=true,status=0,raw=20,name="Same Mob"}
event("NAME_PLATE_UNIT_ADDED","nameplate1")
local panel=ThreatArrowsThreatPanel
local function panelRows()
    local result={}
    for _,frame in ipairs(frames) do if frame.parent==panel and frame.unit then result[#result+1]=frame end end
    return result
end
target="nameplate2";event("PLAYER_TARGET_CHANGED")
local roster=panelRows();assert(#roster==2)
assert(roster[2].unit=="nameplate2" and roster[2].state.text=="TARGET")
assert(roster[2].percent.text=="20%")
local current=plates.nameplate1.ThreatArrowsOverlay
assert(current.warning=="LOSING" and current.halo.shown and current.warningText.text=="LOSING")
local lost=plates.nameplate2.ThreatArrowsOverlay
assert(lost.warning=="LOST" and lost.halo.shown)
tick();local alpha=lost.halo.alpha;tick();assert(lost.halo.alpha~=alpha,"halo pulses")
units.nameplate1.status=3;tick();assert(not current.halo.shown and current.warningText.text=="")
units.nameplate2.raw=secret;tick();assert(panelRows()[2].percent.formattedValue==secret)
units.nameplate2.dead=true;tick();assert(#panelRows()==1,"dead row removed")
units.nameplate2.dead=false
for i=3,15 do add("nameplate"..i,{combat=true,status=3,name="Extra Mob"}) end
tick();assert(#panelRows()==15,"compact rows fit height")
panel:SetHeight(140);panel.scripts.OnSizeChanged(panel,330,140)
panel.scripts.OnMouseWheel(panel,-5);assert(panelRows()[1].unit~="nameplate2","scroll changes entries")
SlashCmdList.THREATARROWS("panel hide");assert(not panel.shown and ThreatArrowsDB.panelHidden)
SlashCmdList.THREATARROWS("panel show");assert(panel.shown)
SlashCmdList.THREATARROWS("off");assert(not panel.shown)
SlashCmdList.THREATARROWS("on");assert(panel.shown)
for i=1,15 do event("NAME_PLATE_UNIT_REMOVED","nameplate"..i) end
assert(#panelRows()==0,"removed plates leave no rows")
print("PASS: losing/lost halos and pulse, secure reset, panel roster, duplicate mob names, selected row, secret display, death/removal, 15-mob scrolling and panel toggles.")

SlashCmdList.THREATARROWS("panel unlock")
panel.scripts.OnDragStart(panel);assert(panel.moving)
panel.cx=123;panel.cy=-45;panel.scripts.OnDragStop(panel)
assert(ThreatArrowsDB.panelPosition.x==123 and ThreatArrowsDB.panelPosition.y==-45)
ThreatArrowsPanelLock.scripts.OnClick();assert(ThreatArrowsDB.panelLocked)
panel.scripts.OnDragStart(panel);assert(not panel.moving,"locked panel cannot move")
ThreatArrowsPanelResize.scripts.OnMouseDown(nil,"LeftButton");assert(not panel.sizing)
ThreatArrowsPanelLock.scripts.OnClick();assert(not ThreatArrowsDB.panelLocked)
ThreatArrowsPanelResize.scripts.OnMouseDown(nil,"LeftButton");assert(panel.sizing)
panel:SetSize(440,429);panel.scripts.OnSizeChanged(panel,440,429)
ThreatArrowsPanelResize.scripts.OnMouseUp()
assert(ThreatArrowsDB.panelWidth==440 and ThreatArrowsDB.panelHeight==429)
ThreatArrowsPanelOpacity.scripts.OnValueChanged(nil,20);assert(ThreatArrowsDB.panelOpacity==20)
SlashCmdList.THREATARROWS("panel opacity 50");assert(ThreatArrowsDB.panelOpacity==50)
SlashCmdList.THREATARROWS("panel lock");assert(ThreatArrowsDB.panelLocked)
SlashCmdList.THREATARROWS("reset");assert(not ThreatArrowsDB.panelLocked and ThreatArrowsDB.panelWidth==330)
print("PASS: panel movement, position persistence, lock button and commands, guarded resizing, size persistence, opacity slider and command, reset.")

assert(ThreatArrowsPanelOpacity.parent==ThreatArrowsOptionsPanel,"slider is in options, not meter")
local registrations=0
Settings={RegisterCanvasLayoutCategory=function(frame,name) assert(frame==ThreatArrowsOptionsPanel);return {GetID=function() return 123 end} end,
RegisterAddOnCategory=function() registrations=registrations+1 end,
OpenToCategory=function(id) assert(id==123) end}
event("PLAYER_LOGIN");event("PLAYER_ENTERING_WORLD");assert(registrations==1)
SlashCmdList.THREATARROWS("options")
ThreatArrowsOptionsPanel.OnDefault();assert(ThreatArrowsDB.panelOpacity==35)
print("PASS: settings category registered once, opacity slider relocated, options command and default reset.")

panel.scripts.OnEnter(panel);assert(ThreatArrowsPanelResize.shown,"hover shows resize grip")
panel.hovered=false;panel.scripts.OnLeave(panel);assert(not ThreatArrowsPanelResize.shown,"no hover hides grip")
print("PASS: hover reveals resize controls and leaving hides them.")

for i=1,15 do event("NAME_PLATE_UNIT_REMOVED","nameplate"..i) end
add("nameplate21",{combat=true,status=3,name="Pulse target"})
add("nameplate22",{combat=true,status=0,raw=15,name="Other mob"})
target="nameplate21";event("PLAYER_TARGET_CHANGED")
local pulseRow=panelRows()[1];assert(pulseRow.selected)
local startAlpha=pulseRow.fillColor[4];tick()
assert(pulseRow.fillColor[4]~=startAlpha and pulseRow.fillColor[4]>=0.38 and pulseRow.fillColor[4]<=0.62)
target="nameplate22";event("PLAYER_TARGET_CHANGED");tick()
assert(panelRows()[2].unit=="nameplate22" and panelRows()[2].selected)
assert(not panelRows()[1].selected,"pulse leaves old selected row")
print("PASS: selected row pulses gold within bounds and follows target switches.")

local selectedRow=panelRows()[2]
assert(selectedRow.threatColor~=nil,"selected pulse retains threat color")
for _,edge in ipairs(selectedRow.selectionBorder) do assert(edge.shown and edge.fill[4]==0.95,"crisp selected outline") end
for _,edge in ipairs(panelRows()[1].selectionBorder) do assert(not edge.shown,"other rows have no selected border") end
target="nameplate21";event("PLAYER_TARGET_CHANGED")
for _,edge in ipairs(panelRows()[1].selectionBorder) do assert(edge.shown) end
for _,edge in ipairs(panelRows()[2].selectionBorder) do assert(not edge.shown) end
print("PASS: green selection pulse and opaque four-edge border follow the selected target.")

units.nameplate21={combat=true,status=0,raw=35};tick()
assert(panelRows()[1].value==35,"bar fills to actual percentage")
units.nameplate21.raw=secret;tick();assert(panelRows()[1].value==secret,"restricted value passed directly to native bar")
units.nameplate21={combat=true};tick();assert(panelRows()[1].value==0,"unknown percentage clears old fill")
print("PASS: left-to-right bar value, restricted UI values and stale fill clearing.")

for _,edge in ipairs(panelRows()[1].selectionBorder) do assert(edge.fill[1]==0.82 and edge.fill[3]==1 and edge.fill[4]==0.95,"icy white selected outline") end

ThreatArrowsArrowToggle.scripts.OnClick()
assert(ThreatArrowsDB.arrowsHidden and not plates.nameplate21.ThreatArrowsOverlay.shown)
assert(panel.shown and #panelRows()>0,"list stays active with arrows hidden")
tick();assert(not plates.nameplate22.ThreatArrowsOverlay.shown and panel.shown)
ThreatArrowsArrowToggle.scripts.OnClick()
assert(not ThreatArrowsDB.arrowsHidden and plates.nameplate21.ThreatArrowsOverlay.shown)
print("PASS: overhead arrow toggle hides arrows independently of active threat list.")

panel:SetSize(180,60);panel.scripts.OnSizeChanged(panel,180,60)
assert(ThreatArrowsDB.panelWidth==180 and ThreatArrowsDB.panelHeight==60)
assert(#panelRows()==1 and panelRows()[1].name.width==60 and not panelRows()[1].state.shown)
assert(panelRows()[1].percent.text~=nil,"percentage retained in compact mode")
panel:SetSize(330,160);panel.scripts.OnSizeChanged(panel,330,160)
assert(panelRows()[1].state.shown,"state restored at wider size")
print("PASS: 180x60 compact meter, one-row scrolling capacity, name space and wide layout restoration.")

SlashCmdList.THREATARROWS("panel unlock");panel.scripts.OnEnter(panel)
assert(ThreatArrowsPanelResizeLeft.shown and ThreatArrowsPanelBottomLock.shown)
ThreatArrowsPanelResizeLeft.scripts.OnMouseDown(nil,"LeftButton");assert(panel.sizing)
ThreatArrowsPanelResizeLeft.scripts.OnMouseUp();assert(not panel.sizing)
ThreatArrowsPanelBottomLock.scripts.OnClick();assert(ThreatArrowsDB.panelLocked and not ThreatArrowsPanelResizeLeft.shown)
ThreatArrowsPanelBottomLock.scripts.OnClick();assert(not ThreatArrowsDB.panelLocked)
panel.scripts.OnLeave(panel);assert(not ThreatArrowsPanelBottomLock.shown)
print("PASS: dual corner resize handles, shared resize completion, bottom lock toggle and hover visibility.")

panel:SetSize(330,160);panel.scripts.OnSizeChanged(panel,330,160)
local before={};for i,row in ipairs(panelRows()) do before[i]=row.unit end
for _,unit in ipairs({"nameplate22","nameplate21","nameplate22"}) do
 target=unit;event("PLAYER_TARGET_CHANGED")
 for i,row in ipairs(panelRows()) do assert(row.unit==before[i],"target changes must not reorder list") end
end
print("PASS: target rotation moves selection in place without reordering rows.")

UnitHealth=function(u) return u=="nameplate21" and 45 or 80 end
UnitHealthMax=function() return 100 end
target="nameplate21";event("PLAYER_TARGET_CHANGED")
assert(panelRows()[1].health.value==45 and panelRows()[1].health.fillColor[2]==0.9)
assert(panelRows()[2].health.value==80 and panelRows()[2].health.fillColor[2]==1)
assert(panelRows()[1].chevrons[1].shown and not panelRows()[2].chevrons[1].shown)
UnitHealth=function() return nil end;tick();assert(not panelRows()[1].health.shown)
print("PASS: independent mob health bars, selected green/other blue, unknown health hides bar and selected chevrons.")

UnitHealthMax=function() return 100 end
for _,hp in ipairs({10,50,100}) do
 UnitHealth=function() return hp end;tick()
 local c=panelRows()[1].health.fillColor
 assert(c[1]==math.min(1,2*(1-hp/100)) and c[2]==math.min(1,2*hp/100))
 assert(panelRows()[1].healthCross[1].shown)
end
print("PASS: health color gradient red/yellow/green and healing cross visibility.")

UnitHealthPercent=function() return 0.35 end;tick()
assert(panelRows()[1].health.value==0.35 and panelRows()[1].health.shown)
UnitHealthPercent=function() return secret end
local curveCalls=0
CreateColor=function(...) return {...} end
C_CurveUtil={CreateColorCurve=function() return {AddPoint=function() end,EvaluateUnpacked=function(_,value) assert(value==secret);curveCalls=curveCalls+1;return 1,0.3,0.08,1 end} end}
tick();assert(panelRows()[1].health.value==secret and curveCalls>0,"native curve consumes restricted health")
units.nameplate21={combat=true,status=3,raw=255,tanking=secret};tick()
assert(panelRows()[1].percent.text=="100%" and panelRows()[1].value==100,"confirmed tank overrides invalid raw 255 even with secret tank flag")
print("PASS: normalized health percentage, restricted native color curve, and public tank-state guard against invalid 255%.")

C_Spell={GetSpellInfo=function() return {minRange=0,maxRange=10} end,IsSpellInRange=function(_,unit) return unit=="nameplate21" end}
tick();assert(panelRows()[1].inTauntRange==true)
assert(panelRows()[2].inTauntRange==false and panelRows()[2].state.text=="OUT OF RANGE")
C_Spell.IsSpellInRange=function() return nil end;tick();assert(panelRows()[1].rangeMark.text=="?")
C_Spell.IsSpellInRange=function() return secret end;tick();assert(panelRows()[1].rangeMark.text=="?")
C_Spell.IsSpellInRange=function() return 0 end;tick();assert(panelRows()[1].state.text=="OUT OF RANGE")
print("PASS: Judgement spell range IN/OUT, numeric API responses and nil/restricted unknown handling.")

for _,row in ipairs(panelRows()) do row.healthCurve={EvaluateUnpacked=function() error("unsupported curve") end} end
UnitHealthPercent=function() return secret end;tick()
assert(panelRows()[1].health.shown and panelRows()[1].health.value==secret,"color error cannot hide health")
UnitHealthPercent=function() error("normalized API unavailable") end
UnitHealth=function() return 60 end;UnitHealthMax=function() return 100 end;tick()
assert(panelRows()[1].health.shown and panelRows()[1].health.value==60,"health/max fallback after percent error")
print("PASS: curve failures preserve valid bars and failed percent API falls back to health/max.")

UnitDetailedThreatSituation=function(source,u)
 if source=="party1" then return false,0,80,80 end
 if source=="player" then return true,3,100,255 end
end
units.party1={};units.nameplate21={combat=true,status=3};tick()
assert(panelRows()[1].threatColor[1]==0.8 and panelRows()[1].threatColor[2]==0.2,"Tiny Threat tank rival formula")
units.party1=nil
UnitDetailedThreatSituation=function() return false,0,25,25 end
units.nameplate21.status=0;tick()
assert(panelRows()[1].threatColor[1]==1 and panelRows()[1].threatColor[2]==127/255,"Details quantized percentage ramp")
print("PASS: Tiny Threat tank-rival color formula and Details 8-bit ramp with selected pulse preserved.")

target="nameplate21";event("PLAYER_TARGET_CHANGED");tick()
assert(panelRows()[1].fillColor[3]==1 and panelRows()[1].fillColor[2]==0.35,"selected fill stays blue independent of threat")
assert(panelRows()[1].chevrons[1].shown and panelRows()[1].selectionBorder[1].shown)
assert(panelRows()[1].health.shown and panelRows()[1].healthCross[1].shown)
assert(panelRows()[1].rangeMark.text~=nil)
print("PASS: selected blue pulse excludes gradient while health/cross/range/arrows/outline remain.")

local nativeColors=0
UnitHealthPercent=function(_,_,curve)
 if curve then return {GetRGB=function() nativeColors=nativeColors+1;return 0.1,0.9,0.08 end} end
 return secret
end
for _,row in ipairs(panelRows()) do row.healthCurve={EvaluateUnpacked=function() error("generic evaluator rejects restricted input") end} end
tick();assert(nativeColors>0 and panelRows()[1].health.fillColor[2]==0.9,"native health-percent curve colors restricted health")
print("PASS: native UnitHealthPercent curve sets health color even when generic evaluation fails.")
-- Artistic texture styles, palette editing, picker cancellation and saved settings.
local appearance=plates.nameplate21.ThreatArrowsOverlay
units.nameplate21={combat=true,status=3};tick()
assert(appearance.art.texturePath:match('Media\\ArrowStyles.tga$'))
for _,style in ipairs({'Forged','Arcane','Sentinel','Wisp'}) do
    _G['ThreatArrowsStyle'..style].scripts.OnClick()
    assert(ThreatArrowsDB.arrowStyle==style and appearance.style==style,'style applied immediately')
end
local beforeWidth=ThreatArrowsDB.panelWidth
local field=ThreatArrowsColorsecure
field:SetText('#3388FF');field.scripts.OnEnterPressed(field)
assert(ThreatArrowsDB.customColors and math.abs(appearance.tint[3]-1)<0.001)
assert(math.abs(appearance.tint[1]-0.2)<0.001,'secure custom color')
field:SetText('bad');field.scripts.OnEnterPressed(field)
assert(math.abs(ThreatArrowsDB.colors.secure[1]-0.2)<0.001,'invalid edit preserved')
for _,pair in ipairs({{2,'losing'},{0,'lost'}}) do
    local f=_G['ThreatArrowsColor'..pair[2]];f:SetText('8844CC');f.scripts.OnEnterPressed(f)
    units.nameplate21={combat=true,status=pair[1],raw={secret=true}};tick()
    assert(math.abs(appearance.tint[3]-0.8)<0.001,'restricted percentage keeps custom state color')
    assert(math.abs(appearance.halo.color[3]-0.8)<0.001,'warning uses palette')
end
local unknown=ThreatArrowsColorunknown;unknown:SetText('445566');unknown.scripts.OnEnterPressed(unknown)
units.nameplate21={combat=true};tick();assert(math.abs(appearance.tint[3]-0.4)<0.001,'unknown palette')
local wheel=ThreatArrowsColorWheelSurface
wheel.GetEffectiveScale=function() return 2 end
GetCursorPosition=function() return 236,0 end
ThreatArrowsSwatchsecure.scripts.OnClick()
assert(ThreatArrowsColorWheel.shown,'swatch opens circular picker')
wheel.scripts.OnMouseDown(wheel,'LeftButton');wheel.scripts.OnMouseUp(wheel)
assert(ThreatArrowsDB.colors.secure[1]==1 and ThreatArrowsDB.colors.secure[2]==0,'red edge selection')
ThreatArrowsColorCancel.scripts.OnClick()
assert(math.abs(ThreatArrowsDB.colors.secure[1]-0.2)<0.001,'cancel restores prior color')
ThreatArrowsColorMode.scripts.OnClick();assert(not ThreatArrowsDB.customColors)
ThreatArrowsResetAppearance.scripts.OnClick()
assert(ThreatArrowsDB.arrowStyle=='Sentinel' and not ThreatArrowsDB.customColors)
assert(ThreatArrowsDB.panelWidth==beforeWidth,'appearance reset preserves layout')
ThreatArrowsDB.arrowStyle='corrupt';ThreatArrowsDB.colors={secure={-1,'bad',4}};tick()
assert(ThreatArrowsDB.arrowStyle=='Sentinel' and ThreatArrowsDB.colors.secure[1]==0 and ThreatArrowsDB.colors.secure[2]==1 and ThreatArrowsDB.colors.secure[3]==1)
print('PASS: all four textured styles, custom state/unknown colors, restricted values, warning palette, invalid hex, circular picker and cancel, gradient toggle, safe appearance reset, saved-setting validation.')
-- Minimap launcher opens settings, toggles the meter, and remembers drag position.
local launcher=ThreatArrowsMinimapButton
assert(launcher and launcher.parent==Minimap and launcher.shown,'minimap launcher exists')
local opened=0
local oldSettings=Settings
Settings.OpenToCategory=function(id) assert(id==123);opened=opened+1 end
launcher.scripts.OnClick(launcher,'LeftButton');assert(opened==1,'left-click opens settings')
local legacyOpened=false
Settings=nil
InterfaceOptionsFrame_OpenToCategory=function(frame) assert(frame==ThreatArrowsOptionsPanel);legacyOpened=true end
launcher.scripts.OnClick(launcher,'LeftButton');assert(legacyOpened,'legacy settings launcher')
Settings=oldSettings;InterfaceOptionsFrame_OpenToCategory=nil
ThreatArrowsDB.panelHidden=false
launcher.scripts.OnClick(launcher,'RightButton');tick();assert(ThreatArrowsDB.panelHidden and not panel.shown)
launcher.scripts.OnClick(launcher,'RightButton');tick();assert(not ThreatArrowsDB.panelHidden and panel.shown)
Minimap.GetEffectiveScale=function() return 2 end
GetCursorPosition=function() return 200,0 end
launcher.scripts.OnDragStart(launcher);assert(launcher.scripts.OnUpdate)
launcher.scripts.OnUpdate(launcher)
assert(ThreatArrowsDB.minimapAngle==0 and math.abs(launcher.point[4]-78)<0.001,'drag uses minimap scale')
launcher.scripts.OnDragStop(launcher);assert(not launcher.scripts.OnUpdate,'drag handler stops')
event('PLAYER_LOGIN');assert(ThreatArrowsDB.minimapAngle==0,'login preserves icon position')
ThreatArrowsDB.minimapAngle='invalid';event('PLAYER_LOGIN');assert(ThreatArrowsDB.minimapAngle==225)
for _,style in ipairs({'Forged','Arcane','Sentinel','Wisp'}) do
    assert(_G['ThreatArrowsStyle'..style].preview.percentageText==nil,'preview has no percentage text')
end
assert(appearance.percentageText==nil,'overhead arrows have no percentage text')
print('PASS: text-free arrows/previews, minimap left/right clicks, modern/legacy options, scale-aware drag, persistent position and invalid-position recovery.')

-- Six hue sectors, saturation, brightness, release, and transaction behavior.
local picker=ThreatArrowsColorWheel
local colorWheel=ThreatArrowsColorWheelSurface
local brightness=ThreatArrowsColorBrightness
local originalSecure=ThreatArrowsDB.colors.secure
ThreatArrowsDB.colors.secure={1,1,1};ThreatArrowsDB.customColors=false
ThreatArrowsSwatchsecure.scripts.OnClick()
assert(not ThreatArrowsDB.customColors,'opening alone preserves gradient mode')
local cursorX,cursorY=0,0
GetCursorPosition=function() return cursorX*2,cursorY*2 end
for i,expected in ipairs({{1,0,0},{1,1,0},{0,1,0},{0,1,1},{0,0,1},{1,0,1}}) do
    local angle=(i-1)*math.pi/3
    cursorX=117.999*math.cos(angle);cursorY=117.999*math.sin(angle)
    colorWheel.scripts.OnMouseDown(colorWheel,'LeftButton')
    colorWheel.scripts.OnMouseUp(colorWheel)
    local c=ThreatArrowsDB.colors.secure
    for j=1,3 do assert(math.abs(c[j]-expected[j])<0.0001,'HSV hue sector') end
end
cursorX=0;cursorY=0;colorWheel.scripts.OnMouseDown(colorWheel,'LeftButton');colorWheel.scripts.OnMouseUp(colorWheel)
assert(ThreatArrowsDB.colors.secure[1]==1 and ThreatArrowsDB.colors.secure[2]==1,'center is white')
brightness.scripts.OnValueChanged(brightness,25)
assert(ThreatArrowsDB.colors.secure[1]==0.25 and ThreatArrowsDB.colors.secure[3]==0.25,'brightness controls value')
ThreatArrowsColorCancel.scripts.OnClick()
assert(not ThreatArrowsDB.customColors and ThreatArrowsDB.colors.secure[1]==1,'cancel restores mode and color')
ThreatArrowsSwatchsecure.scripts.OnClick()
cursorX=200;cursorY=200;colorWheel.scripts.OnMouseDown(colorWheel,'LeftButton')
assert(not ThreatArrowsDB.customColors,'outside circle ignored')
cursorX=118;cursorY=0;colorWheel.scripts.OnMouseDown(colorWheel,'LeftButton')
cursorX=0;cursorY=200;picker.scripts.OnUpdate(picker)
assert(ThreatArrowsDB.colors.secure[3]==0,'drag beyond wheel clamps to rim')
IsMouseButtonDown=function() return false end
picker.scripts.OnUpdate(picker)
local afterRelease=ThreatArrowsDB.colors.secure
cursorX=-118;cursorY=0;picker.scripts.OnUpdate(picker)
assert(ThreatArrowsDB.colors.secure==afterRelease,'release outside wheel stops drag')
ThreatArrowsColorDone.scripts.OnClick()
assert(ThreatArrowsDB.colors.secure==afterRelease and not picker.shown,'Done commits live color')
ThreatArrowsSwatchsecure.scripts.OnClick();brightness.scripts.OnValueChanged(brightness,0)
ThreatArrowsSwatchlost.scripts.OnClick()
for j=1,3 do assert(ThreatArrowsDB.colors.secure[j]==afterRelease[j],'switching states cancels unfinished edit') end
picker:Hide()
ThreatArrowsDB.colors.secure={0.31,0.53,0.79}
ThreatArrowsSwatchsecure.scripts.OnClick()
brightness.scripts.OnValueChanged(brightness,79)
for j,n in ipairs({0.31,0.53,0.79}) do assert(math.abs(ThreatArrowsDB.colors.secure[j]-n)<0.000001,'RGB HSV roundtrip') end
picker:Hide()
print('PASS: circular hue sectors, center saturation, scale-correct pointer, brightness, outside bounds, drag release, live colors, commit/cancel, state switching and RGB/HSV roundtrip.')
-- Configurable distance threshold uses validated client distance and honest unknowns.
local rangeSlider=ThreatArrowsMaxTauntDistance
assert(ThreatArrowsDB.maxTauntDistance==10,'default distance is ten yards')
local oldSpells=C_Spell
C_Spell=nil;IsSpellInRange=nil
local measured,valid=100,true
UnitDistanceSquared=function() return measured,valid end
units.nameplate21={combat=true,status=3};units.nameplate22={combat=true,status=3}
tick();assert(panelRows()[1].inTauntRange==true,'ten-yard boundary included')
measured=100.01;tick();assert(panelRows()[1].inTauntRange==false and panelRows()[1].state.text=='OUT OF RANGE')
rangeSlider.scripts.OnValueChanged(rangeSlider,15)
assert(ThreatArrowsDB.maxTauntDistance==15 and panelRows()[1].inTauntRange==true,'distance control applies immediately')
measured=225;tick();assert(panelRows()[1].inTauntRange==true)
measured=226;tick();assert(panelRows()[1].inTauntRange==false)
for _,bad in ipairs({-1,math.huge,secret,'invalid'}) do measured=bad;tick();assert(panelRows()[1].inTauntRange==nil,'invalid distance is unknown') end
measured=4;valid=false;tick();assert(panelRows()[1].inTauntRange==nil,'unvalidated distance rejected')
valid=secret;tick();assert(panelRows()[1].inTauntRange==nil,'restricted validation rejected')
UnitDistanceSquared=function() error('distance unavailable') end
C_Spell={GetSpellInfo=function() return {minRange=0,maxRange=10} end,IsSpellInRange=function() return true end}
tick();assert(panelRows()[1].inTauntRange==true,'shorter spell proves inside larger threshold')
C_Spell.IsSpellInRange=function() return false end;tick();assert(panelRows()[1].inTauntRange==nil,'shorter spell cannot prove outside larger threshold')
C_Spell.GetSpellInfo=function() return {minRange=0,maxRange=30} end
tick();assert(panelRows()[1].inTauntRange==false,'outside longer spell proves outside threshold')
C_Spell.IsSpellInRange=function() return true end;tick();assert(panelRows()[1].inTauntRange==nil,'longer spell cannot prove inside threshold')
C_Spell.GetSpellInfo=function() return {minRange=0,maxRange=secret} end;tick();assert(panelRows()[1].inTauntRange==nil)
rangeSlider.scripts.OnValueChanged(rangeSlider,99);assert(ThreatArrowsDB.maxTauntDistance==40)
rangeSlider.scripts.OnValueChanged(rangeSlider,-4);assert(ThreatArrowsDB.maxTauntDistance==1)
ThreatArrowsDB.maxTauntDistance='bad';tick();assert(ThreatArrowsDB.maxTauntDistance==10)
rangeSlider.scripts.OnValueChanged(rangeSlider,22);event('PLAYER_LOGIN');assert(ThreatArrowsDB.maxTauntDistance==22,'login preserves distance')
ThreatArrowsOptionsPanel.OnDefault();assert(ThreatArrowsDB.maxTauntDistance==10,'defaults restore ten yards')
UnitDistanceSquared=nil;C_Spell=oldSpells
print('PASS: 10-yard default, editable distance, inclusive threshold, instant warning update, persistence, bounds, reset, invalid/restricted/native failures and conservative spell bounds.')
C_Spell=nil;UnitDistanceSquared=nil
GetSpellInfo=function() return 'Judgement',nil,1,0,0,10,20271 end
IsSpellInRange=function() return true end
tick();assert(panelRows()[1].inTauntRange==true,'legacy spell info range slots')
IsSpellInRange=function() return false end
tick();assert(panelRows()[1].inTauntRange==false,'legacy spell info outside')
GetSpellInfo=nil;IsSpellInRange=nil
print('PASS: legacy spell metadata uses actual min/max ranges, not spell ID.')
