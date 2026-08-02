--[[
  ArenaCombatLog — minimap button + GUI for TBC Arena Logs.

  By default, combat logging turns ON only inside arenas and OFF everywhere
  else (Shattrath, world, etc.). Manual Start/Stop still force the logger
  until the next zone change re-syncs auto mode.

  Left-click icon  = open/close GUI
  Right-click icon = force toggle logging (temporary until next zone)
]]

local PREFIX = "|cff66bbffArena Combat Log|r"

local LOG_DIR = [[World of Warcraft\_anniversary_\Logs\]]
local LOG_FILE = "WoWCombatLog.txt"
local LOG_GLOB = "WoWCombatLog*.txt"
local ICON_TEX = "Interface\\Icons\\INV_Misc_Book_09"

local db
local panel
local miniBtn
local refreshAll
local SyncArenaLogging  -- fwd

local function EnsureDB()
  ArenaCombatLogDB = ArenaCombatLogDB or {}
  db = ArenaCombatLogDB
  if db.minimapAngle == nil then
    db.minimapAngle = 220
  end
  if db.minimapHide == nil then
    db.minimapHide = false
  end
  -- Default: only write combat log while inside an arena.
  if db.arenaOnly == nil then
    db.arenaOnly = true
  end
end

local function InArena()
  local _, instanceType = IsInInstance()
  if instanceType == "arena" then
    return true
  end
  if type(IsActiveBattlefieldArena) == "function" and IsActiveBattlefieldArena() then
    return true
  end
  return false
end

local function IsLogging()
  if type(LoggingCombat) ~= "function" then
    return nil
  end
  return LoggingCombat() and true or false
end

local function SetLogging(on, quiet)
  if type(LoggingCombat) ~= "function" then
    if not quiet then
      print(PREFIX .. ": LoggingCombat() is not available on this client.")
    end
    return false
  end
  local want = on and true or false
  local cur = IsLogging()
  if cur == want then
    if refreshAll then refreshAll() end
    return cur
  end
  LoggingCombat(want)
  if refreshAll then
    refreshAll()
  end
  if not quiet then
    local state = IsLogging() and "|cff88ff88ON|r" or "|cffff8888OFF|r"
    local where = InArena() and " (arena)" or " (out of arena)"
    print(PREFIX .. ": combat logging " .. state .. where)
  end
  return IsLogging()
end

local function ToggleLogging()
  return SetLogging(not IsLogging())
end

-- Keep LoggingCombat() aligned with arena presence when arena-only mode is on.
SyncArenaLogging = function(quiet)
  if not db or not db.arenaOnly then
    return
  end
  SetLogging(InArena(), quiet ~= false)
end

