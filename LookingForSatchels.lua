local expLeg = select(4, GetBuildInfo()) >= 70000
--[[ LookingForSatchels ]]

--TODOs:
-- localization
-- minimap button
-- tooltip
-- watch list: separate roles per dungeon
-- one-click-queue: use separate roles per dungeon to queue for, not blizzard's roles
-- LDB
-- movable popup
-- (a) add all dungeons (b) add all dungeons that give valor points (c) remove all dungeons
-- hide popup when joining a group

local DefaultO = {
  ["framePoint"] = "CENTER";
  ["frameRelativeTo"] = "UIParent";
  ["frameRelativePoint"] = "CENTER";
  ["frameOffsetX"] = 0;
  ["frameOffsetY"] = 0;
  ["framePointPopup"] = "CENTER";
  ["frameRelativeToPopup"] = "UIParent";
  ["frameRelativePointPopup"] = "CENTER";
  ["frameOffsetXPopup"] = 0;
  ["frameOffsetYPopup"] = 0;
  ["showPopup"] = true;
  ["showFrame"] = 1;
  ["playSound"] = 1;
  ["soundName"] = "LOOTWINDOWCOINSOUND";
  ["scanActive"] = 1;
  ["LFG_dungeonIDs"] = {
    --[[
    [123] = {
      ["status"] = 1; --on watch list
      ["lfgCategory"] = "LFD";
    };
    [234] = {
      ["status"] = 2; --on watch list and satchel found
      ["lfgCategory"] = "Scenario";
    };
    --]]
  };
  ["LFG_roles"] = {1, 1, 1}; --Tank, Heal, Damage
  ["first"] = false;
}
local O

local frame = CreateFrame("Frame", "LookingForSatchelsFrame", UIParent)
local popupFrame = CreateFrame("Frame", "LookingForSatchelsPopupFrame", UIParent)
local frameEvents = {};
local moving = false
local POPUP_MINWIDTH = 166



