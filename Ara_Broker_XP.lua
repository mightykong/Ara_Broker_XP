if( UnitLevel"player" == MAX_PLAYER_LEVEL_TABLE[GetAccountExpansionLevel()] )then return end

local addonName = ...
local f = CreateFrame("Frame", "AraXP")
local tonumber, floor, XP, restedXP, maxXP, frame = tonumber, floor
local lenChar, bar

local config, configMenu, options, info, SetOption
local ColorPickerChange, ColorPickerCancel, OpenColorPicker, HTML2RGB, curCol

local defaultConfig = {
	pattern =	"||",
	length =	30,
	colorXP =	"6060ff",
	colorRested =	"ff8040",
	colorRemaining ="cccccc",
	sep =		GetLocale() == "enUS" and "," or " "
}

local block = LibStub("LibDataBroker-1.1"):NewDataObject("|cFFFFB366Ara|r XP", {
	type = "data source",
	icon = "Interface\\Icons\\Achievement_Halloween_Cat_01",
	text = "-",
	OnLeave = function() frame = nil return GameTooltip:Hide() end,
	OnClick = function(self, button)
		if not configMenu then f:InitConfigMenu() end
		GameTooltip:Hide()
		ToggleDropDownMenu(1, nil, configMenu, self, 0, 0)
	end
})

local function UpdateText()
	XP, restedXP, maxXP = UnitXP("player"), GetXPExhaustion() or 0, UnitXPMax("player")
    -- DEFAULT_CHAT_FRAME:AddMessage(format("%d/%d/%d,%d",XP,restedXP,maxXP,config.length))
    -- This is a hack put in to get around an error when loading where XP doesn't seem to available
    -- at loading.  Prevents division by zero error.  Not sure if this is just a BfA or not.
    if maxXP == 0 or maxXP == nil then maxXP = 1 end
    
	local lenXP = floor( XP/maxXP *config.length +.5 )
	local lenRested = floor( min( XP+restedXP, maxXP ) / maxXP * config.length - lenXP + .5 )
	block.text =
		"|cff"..config.colorXP	..bar:sub( 1, lenXP*lenChar )..
		"|r|cff"..config.colorRested    ..bar:sub( 1, lenRested*lenChar )..
		"|r|cff"..config.colorRemaining ..bar:sub( 1, (config.length-lenXP-lenRested) * lenChar ).."|r"
end

function f:InitConfigMenu()
	configMenu = CreateFrame("Frame", "AraXPConfigMenu")
	configMenu.displayMode = "MENU"
	info = {}
	options = {
	{ text = ("|cffffb366Ara|r XP (%s)"):format( GetAddOnMetadata(addonName, "Version") ), isTitle = true },
	{ text = "Pattern...", func = function() StaticPopup_Show"SET_ABXP_PATTERN" end },
	{ text = "Length...", func = function() StaticPopup_Show"SET_ABXP_LENGTH" end },
	{ text = "Colors", submenu = {
		{ text = "XP", color = "colorXP" },
		{ text = "Rested XP", color = "colorRested" },
		{ text = "Remaining XP", color = "colorRemaining" },}},
	{ text = "Thousand separator", submenu = {
		{ text = "Comma [,]",	radio = "sep", val = "," },
		{ text = "Space [ ]",	radio = "sep", val = " " },
		{ text = "None",	radio = "sep", val = "" },}},
	}
	HTML2RGB = function(html)
		info.r = tonumber( html:sub(1,2), 16 ) / 255
		info.g = tonumber( html:sub(3,4), 16 ) / 255
		info.b = tonumber( html:sub(5,6), 16 ) / 255
	end
	ColorPickerChange = function()
		local r, g, b = ColorPickerFrame:GetColorRGB()
		config[curCol] = ("%.2x%.2x%.2x"):format(r*255, g*255, b*255)
		UpdateText()
	end
	ColorPickerCancel = function(prev) config[curCol]=prev UpdateText() end
	OpenColorPicker = function(self, col)
		curCol = col
		local cc = config[col]
		HTML2RGB(cc)
		ColorPickerFrame.func = ColorPickerChange
		ColorPickerFrame.cancelFunc = ColorPickerCancel
		ColorPickerFrame.previousValues = cc
		ColorPickerFrame:SetColorRGB( info.r, info.g, info.b )
		ColorPickerFrame:Show()
	end

	SetOption = function(bt, var, val, checked)
		config[var] = val or checked -- or not config[var]
		if var:sub(1,5) == "color" then UpdateText() end
		if not val then return end

		local sub = bt:GetName():sub(1, 19)
		for i = 1, bt:GetParent().numButtons do
			if _G[sub..i] == bt then _G[sub..i.."Check"]:Show() else _G[sub..i.."Check"]:Hide() _G[sub..i.."UnCheck"]:Show() end
		end
	end

	f.SetLength = function(dialog)
		local length = tonumber( dialog.editBox:GetText():match"(%d+)" )
		if not length or length<4 or length>200 then
			baseScript = BasicScriptErrors:GetScript"OnHide"
			BasicScriptErrors:SetScript("OnHide",Error_OnHide)
			BasicScriptErrorsText:SetText"Invalid length.\nShould be between 4 and 200"
			return BasicScriptErrors:Show()
		end
		config.length = length
		bar = config.pattern:rep(length)
		UpdateText()
	end

	f.SetPattern = function(dialog)
		local pattern = dialog.editBox:GetText()
		config.pattern = pattern
		lenChar, bar = #pattern, pattern:rep(config.length)
		UpdateText()
	end

	local dialogLength = {
		text = "Set XP bar length.\n(Number of pattern repetitions).",
		maxLetters = 3,
		OnAccept = f.SetLength,
		OnShow = function(self) CloseDropDownMenus() self.editBox:SetText(config.length) self.editBox:SetFocus() end,
		EditBoxOnEnterPressed = function(self) local p=self:GetParent() StaticPopupDialogs.SET_ABXP_LENGTH.OnAccept(p) p:Hide() end,
	}
	local dialogPattern = {
		text = "Set XP bar pattern to repeat.",
		maxLetters = 5,
		OnAccept = AraXP.SetPattern,
		OnShow = function(self) CloseDropDownMenus() self.editBox:SetText(config.pattern) self.editBox:SetFocus() end,
		EditBoxOnEnterPressed = function(self) local p=self:GetParent() StaticPopupDialogs.SET_ABXP_PATTERN.OnAccept(p) p:Hide() end,
	}

	for k, v in next, StaticPopupDialogs.ADD_IGNORE do --ADD_MUTE
		if not dialogLength[k]	then dialogLength[k] = v end
		if not dialogPattern[k]	then dialogPattern[k] = v end
	end
	StaticPopupDialogs.SET_ABXP_LENGTH = dialogLength
	StaticPopupDialogs.SET_ABXP_PATTERN = dialogPattern

	configMenu.initialize = function(self, level)
		if not level then return end
		for i, v in ipairs( level > 1 and UIDROPDOWNMENU_MENU_VALUE or options ) do
			info = wipe(info)
			info.text = v.text
			info.isTitle, info.hasArrow, info.value = v.isTitle, v.submenu ~= nil, v.submenu
			if v.func then
				info.func = v.func
			elseif v.radio then
				info.checked = config[v.radio] == v.val
				info.func, info.arg1, info.arg2 = SetOption, v.radio, v.val
				info.keepShownOnClick = true
			elseif v.color then
				info.hasColorSwatch, info.notCheckable, info.padding = true, true, 10
				HTML2RGB(config[v.color])
				info.func, info.arg1 = OpenColorPicker, v.color
			end
			if level == 1 or v.color then info.notCheckable = true end
			UIDropDownMenu_AddButton(info, level)
		end
	end
	f.InitConfigMenu = nil