-- =====================================================================
-- Main GUI
-- =====================================================================
local function EnsurePanel()
  if panel then
    return panel
  end

  local f = CreateFrame("Frame", "ArenaCombatLogPanel", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  f:SetSize(420, 320)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetFrameStrata("DIALOG")
  f:SetClampedToScreen(true)
  if f.SetBackdrop then
    f:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      edgeSize = 1,
    })
    f:SetBackdropColor(0.06, 0.07, 0.09, 0.96)
    f:SetBackdropBorderColor(0, 0, 0, 1)
  end

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -14)
  title:SetText("Arena Combat Log")

  local subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  subtitle:SetTextColor(0.65, 0.7, 0.78)
  subtitle:SetText("Auto-logs arenas only — off in the world / city.")

  local closeX = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  closeX:SetPoint("TOPRIGHT", 2, 2)
  closeX:SetScript("OnClick", function()
    f:Hide()
  end)

  -- Big status pill
  local statusBg = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
  statusBg:SetSize(388, 44)
  statusBg:SetPoint("TOPLEFT", 16, -56)
  if statusBg.SetBackdrop then
    statusBg:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      edgeSize = 1,
    })
    statusBg:SetBackdropBorderColor(0, 0, 0, 1)
  end
  f.statusBg = statusBg

  local statusText = statusBg:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  statusText:SetPoint("CENTER")
  f.statusText = statusText

  -- Arena-only checkbox
  local autoCheck = CreateFrame("CheckButton", "ArenaCombatLogAutoCheck", f, "UICheckButtonTemplate")
  autoCheck:SetPoint("TOPLEFT", statusBg, "BOTTOMLEFT", -4, -10)
  autoCheck:SetSize(24, 24)
  local autoLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  autoLabel:SetPoint("LEFT", autoCheck, "RIGHT", 4, 0)
  autoLabel:SetText("Only log arenas (auto on/off)")
  autoCheck:SetScript("OnClick", function(self)
    db.arenaOnly = self:GetChecked() and true or false
    if db.arenaOnly then
      SyncArenaLogging(false)
      print(PREFIX .. ": arena-only mode |cff88ff88ON|r")
    else
      print(PREFIX .. ": arena-only mode |cffff8888OFF|r — use Start/Stop manually")
    end
    refreshAll()
  end)
  f.autoCheck = autoCheck

  -- Path box
  local pathLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  pathLabel:SetPoint("TOPLEFT", autoCheck, "BOTTOMLEFT", 4, -12)
  pathLabel:SetText("Where WoW saves the log")

  local pathBox = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
  pathBox:SetSize(388, 72)
  pathBox:SetPoint("TOPLEFT", pathLabel, "BOTTOMLEFT", 0, -6)
  if pathBox.SetBackdrop then
    pathBox:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      edgeSize = 1,
    })
    pathBox:SetBackdropColor(0.02, 0.02, 0.03, 0.95)
    pathBox:SetBackdropBorderColor(0.15, 0.15, 0.18, 1)
  end

  local pathText = pathBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  pathText:SetPoint("TOPLEFT", 10, -10)
  pathText:SetPoint("BOTTOMRIGHT", -10, 10)
  pathText:SetJustifyH("LEFT")
  pathText:SetJustifyV("TOP")
  pathText:SetText(
    "Folder:\n  " .. LOG_DIR .. "\n" ..
    "File:\n  " .. LOG_FILE .. "  (or " .. LOG_GLOB .. ")"
  )

  local note = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  note:SetPoint("TOPLEFT", pathBox, "BOTTOMLEFT", 0, -10)
  note:SetPoint("TOPRIGHT", pathBox, "BOTTOMRIGHT", 0, -10)
  note:SetJustifyH("LEFT")
  note:SetJustifyV("TOP")
  note:SetWordWrap(true)
  note:SetText("With arena-only on, Start/Stop is a temporary override until you change zones. TBC Arena Logs still splits each fight.")

  local startBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  startBtn:SetSize(150, 28)
  startBtn:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -16)
  startBtn:SetText("Start logging")
  startBtn:SetScript("OnClick", function()
    SetLogging(true)
  end)
  f.startBtn = startBtn

  local stopBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  stopBtn:SetSize(150, 28)
  stopBtn:SetPoint("LEFT", startBtn, "RIGHT", 10, 0)
  stopBtn:SetText("Stop logging")
  stopBtn:SetScript("OnClick", function()
    SetLogging(false)
  end)
  f.stopBtn = stopBtn

  local printBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  printBtn:SetSize(78, 28)
  printBtn:SetPoint("TOPRIGHT", note, "BOTTOMRIGHT", 0, -16)
  printBtn:SetText("Chat info")
  printBtn:SetScript("OnClick", function()
    local on = IsLogging()
    print(PREFIX .. ": " .. (on and "|cff88ff88ON|r" or "|cffff8888OFF|r")
      .. (db.arenaOnly and " | arena-only" or " | manual")
      .. (InArena() and " | in arena" or ""))
    print("  " .. LOG_DIR .. LOG_FILE)
  end)

  function f:Refresh()
    if self.autoCheck then
      self.autoCheck:SetChecked(db.arenaOnly and true or false)
    end
    local on = IsLogging()
    if on then
      local label = db.arenaOnly and "|cff88ff88LOGGING ON|r  (arena)" or "|cff88ff88LOGGING ON|r"
      self.statusText:SetText(label)
      if self.statusBg.SetBackdropColor then
        self.statusBg:SetBackdropColor(0.08, 0.28, 0.12, 0.95)
      end
      self.startBtn:Disable()
      self.stopBtn:Enable()
    elseif on == false then
      local label = db.arenaOnly and "|cffff8888LOGGING OFF|r  (waiting for arena)" or "|cffff8888LOGGING OFF|r"
      self.statusText:SetText(label)
      if self.statusBg.SetBackdropColor then
        self.statusBg:SetBackdropColor(0.28, 0.08, 0.08, 0.95)
      end
      self.startBtn:Enable()
      self.stopBtn:Disable()
    else
      self.statusText:SetText("|cffffaa00UNAVAILABLE|r")
      if self.statusBg.SetBackdropColor then
        self.statusBg:SetBackdropColor(0.25, 0.2, 0.05, 0.95)
      end
      self.startBtn:Disable()
      self.stopBtn:Disable()
    end
  end

  f:Hide()
  panel = f
  return f
end

local function ShowPanel(show)
  local f = EnsurePanel()
  f:Refresh()
  if show == false then
    f:Hide()
  elseif show == true then
    f:Show()
  else
    f:SetShown(not f:IsShown())
  end
end