local function initFrame()
  frame:SetPoint(O["framePoint"], O["frameRelativeTo"], O["frameRelativePoint"], O["frameOffsetX"], O["frameOffsetY"])
  frame:SetFrameStrata("LOW")
  frame:SetSize(50, 12)
  
  frame.bgtexture = frame:CreateTexture(nil, "OVERLAY")
  frame.bgtexture:SetAllPoints(frame)
  if expLeg then
    frame.bgtexture:SetColorTexture(0, 0, 0, 1)
  else
    frame.bgtexture:SetTexture(0, 0, 0, 1)
  end
  frame.bgtexture:Hide()
  
  frame:SetScript("OnDragStart", function(self) self:StartMoving(); end);
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint()
    O["framePoint"] = point or "LEFT"
    O["frameRelativeTo"] = relativeTo or "UIParent"
    O["frameRelativePoint"] = relativePoint or "CENTER"
    O["frameOffsetX"] = xOfs
    O["frameOffsetY"] = yOfs
  end);
  
  frame.joinLFG_popupQueue = {};
  frame.joinLFG_popupQueue_showNext_afterCombat = false
  frame.joinLFG_popupQueue_showNext_afterGroupDisband = false
  frame.joinLFG_popupQueue_push = function(dungeonID, lfgCategory)
    for _, v in ipairs(frame.joinLFG_popupQueue) do
      if v["dungeonID"] == dungeonID then
        return
      end
    end
    table.insert(frame.joinLFG_popupQueue, {
      ["dungeonID"] = dungeonID;
      ["lfgCategory"] = lfgCategory;
    })
  end
  frame.joinLFG_popupQueue_pop = function()
    --dequeue this popup
    table.remove(frame.joinLFG_popupQueue, 1)
    popupFrame:Hide()
    frame.joinLFG_lastDungeonID = 0
    frame.joinLFG_lastLfgCategory = ""
  end
  frame.joinLFG_popupQueue_showNext = function()
    if InCombatLockdown() then
      frame.joinLFG_popupQueue_showNext_afterCombat = true
    elseif IsInGroup() then
      frame.joinLFG_popupQueue_showNext_afterGroupDisband = true
    else
      --queue next popup (if any)
      if #frame.joinLFG_popupQueue > 0 then
        local dungeonID = frame.joinLFG_popupQueue[1]["dungeonID"]
        local v = frame.LFG_dungeonIDs[dungeonID]
        if v and v["status"] and v["status"] == 2 then --still on watch list, and bonus active
          frame.joinLFG_lastDungeonID = dungeonID
          frame.joinLFG_lastLfgCategory = frame.joinLFG_popupQueue[1]["lfgCategory"]
          local name = GetLFGDungeonInfo(dungeonID)
          popupFrame:showDialog("Queue for:\124n"..name)
        else
          frame.joinLFG_popupQueue_pop()
          frame.joinLFG_popupQueue_showNext()
        end
      end
    end
  end
  
  frame.joinLFG_lastDungeonID = 0--789
  frame.joinLFG_lastLfgCategory = ""--"LFD"
  frame.joinLFG = function(dungeonID, lfgCategory, removeFromWatchlist)
    if lfgCategory == "LFD" then
      LFG_JoinDungeon(LE_LFG_CATEGORY_LFD, dungeonID, LFDDungeonList, LFDHiddenByCollapseList)
      --[[
      ClearAllLFGDungeons(LE_LFG_CATEGORY_LFD)
      SetLFGDungeon(LE_LFG_CATEGORY_LFD, dungeonID)
      JoinLFG(LE_LFG_CATEGORY_LFD)
      --]]
    elseif lfgCategory == "Scenario" then
      LFG_JoinDungeon(LE_LFG_CATEGORY_SCENARIO, dungeonID, ScenariosList, ScenariosHiddenByCollapseList)
    elseif lfgCategory == "RaidFinder" then
      ClearAllLFGDungeons(LE_LFG_CATEGORY_RF)
      SetLFGDungeon(LE_LFG_CATEGORY_RF, dungeonID)
      --JoinLFG(LE_LFG_CATEGORY_RF)
      JoinSingleLFG(LE_LFG_CATEGORY_RF, dungeonID)
    end
    
    if removeFromWatchlist then
      frame.removeLFGId(dungeonID)
    end
    
    frame.joinLFG_popupQueue_pop()
    frame.joinLFG_popupQueue_showNext()
  end
  frame.dequeueJoinLFG = function(dungeonID, lfgCategory, removeFromWatchlist)
    if removeFromWatchlist then
      frame.removeLFGId(dungeonID)
    end
    
    frame.joinLFG_popupQueue_pop()
    frame.joinLFG_popupQueue_showNext()
  end
  
  frame.toggleScan = function()
    O.scanActive = O.scanActive == 1 and 0 or 1
    print("|cffaaaaffLookingForSatchels |rscan |cffaaaaffis "..(O.scanActive == 1 and "|cffaaffaaactive" or "|cffff8888paused"))
    frame.updateDisplay()
  end
  
  frame.toggleFrame = function(b)
    frame:SetAlpha(b)
    frame:EnableMouse(b==1)
    O.showFrame = b
  end
  
  --[ [
  frame:EnableMouse(true)
  frame:SetScript("OnMouseUp", function(self, button)
    self:handleMouseUp(0, button)
  end)
  frame.handleMouseUp = function(self, barIndex, button)
    if button == "LeftButton" and IsShiftKeyDown() then
      frame.toggleScan()
    elseif button == "RightButton" then
      print("|cffaaaaffLookingForSatchels: Rescan...")
      for k, v in pairs(self.LFG_dungeonIDs) do
        if v["status"] == 2 then
          v["status"] = 1
        end
      end
      RequestLFDPlayerLockInfo()
    end
  end
  --] ]
  
  --------------------
  --LFG satchel grabber
  --------------------
  frame.watchListNotEmpty = false
  frame.LFGtslU = 0
  frame.LFGInterval = 10
  frame.LFGsearchLastScanFoundReward = false
  frame.LFG_roles = O.LFG_roles
  frame.LFG_dungeonIDs = O.LFG_dungeonIDs
  
  frame.addLFGId = function(dungeonID, lfgCategory)
    if (type(dungeonID) ~= "number") or LFGIsIDHeader(dungeonID) then
      return
    end
    
    frame.LFG_dungeonIDs[dungeonID] = {
      ["status"] = 1;
      ["lfgCategory"] = lfgCategory;
    };
    
    --LFDQueueFrame.type
    --LFRQueueFrame.selectedLFM
    frame.watchListNotEmpty = true
    frame.LFGtslU = frame.LFGInterval
    local name = GetLFGDungeonInfo(dungeonID)
    print(format("|cffaaaaffLookingForSatchels: added to watch list: %s", name))
    O.LFG_dungeonIDs = frame.LFG_dungeonIDs
    
    frame.updateDisplay()
  end
  frame.removeLFGId = function(dungeonID)
    if (type(dungeonID) ~= "number") or LFGIsIDHeader(dungeonID) then
      return
    end
    
    frame.LFG_dungeonIDs[dungeonID] = nil
    local active = false
    for k, v in pairs(frame.LFG_dungeonIDs) do
      if v and v["status"] and v["status"] >= 1 then
        active = true
        break
      end
    end
    frame.watchListNotEmpty = active
    frame.LFGtslU = frame.LFGInterval
    local name = GetLFGDungeonInfo(dungeonID)
    print(format("|cffaaaaffLookingForSatchels: removed LFG search for: %s", name))
    O.LFG_dungeonIDs = frame.LFG_dungeonIDs
    
    frame.updateDisplay()
    
    --update L+ buttons
    for i, b in ipairs(frame.frameLFGSearchButtons) do
      b:updateStatus()
    end
  end
  
  frame.frameLFGSearchButtons = {
    CreateFrame("Button", nil, LFDQueueFrameTypeDropDown),
    CreateFrame("Button", nil, ScenarioQueueFrameTypeDropDown),
    CreateFrame("Button", nil, RaidFinderQueueFrameSelectionDropDown),
  };
  local additionalButtonInfo = {
    "LFD",
    "Scenario",
    "RaidFinder",
  };
  for i, b in ipairs(frame.frameLFGSearchButtons) do
    b:SetPoint("RIGHT", _G[(b:GetParent():GetName()).."Name"], "RIGHT", -60, 0)
    b:SetFrameStrata("DIALOG")
    b:SetWidth(30)
    b:SetHeight(22)
    b.frameRef = frame
    
    b.dungeonID = 0
    b.status = 0
    
    b.updateStatus = function(self)
      local v = self.frameRef.LFG_dungeonIDs[self.dungeonID]
      local i
      if not v then
        i = 0
      else
        i = v["status"]
      end
      self.status = i
      self:updateText()
    end
    b.updateText = function(self)
      if self.status == 0 then
        b:SetText("L+")
      else
        b:SetText("L-")
      end
    end
    b:updateText()
    
    b.lfgCategory = additionalButtonInfo[i]
    
    b:SetScript("OnClick", function(self, arg1)
      if IsShiftKeyDown() then --add all to watch list
        if self.lfgCategory == "RaidFinder" then
          for i = 1, GetNumRFDungeons() do
            local id = GetRFDungeonInfo(i)
            local isAvailable = IsLFGDungeonJoinable(id)
            if isAvailable then
              self.frameRef.addLFGId(id, self.lfgCategory)
              self.status = 1
            end
          end
          self:updateText()
        end
      elseif IsControlKeyDown() then --remove all from watch list
        if self.lfgCategory == "RaidFinder" then
          local foundRaidFinder
          repeat
            foundRaidFinder = false
            for k, v in pairs(frame.LFG_dungeonIDs) do
              if v and v["status"] and v["status"] >= 1 and v["lfgCategory"] == "RaidFinder" then
                foundRaidFinder = true
                self.frameRef.removeLFGId(k)
                self.status = 0
                break
              end
            end
          until foundRaidFinder == false
          self:updateText()
        end
      else
        if self.status == 0 then
          self.frameRef.addLFGId((self:GetParent()).selectedValue, self.lfgCategory)
          self.status = 1
        else
          self.frameRef.removeLFGId((self:GetParent()).selectedValue)
          self.status = 0
        end
        self:updateText()
      end
    end);
    
    b:SetNormalFontObject("GameFontNormal")
    
    local ntex = b:CreateTexture()
    ntex:SetTexture("Interface/Buttons/UI-Panel-Button-Up")
    ntex:SetTexCoord(0, 0.625, 0, 0.6875)
    ntex:SetAllPoints()	
    b:SetNormalTexture(ntex)

    local htex = b:CreateTexture()
    htex:SetTexture("Interface/Buttons/UI-Panel-Button-Highlight")
    htex:SetTexCoord(0, 0.625, 0, 0.6875)
    htex:SetAllPoints()
    b:SetHighlightTexture(htex)

    local ptex = b:CreateTexture()
    ptex:SetTexture("Interface/Buttons/UI-Panel-Button-Down")
    ptex:SetTexCoord(0, 0.625, 0, 0.6875)
    ptex:SetAllPoints()
    b:SetPushedTexture(ptex)
  end
  
  --[ [
  frame.hook_LFGRewardsFrame_UpdateFrame = function(parentFrame, dungeonID, background)
    if (type(dungeonID) == "number") and not LFGIsIDHeader(dungeonID) then
      local v = frame.LFG_dungeonIDs[dungeonID]
      local i
      if not v then
        i = 0
      else
        i = v["status"]
      end
      for i2, b in ipairs(frame.frameLFGSearchButtons) do
        b.dungeonID = dungeonID
        b.status = i
        b:updateText()
      end
    end
  end
  hooksecurefunc("LFGRewardsFrame_UpdateFrame", frame.hook_LFGRewardsFrame_UpdateFrame)
  --] ]
  
  --------------------
  --frame text
  --------------------
  frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.text:SetPoint("RIGHT")
  frame.text:SetText("L")
  frame.text:SetTextColor(1, 1, 1, 1)
  
  frame.OnUpdate = function(self, elapsed)
    self.LFGtslU = self.LFGtslU + elapsed
    if self.watchListNotEmpty and O.scanActive == 1 and (self.LFGtslU >= self.LFGInterval) then
      self.LFGtslU = 0
      RequestLFDPlayerLockInfo()
    end
  end
  frame:SetScript("OnUpdate", function(self, elapsed)
    self.OnUpdate(self, elapsed)
  end);
  
  frame.updateDisplay = function()
    local t
    if O.scanActive == 1 then
      if frame.watchListNotEmpty then
        if frame.LFGsearchLastScanFoundReward then
          t = "|cff00ff00F|r" --scanning, found satchel
        else
          t = "|cffffff00L|r" --scanning
        end
      else
        t = "|cffff0000L|r" --watch list empty
      end
    else
      t = "|cffaaaaaaL|r" --scan paused
    end
    frame.text:SetText(t)
  end
  
  --------------------
  --popup frame
  --------------------
  
  --popupFrame:SetPoint("CENTER", UIParent, "CENTER")
  popupFrame:SetPoint(O.framePointPopup, O.frameRelativeToPopup, O.frameRelativePointPopup, O.frameOffsetXPopup, O.frameOffsetYPopup)
  popupFrame:SetFrameStrata("DIALOG")
  popupFrame:SetSize(POPUP_MINWIDTH, 70+22)
  popupFrame:EnableMouse(true)
  
  popupFrame:SetScript("OnDragStart", function(self) self:StartMoving(); end);
  popupFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint()
    O.framePointPopup = point or DefaultO.framePointPopup
    O.frameRelativeToPopup = relativeTo or DefaultO.frameRelativeToPopup
    O.frameRelativePointPopup = relativePoint or DefaultO.frameRelativePointPopup
    O.frameOffsetXPopup = xOfs or DefaultO.frameOffsetXPopup
    O.frameOffsetYPopup = yOfs or DefaultO.frameOffsetYPopup
  end);
  popupFrame:SetMovable(true)
  popupFrame:RegisterForDrag("LeftButton")

  popupFrame.bgtexture = popupFrame:CreateTexture(nil, "BACKGROUND")
  popupFrame.bgtexture:SetAllPoints(popupFrame)
  if expLeg then
    popupFrame.bgtexture:SetColorTexture(0, 0, 0, 0.8)
  else
    popupFrame.bgtexture:SetTexture(0, 0, 0, 0.8)
  end
  popupFrame.bgtexture:Show()

  popupFrame.text = popupFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  popupFrame.text:SetPoint("TOP", 0, -4)
  popupFrame.text:SetText("Queue?")
  popupFrame.text:SetTextColor(1, 1, 1, 1)
  
  popupFrame.bottomText = popupFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  popupFrame.bottomText:SetPoint("BOTTOM", 0, 2)
  popupFrame.bottomText:SetText("Shift+Click to remove from watchlist")
  popupFrame.bottomText:SetTextColor(0.7, 0.7, 0.7, 1)
  
  POPUP_MINWIDTH = max(POPUP_MINWIDTH, popupFrame.bottomText:GetStringWidth()+2)
  popupFrame:SetSize(POPUP_MINWIDTH, 70+22)  
  popupFrame:Hide()
  
  local newButton = function(parent, posSelf, posRelativeTo, posRelative, ox, oy, w, h, text)
    local retButton = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
    retButton:SetPoint(posSelf, posRelativeTo, posRelative, ox, oy)
    retButton:SetFrameStrata("DIALOG")
    retButton:SetWidth(w)
    retButton:SetHeight(h)
    
    retButton:SetText(text)
    retButton:SetNormalFontObject("GameFontNormal")
    
    local ntex = retButton:CreateTexture()
    ntex:SetTexture("Interface/Buttons/UI-Panel-Button-Up")
    ntex:SetTexCoord(0, 0.625, 0, 0.6875)
    ntex:SetAllPoints()	
    retButton:SetNormalTexture(ntex)
    
    local htex = retButton:CreateTexture()
    htex:SetTexture("Interface/Buttons/UI-Panel-Button-Highlight")
    htex:SetTexCoord(0, 0.625, 0, 0.6875)
    htex:SetAllPoints()
    retButton:SetHighlightTexture(htex)
    
    local ptex = retButton:CreateTexture()
    ptex:SetTexture("Interface/Buttons/UI-Panel-Button-Down")
    ptex:SetTexCoord(0, 0.625, 0, 0.6875)
    ptex:SetAllPoints()
    retButton:SetPushedTexture(ptex)

    retButton:Show()
    
    return retButton
  end
  
  popupFrame.buttonsYES = newButton(popupFrame, "TOPRIGHT", popupFrame, "TOPLEFT", POPUP_MINWIDTH/2-1, -22*2, 80, 22, "Yes")
  popupFrame.buttonsNO = newButton(popupFrame, "TOPLEFT", popupFrame, "TOPLEFT", POPUP_MINWIDTH/2+1, -22*2, 80, 22, "No")
  
  popupFrame.buttonsYES:SetAttribute("type", "macro")
  popupFrame.buttonsYES:SetAttribute("macrotext", [[/run LookingForSatchelsFrame.joinLFG(LookingForSatchelsFrame.joinLFG_lastDungeonID, LookingForSatchelsFrame.joinLFG_lastLfgCategory, IsShiftKeyDown())]])
  
  popupFrame.buttonsNO:SetAttribute("type", "macro")
  popupFrame.buttonsNO:SetAttribute("macrotext", [[/run LookingForSatchelsFrame.dequeueJoinLFG(LookingForSatchelsFrame.joinLFG_lastDungeonID, LookingForSatchelsFrame.joinLFG_lastLfgCategory, IsShiftKeyDown())]])
  
  popupFrame.showDialog = function(self, text)
    self.text:SetText(text)
    local newWidth = max(POPUP_MINWIDTH, self.text:GetStringWidth()+4*2)
    self:SetWidth(newWidth)
    self.buttonsYES:SetPoint("TOPRIGHT", self, "TOPLEFT", newWidth/2-1, -22*2)
    self.buttonsNO:SetPoint("TOPLEFT", self, "TOPLEFT", newWidth/2+1, -22*2)
    if O.showPopup then
      self:Show()
    end
  end