end

local function FormatXP( value )
	local p = floor( value/maxXP*1e3 +.5 ) * .1
	return	value >= 1e6 and ("%i%s%.3i%s%.3i  [%.2i.%.0f%%]|r"):format( floor(value*1e-6), config.sep, floor((value%1e6)*1e-3), config.sep, value%1e3, p, p*10%10 )
		or value >= 1e3 and ("%i%s%.3i  [%.2i.%.0f%%]|r"):format( floor(value*1e-3), config.sep, value%1e3, p, p*10%10 )
		or ("%i  [%.2i.%.0f%%]|r"):format( value, p, p*10%10 )
end

block.OnEnter = function(self)
	CloseDropDownMenus()
	frame = self
	local showBelow = select( 2, self:GetCenter() ) > UIParent:GetHeight() / 2
	GameTooltip:SetOwner( self, "ANCHOR_NONE" )
	GameTooltip:SetPoint( showBelow and "TOP" or "BOTTOM", self, showBelow and "BOTTOM" or "TOP" )
	local nbBubbles =  floor( (maxXP-XP) / maxXP*20 +.5 )
	GameTooltip:AddDoubleLine( ("Lv. %i"):format(UnitLevel"player"), ("%i \1244bubble:bubbles; left"):format(nbBubbles) )
	GameTooltip:AddDoubleLine( "|cff"..config.colorXP.."XP|r", "|cff"..config.colorXP..FormatXP(XP) )
	GameTooltip:AddDoubleLine( "|cff"..config.colorRested.."Rested|r", "|cff"..config.colorRested..FormatXP(restedXP) )
	GameTooltip:AddDoubleLine( "|cff"..config.colorRemaining.."Remaining|r", "|cff"..config.colorRemaining..FormatXP(maxXP-XP) )
	return GameTooltip:Show()
end

local function Init()
	AraBrokerXPDB = AraBrokerXPDB or defaultConfig
	config = AraBrokerXPDB
	for k, v in next, defaultConfig do -- add new settings
		if config[k] == nil then config[k] = v end
	end
--	for k, v in next, config do -- remove settings no longer in use
--		if defaultConfig[k] == nil then config[k] = nil end
--	end
	lenChar, bar = #config.pattern, config.pattern:rep(config.length)
	f:RegisterEvent"PLAYER_XP_UPDATE"
	f:RegisterEvent"UPDATE_EXHAUSTION"
	return IsLoggedIn() or f:RegisterEvent"PLAYER_LOGIN"
end

f:SetScript("OnEvent", function(self, event, unit)
	if unit and unit ~= "player" and unit ~= addonName then return end
	if event == "ADDON_LOADED" and not Init() then return end
	UpdateText()
	if frame then return block.OnEnter(frame) end
end)

f:RegisterEvent"ADDON_LOADED"