-- =====================================================================
-- Minimap button (no libraries)
-- =====================================================================
local function UpdateMinimapPosition()
  if not miniBtn or not db then
    return
  end
  local angle = math.rad(db.minimapAngle or 220)
  local x = math.cos(angle) * 80
  local y = math.sin(angle) * 80
  miniBtn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function UpdateMinimapLook()
  if not miniBtn then
    return
  end
  local on = IsLogging()
  if on then
    miniBtn.icon:SetVertexColor(0.45, 1, 0.55)
  else
    miniBtn.icon:SetVertexColor(1, 0.45, 0.45)
  end
end

local function EnsureMinimapButton()
  if miniBtn then
    return miniBtn
  end

  local btn = CreateFrame("Button", "ArenaCombatLogMinimapButton", Minimap)
  btn:SetSize(32, 32)
  btn:SetFrameStrata("MEDIUM")
  btn:SetFrameLevel(8)
  btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  btn:RegisterForDrag("LeftButton")

  local overlay = btn:CreateTexture(nil, "OVERLAY")
  overlay:SetSize(53, 53)
  overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  overlay:SetPoint("TOPLEFT")

  local bg = btn:CreateTexture(nil, "BACKGROUND")
  bg:SetSize(20, 20)
  bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  bg:SetPoint("TOPLEFT", 6, -6)

  local icon = btn:CreateTexture(nil, "ARTWORK")
  icon:SetSize(18, 18)
  icon:SetTexture(ICON_TEX)
  icon:SetPoint("TOPLEFT", 7, -7)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  btn.icon = icon

  btn:SetScript("OnClick", function(_, button)
    if button == "RightButton" then
      ToggleLogging()
    else
      ShowPanel()
    end
  end)

  btn:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = GetCursorPosition()
      local cx, cy = Minimap:GetCenter()
      local scale = Minimap:GetEffectiveScale()
      db.minimapAngle = math.deg(math.atan2(my / scale - cy, mx / scale - cx))
      UpdateMinimapPosition()
    end)
  end)

  btn:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
  end)

  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Arena Combat Log", 0.4, 0.75, 1)
    local on = IsLogging()
    if on then
      GameTooltip:AddLine("Status: |cff88ff88LOGGING ON|r", 1, 1, 1)
    else
      GameTooltip:AddLine("Status: |cffff8888LOGGING OFF|r", 1, 1, 1)
    end
    if db.arenaOnly then
      GameTooltip:AddLine("Mode: arena-only (auto)", 0.7, 0.85, 1)
    else
      GameTooltip:AddLine("Mode: manual", 1, 0.85, 0.5)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cffaaaaaaLeft-click:|r open panel", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("|cffaaaaaaRight-click:|r force start/stop", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("|cffaaaaaaDrag:|r move button", 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)

  btn:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  miniBtn = btn
  UpdateMinimapPosition()
  UpdateMinimapLook()
  if db.minimapHide then
    btn:Hide()
  else
    btn:Show()
  end
  return btn
end

refreshAll = function()
  if panel then
    panel:Refresh()
  end
  UpdateMinimapLook()
end

-- =====================================================================
-- Slash (optional power-user; GUI is primary)
-- =====================================================================
SLASH_ARENACOMBATLOG1 = "/clog"
SLASH_ARENACOMBATLOG2 = "/arenalog"
SlashCmdList["ARENACOMBATLOG"] = function(msg)
  msg = strtrim(string.lower(msg or ""))
  if msg == "on" or msg == "start" then
    SetLogging(true)
    ShowPanel(true)
  elseif msg == "off" or msg == "stop" then
    SetLogging(false)
    ShowPanel(true)
  elseif msg == "auto" or msg == "arena" then
    db.arenaOnly = true
    SyncArenaLogging(false)
    print(PREFIX .. ": arena-only mode |cff88ff88ON|r")
    refreshAll()
  elseif msg == "manual" then
    db.arenaOnly = false
    print(PREFIX .. ": arena-only mode |cffff8888OFF|r — use Start/Stop")
    refreshAll()
  elseif msg == "minimap" then
    db.minimapHide = not db.minimapHide
    if miniBtn then
      miniBtn:SetShown(not db.minimapHide)
    end
    print(PREFIX .. ": minimap button " .. (db.minimapHide and "hidden" or "shown"))
  else
    ShowPanel()
  end
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:RegisterEvent("PLAYER_ENTERING_WORLD")
boot:RegisterEvent("ZONE_CHANGED_NEW_AREA")
boot:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    EnsureDB()
    EnsureMinimapButton()
    EnsurePanel()
    -- If someone left logging on from an old session, shut it off outside arena.
    SyncArenaLogging(true)
    refreshAll()
    print(PREFIX .. " ready — |cffffffffarena-only|r auto-log (minimap book icon).")
  else
    -- Entering / leaving instances (including arenas).
    SyncArenaLogging(false)
  end
end)