end


function frameEvents:PLAYER_ENTERING_WORLD(...)
  frame:UnregisterEvent("PLAYER_ENTERING_WORLD")
  
  --------------------
  -- get all options/upgrade option table
  --------------------
  if not LookingForSatchelsOptions then
    LookingForSatchelsOptions = DefaultO
  end
  O = LookingForSatchelsOptions
  
  if not O.addonVersion then
    --update from pre 0.3, revert to default LFG_dungeonIDs settings
    O.LFG_dungeonIDs = {}; --frame.LFG_dungeonIDs
    --add popup option
    O.showPopup = true
    print("|cffaaaaffNew version of LookingForSatchels. Watch list has been reset.")
  end
  O.addonVersion = GetAddOnMetadata("LookingForSatchels", "Version")
  
  O.playSound = O.playSound or DefaultO.playSound
  O.soundName = O.soundName or DefaultO.soundName
  
  O.scanActive = O.scanActive or DefaultO.scanActive
  O.showFrame = O.showFrame or DefaultO.showFrame
  
  O.LFG_roles = O.roles or DefaultO.LFG_roles
  O.LFG_dungeonIDs = O.LFG_dungeonIDs or DefaultO.LFG_dungeonIDs
  
  if O.first == nil then O.first = DefaultO.first end
  
  O.framePointPopup = O.framePointPopup or DefaultO.framePointPopup
  O.frameRelativeToPopup = O.frameRelativeToPopup or DefaultO.frameRelativeToPopup
  O.frameRelativePointPopup = O.frameRelativePointPopup or DefaultO.frameRelativePointPopup
  O.frameOffsetXPopup = O.frameOffsetXPopup or DefaultO.frameOffsetXPopup
  O.frameOffsetYPopup = O.frameOffsetYPopup or DefaultO.frameOffsetYPopup
  
  --------------------
  -- init frame and frame's functions
  --------------------
  initFrame()
  
  --TODO: move to initFrame()
  local active = false
  for k, v in pairs(frame.LFG_dungeonIDs) do
    if v and v["status"] and v["status"] >= 1 then
      active = true
      if v["status"] == 2 then
        v["status"] = 1 --show this popup again at login
      end
    end
  end
  frame.watchListNotEmpty = active
  
  frame.updateDisplay()
  
  frame.toggleFrame(O.showFrame)
  
  frame:RegisterEvent("LFG_UPDATE_RANDOM_INFO")
  frame:RegisterEvent("PLAYER_REGEN_DISABLED")
  frame:RegisterEvent("PLAYER_REGEN_ENABLED")
  frame:RegisterEvent("GROUP_ROSTER_UPDATE")
end

function frameEvents:LFG_UPDATE_RANDOM_INFO()
  if frame.watchListNotEmpty and O.scanActive == 1 then
    local foundReward = false
    for k, v in pairs(frame.LFG_dungeonIDs) do
      if v and v["status"] and v["status"] >= 1 then
        local foundRewardForK = false
        local doneonce = GetLFGDungeonRewards(k)
        for i = 1, LFG_ROLE_NUM_SHORTAGE_TYPES do
          local eligible, forTank, forHealer, forDamage, itemCount, money, xp = GetLFGRoleShortageRewards(k, i)
          if eligible
                and (forTank and frame.LFG_roles[1]==1 or forHealer and frame.LFG_roles[2]==1 or forDamage and frame.LFG_roles[3]==1) and (itemCount ~= 0 or money ~= 0 or xp ~= 0)
                and (not O.first or not doneonce)
                then
            foundReward = true
            foundRewardForK = true
            
            if v["status"] == 1 then
              v["status"] = 2
              
              local name = GetLFGDungeonInfo(k)
              print("|cffaaaaffLFG reward for: "..name)
              local warningColor = {
                ["r"] = 0.67;
                ["g"] = 0.67;
                ["b"] = 1;
              };
              RaidNotice_AddMessage(RaidWarningFrame, "LFG reward for: "..name, warningColor, 10)
              
              frame.joinLFG_popupQueue_push(k, v["lfgCategory"])
              frame.joinLFG_popupQueue_showNext()
            end
            
            if not frame.LFGsearchLastScanFoundReward then
              FlashClientIcon()
              if O.playSound then
                PlaySound(O.soundName, "master")
              end
              frame.LFGsearchLastScanFoundReward = true
            end
          end
        end
        if not foundRewardForK then
          v["status"] = 1
          --if popup asks to queue for this dungeon but the bonus expired, hide popup
          if frame.joinLFG_lastDungeonID == k then
            local name = GetLFGDungeonInfo(k)
            print("|cffaaaaffLFG reward for:", name, "expired")
            frame.joinLFG_popupQueue_pop()
            frame.joinLFG_popupQueue_showNext()
          end
        end
      end
    end
    
    if frame.LFGsearchLastScanFoundReward and (not foundReward) then
      frame.LFGsearchLastScanFoundReward = false
    end
    
    frame.updateDisplay()
  end
end
function frameEvents:PLAYER_REGEN_DISABLED()
  if popupFrame:IsShown() then
    --can't hide in combat
    frame.joinLFG_popupQueue_showNext_afterCombat = true
    popupFrame:Hide()
    print("do it later!")
  end
end
function frameEvents:PLAYER_REGEN_ENABLED()
  if frame.joinLFG_popupQueue_showNext_afterCombat then
    frame.joinLFG_popupQueue_showNext_afterCombat = false
    frame.joinLFG_popupQueue_showNext()
  end
end
function frameEvents:GROUP_ROSTER_UPDATE()
  if frame.joinLFG_popupQueue_showNext_afterGroupDisband then
    if not IsInGroup() then
      frame.joinLFG_popupQueue_showNext_afterGroupDisband = false
      frame.joinLFG_popupQueue_showNext()
    end
  else
    if IsInGroup() and popupFrame:IsShown() then
      --can't solo queue while in a group
      frame.joinLFG_popupQueue_showNext_afterGroupDisband = true
      popupFrame:Hide()
    end
  end
end

frame:SetScript("OnEvent", function(self, event, ...)
  frameEvents[event](self, ...)
end);
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

--split string containing quoted and non quoted arguments
--input pattern: (\S+|".+")?(\s+(\S+|".+"))*
--example input: [[arg1 "arg2part1 arg2part2" arg3]]
--example output: {"arg1", "arg2part1 arg2part2", "arg3"}
local function mysplit2(inputstr)
  local i, i1, i2, l, ret, retI = 1, 0, 0, inputstr:len(), {}, 1
  --remove leading spaces
  i1, i2 = inputstr:find("^%s+")
  if i1 then
    i = i2 + 1
  end
  
  while i <= l do
    --find end of current arg
    if (inputstr:sub(i, i)) == "\"" then
      --quoted arg, find end quote
      i1, i2 = inputstr:find("\"%s+", i + 1)
      if i1 then
        --spaces after end quote, more args to follow
        ret[retI] = inputstr:sub(i + 1, i1 - 1)
        retI = retI + 1
        i = i2 + 1
      else
        i1, i2 = inputstr:find("\"$", i + 1)
        if i1 then
          --end of msg
          ret[retI] = inputstr:sub(i + 1, i1 - 1)
          return ret
        else
          -- no end quote found, or end quote followed by no-space-charater found, disregard last arg
          return ret
        end
      end
    else
      --not quoted arg, find next space (if any)
      i1, i2 = inputstr:find("%s+", i + 1)
      if i1 then
        --spaces after arg, more args to follow
        ret[retI] = inputstr:sub(i, i1 - 1)
        retI = retI + 1
        i = i2 + 1
      else
        --end of msg
        ret[retI] = inputstr:sub(i)
        return ret
      end
    end
  end
  
  return ret
end

SLASH_LOOKINGFORSATCHELS1 = "/lfs"
SlashCmdList["LOOKINGFORSATCHELS"] = function(msg, editbox)
  args = mysplit2(msg or "")
  
  if string.lower(args[1] or "") == "move" then
    if moving then
      moving = false
      frame:SetMovable(false)
      frame:RegisterForDrag("")
      frame.bgtexture:Hide()
    else
      moving = true
      frame:SetMovable(true)
      frame:RegisterForDrag("LeftButton")
      frame.bgtexture:Show()
    end
    print("|cffaaaaffLookingForSatchels |rmove |cffaaaaffis now "..(moving == true and "|cffaaffaamoving" or "|cffff8888fixed"))
  elseif string.lower(args[1] or "") == "hide" then
    frame.toggleFrame(0)
    print("|cffaaaaffLookingForSatchels |rindicator hidden")
  elseif string.lower(args[1] or "") == "show" then
    frame.toggleFrame(1)
    print("|cffaaaaffLookingForSatchels |rindicator shown")
  elseif string.lower(args[1] or "") == "reset" then
    LookingForSatchels["framePoint"] = DefaultO["framePoint"]
    LookingForSatchels["frameRelativeTo"] = DefaultO["frameRelativeTo"]
    LookingForSatchels["frameRelativePoint"] = DefaultO["frameRelativePoint"]
    LookingForSatchels["frameOffsetX"] = DefaultO["frameOffsetX"]
    LookingForSatchels["frameOffsetY"] = DefaultO["frameOffsetY"]
    
    frame:ClearAllPoints()
    frame:SetPoint(LookingForSatchels["framePoint"], LookingForSatchels["frameRelativeTo"], LookingForSatchels["frameRelativePoint"], LookingForSatchels["frameOffsetX"], LookingForSatchels["frameOffsetY"])
    
    print("|cffaaaaffLookingForSatchels |rposition reset")
  elseif string.lower(args[1] or "") == "resetpopup" then
    O.framePointPopup = DefaultO.framePointPopup
    O.frameRelativeToPopup = DefaultO.frameRelativeToPopup
    O.frameRelativePointPopup = DefaultO.frameRelativePointPopup
    O.frameOffsetXPopup = DefaultO.frameOffsetXPopup
    O.frameOffsetYPopup = DefaultO.frameOffsetYPopup
    
    popupFrame:ClearAllPoints()
    popupFrame:SetPoint(O.framePointPopup, O.frameRelativeToPopup, O.frameRelativePointPopup, O.frameOffsetXPopup, O.frameOffsetY)
    
    print("|cffaaaaffLookingForSatchels |rpopup position reset")
  elseif string.lower(args[1] or "") == "roles" then
    if args[2] and args[3] and args[4] then
      frame.LFG_roles[1] = tonumber(args[2])
      frame.LFG_roles[2] = tonumber(args[3])
      frame.LFG_roles[3] = tonumber(args[4])
      O.roles = frame.LFG_roles
    end
    print("|cffaaaaffLookingForSatchels |rroles |cffaaaaffare: "..(frame.LFG_roles[1]==1 and "|cffaaffaa" or "|cffff8888").."Tank "..(frame.LFG_roles[2]==1 and "|cffaaffaa" or "|cffff8888").."Heal "..(frame.LFG_roles[3]==1 and "|cffaaffaa" or "|cffff8888").."Damage")
  elseif string.lower(args[1] or "") == "first" then
    O.first = not O.first
    print("|cffaaaaffLookingForSatchels |rfirst is now |cffaaaaff("..(O.first and "|cffaaffaarequired" or "|cffff8888ignored").."|cffaaaaff)")
  elseif string.lower(args[1] or "") == "popup" then
    if O.showPopup then
      O.showPopup = false
    else
      O.showPopup = true
    end
    print("|cffaaaaffLookingForSatchels |rpopup |cffaaaaff("..(O.showPopup and "|cffaaffaashown" or "|cffff8888hidden").."|cffaaaaff)")
  elseif string.lower(args[1] or "") == "playsound" then
    O.playSound = O.playSound == 1 and 0 or 1
    print("|cffaaaaffLookingForSatchels |rplaysound |cffaaaaffis "..(O.playSound == 1 and "|cffaaffaaenabled" or "|cffff8888disabled"))
  elseif string.lower(args[1] or "") == "sound" then
    if args[2] then
      O.soundName = args[2]
      print("|cffaaaaffLookingForSatchels |rsound |cffaaaaffchanged to: |r"..args[2])
    else
      print("|cffaaaaffLookingForSatchels |rsound |cffaaaaffis: |r"..O.soundName)
    end
    PlaySound(O.soundName, "master")
  elseif string.lower(args[1] or "") == "togglescan" then
    frame.toggleScan()
  else
    print("|cffaaaaffLookingForSatchels |r"..(GetAddOnMetadata("LookingForSatchels", "Version") or "").." |cffaaaaff(use |r/lfs <option> |cffaaaafffor these options)")
    print("  move |cffaaaafftoggle moving the frame ("..(moving == true and "|cffaaffaamoving" or "|cffff8888fixed").."|cffaaaaff)")
    print("  reset |cffaaaaffreset the frame's position")
    print("  show/hide |cffaaaaffshow/hide the indicator ("..(O.showFrame == 1 and "|cffaaffaashown" or "|cffff8888hidden").."|cffaaaaff)")
    print("  roles <n> <n> <n> |cffaaaaffchange search for roles (<n> = 1 or 0) ("..(frame.LFG_roles[1]==1 and "|cffaaffaa" or "|cffff8888").."Tank "..(frame.LFG_roles[2]==1 and "|cffaaffaa" or "|cffff8888").."Heal "..(frame.LFG_roles[3]==1 and "|cffaaffaa" or "|cffff8888").."Damage|cffaaaaff)")
    print("  first |cffaaaafftoggle whether require first-run (valor) reward ("..(O.first and "|cffaaffaarequired" or "|cffff8888ignored").."|cffaaaaff)")
    print("  popup |cffaaaafftoggle showing a popup to queue for a dungeon ("..(O.showPopup and "|cffaaffaashown" or "|cffff8888hidden").."|cffaaaaff)")
    print("  playsound |cffaaaafftoggle playing a sound when a satchel is found ("..(O.playSound == 1 and "|cffaaffaaenabled" or "|cffff8888disabled").."|cffaaaaff)")
    print("  sound [soundName] |cffaaaaffchange or display/listen to sound")
    print("  togglescan |cffaaaaffpause/resume scanning ("..(O.scanActive == 1 and "|cffaaffaaactive" or "|cffff8888paused").."|cffaaaaff)")
  end
end
