-- XanaReagents: adds the professions and products of a crafting reagent to its
-- item tooltip, and a key opens a window listing all its uses. The data in
-- Data.lua is generated from the game's own tables by tools/build_reagent_data.py.

local _, ns = ...

BINDING_HEADER_XANAREAGENTS = "XanaReagents"
BINDING_NAME_XANAREAGENTS_SHOW = "Show all uses of the reagent in the tooltip"

local BINDING = "XANAREAGENTS_SHOW"
local MAX_LISTED = 5
local QUESTION_MARK = "Interface\\Icons\\INV_Misc_QuestionMark"
local CURRENT_REAGENT_COLOR = "|cffffd100"

local ItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local SpellTexture = (C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture

local hookMethod = "none"
local tooltipReagents = {} -- [tooltip] = the reagent it is showing right now

local function IsSecret(value)
	return issecretvalue and issecretvalue(value)
end

local function QualityColor(quality)
	local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
	if color then return color.r, color.g, color.b end
	return 1, 1, 1
end

local function BoundKey()
	local key = GetBindingKey and GetBindingKey(BINDING)
	if not key then return nil end
	return GetBindingText and GetBindingText(key) or key
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------
local function AddReagentLines(tooltip, itemID)
	if not itemID or IsSecret(itemID) then return end
	local entry = ns.reagents[itemID]
	if not entry then return end
	tooltipReagents[tooltip] = itemID

	local names = {}
	for i, profession in ipairs(entry[1]) do
		names[i] = ns.professions[profession]
	end
	tooltip:AddLine(" ")
	tooltip:AddLine("Reagent for " .. table.concat(names, ", "), 1, 0.82, 0, true)

	local listed = entry[2]
	for i = 1, math.min(#listed, MAX_LISTED) do
		local recipe = ns.recipes[listed[i]]
		tooltip:AddLine("  " .. recipe[1], QualityColor(recipe[2]))
	end
	if #listed > MAX_LISTED then
		local key = BoundKey()
		local more = ("  ...and %d more"):format(#listed - MAX_LISTED)
		if key then more = ("%s (%s for full list)"):format(more, key) end
		tooltip:AddLine(more, 0.7, 0.7, 0.7)
	end
end

local function ShouldDecorate(tooltip)
	if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return false end
	return not (tooltip.IsForbidden and tooltip:IsForbidden())
end

local function OnTooltipData(tooltip, data)
	if ShouldDecorate(tooltip) and data then
		AddReagentLines(tooltip, data.id)
	end
end

local function OnTooltipSetItem(tooltip)
	if not ShouldDecorate(tooltip) then return end
	local _, link = tooltip:GetItem()
	if not link or IsSecret(link) then return end
	AddReagentLines(tooltip, tonumber(link:match("item:(%d+)")))
end

local function ForgetTooltip(tooltip)
	tooltipReagents[tooltip] = nil
end

local useDataProcessor = TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
	and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item
if useDataProcessor then
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnTooltipData)
	hookMethod = "TooltipDataProcessor"
end
for _, tooltip in ipairs({ GameTooltip, ItemRefTooltip }) do
	if not useDataProcessor and pcall(tooltip.HookScript, tooltip, "OnTooltipSetItem", OnTooltipSetItem) then
		hookMethod = "OnTooltipSetItem"
	end
	pcall(tooltip.HookScript, tooltip, "OnTooltipCleared", ForgetTooltip)
	pcall(tooltip.HookScript, tooltip, "OnHide", ForgetTooltip)
end

---------------------------------------------------------------------------
-- Window
--
-- One frame: rows are textures and font strings of the window, redrawn as the
-- list scrolls, and the row under the cursor is worked out from the layout.
---------------------------------------------------------------------------
local WIDTH = 560
local PADDING = 12
local HEADER_HEIGHT = 62
local ROW_STEP = 38
local VISIBLE_ROWS = 11
local HEIGHT = HEADER_HEIGHT + VISIBLE_ROWS * ROW_STEP + PADDING
local BAR_WIDTH = 6
local ROW_WIDTH = WIDTH - 2 * PADDING - BAR_WIDTH - 6
local ICON_SIZE = 28
local TEXT_LEFT = 40
local RIGHT_COLUMN = 110
local MIN_THUMB = 24
local WHEEL_STEP = 3
local TRACK_HEIGHT = VISIBLE_ROWS * ROW_STEP - 4

local window = CreateFrame("Frame", "XanaReagentsWindow", UIParent)
window:Hide()
window:SetSize(WIDTH, HEIGHT)
window:SetPoint("CENTER")
window:SetFrameStrata("DIALOG")
window:SetToplevel(true)
window:EnableMouse(true)
window:EnableMouseWheel(true)
window:SetMovable(true)
window:SetClampedToScreen(true)

local function Solid(layer, r, g, b, a)
	local texture = window:CreateTexture(nil, layer)
	texture:SetColorTexture(r, g, b, a)
	return texture
end

local background = Solid("BACKGROUND", 0.05, 0.05, 0.07, 0.97)
background:SetAllPoints()

local headerBand = Solid("BORDER", 0.13, 0.11, 0.07, 1)
headerBand:SetPoint("TOPLEFT")
headerBand:SetPoint("TOPRIGHT")
headerBand:SetHeight(HEADER_HEIGHT - 6)

local headerLine = Solid("ARTWORK", 0.8, 0.62, 0.2, 1)
headerLine:SetPoint("TOPLEFT", 0, -(HEADER_HEIGHT - 6))
headerLine:SetPoint("TOPRIGHT", 0, -(HEADER_HEIGHT - 6))
headerLine:SetHeight(1)

for _, edge in ipairs({
	{ "TOPLEFT", "TOPRIGHT", nil, 1 },
	{ "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1 },
	{ "TOPLEFT", "BOTTOMLEFT", 1, nil },
	{ "TOPRIGHT", "BOTTOMRIGHT", 1, nil },
}) do
	local line = Solid("OVERLAY", 0.32, 0.28, 0.18, 1)
	line:SetPoint(edge[1])
	line:SetPoint(edge[2])
	if edge[3] then line:SetWidth(edge[3]) end
	if edge[4] then line:SetHeight(edge[4]) end
end

local headerIcon = window:CreateTexture(nil, "ARTWORK")
headerIcon:SetSize(36, 36)
headerIcon:SetPoint("TOPLEFT", PADDING, -10)

local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", PADDING + 46, -11)
title:SetWidth(WIDTH - 2 * PADDING - 46 - 34)
title:SetJustifyH("LEFT")
title:SetWordWrap(false)

local subtitle = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
subtitle:SetPoint("TOPLEFT", PADDING + 46, -32)
subtitle:SetWidth(WIDTH - 2 * PADDING - 46 - 34)
subtitle:SetJustifyH("LEFT")
subtitle:SetWordWrap(false)
subtitle:SetTextColor(0.72, 0.72, 0.72)

local closeButton = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
closeButton:SetSize(26, 22)
closeButton:SetPoint("TOPRIGHT", -PADDING, -8)
closeButton:SetText("X")
closeButton:SetScript("OnClick", function() window:Hide() end)

local highlight = Solid("BORDER", 1, 0.85, 0.4, 0.13)
highlight:SetSize(ROW_WIDTH, ROW_STEP - 2)
highlight:Hide()

local track = Solid("ARTWORK", 1, 1, 1, 0.07)
track:SetSize(BAR_WIDTH, TRACK_HEIGHT)
track:SetPoint("TOPRIGHT", -PADDING, -(HEADER_HEIGHT + 2))

local thumb = Solid("OVERLAY", 0.8, 0.62, 0.2, 0.9)
thumb:SetWidth(BAR_WIDTH)

local function RowTop(index)
	return -(HEADER_HEIGHT + (index - 1) * ROW_STEP)
end

local function NewFont(template)
	local text = window:CreateFontString(nil, "OVERLAY", template)
	text:SetJustifyH("LEFT")
	text:SetWordWrap(false)
	return text
end

local rows = {}
for index = 1, VISIBLE_ROWS do
	local top = RowTop(index)
	local row = {}
	row.band = Solid("BORDER", 1, 1, 1, 1)
	row.band:SetPoint("TOPLEFT", PADDING, top)
	row.band:SetSize(ROW_WIDTH, ROW_STEP - 2)

	row.icon = window:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(ICON_SIZE, ICON_SIZE)
	row.icon:SetPoint("TOPLEFT", PADDING + 4, top - 4)

	row.name = NewFont("GameFontNormal")
	row.name:SetPoint("TOPLEFT", PADDING + TEXT_LEFT, top - 4)
	row.name:SetWidth(ROW_WIDTH - TEXT_LEFT - RIGHT_COLUMN)

	row.right = NewFont("GameFontHighlightSmall")
	row.right:SetPoint("TOPRIGHT", window, "TOPLEFT", PADDING + ROW_WIDTH - 6, top - 6)
	row.right:SetWidth(RIGHT_COLUMN - 8)
	row.right:SetJustifyH("RIGHT")
	row.right:SetTextColor(0.62, 0.62, 0.62)

	row.detail = NewFont("GameFontHighlightSmall")
	row.detail:SetPoint("TOPLEFT", PADDING + TEXT_LEFT, top - 21)
	row.detail:SetWidth(ROW_WIDTH - TEXT_LEFT - 8)
	row.detail:SetTextColor(0.68, 0.68, 0.68)

	row.section = NewFont("GameFontNormal")
	row.section:SetPoint("LEFT", window, "TOPLEFT", PADDING + 8, top - (ROW_STEP - 2) / 2)
	row.section:SetWidth(ROW_WIDTH - RIGHT_COLUMN)

	rows[index] = row
end

local reagentID      -- the reagent the window is showing
local entries = {}   -- flattened list: { section = id, count = n } or { recipe = record }
local offset = 0     -- entries scrolled past the top
local draggingBar
local hoveredEntry

local function MaxOffset()
	return math.max(0, #entries - VISIBLE_ROWS)
end

local function RecipeIcon(recipe)
	local icon
	if recipe[5] > 0 then
		icon = select(5, ItemInfoInstant(recipe[5]))
	elseif SpellTexture then
		icon = SpellTexture(recipe[6])
	end
	return icon or QUESTION_MARK
end

local function ReagentList(recipe)
	local parts = {}
	local reagents = recipe[7]
	for i = 1, #reagents, 2 do
		local info = ns.reagentInfo[reagents[i]]
		local text = ("%s x%d"):format(info and info[1] or ("Item " .. reagents[i]), reagents[i + 1])
		if reagents[i] == reagentID then
			text = CURRENT_REAGENT_COLOR .. text .. "|r"
		end
		parts[#parts + 1] = text
	end
	return table.concat(parts, ", ")
end

local function ShowRowParts(row, recipeShown, sectionShown)
	row.icon:SetShown(recipeShown)
	row.name:SetShown(recipeShown)
	row.detail:SetShown(recipeShown)
	row.right:SetShown(recipeShown or sectionShown)
	row.section:SetShown(sectionShown)
	row.band:SetShown(recipeShown or sectionShown)
end

local function DrawRow(row, index)
	local entry = entries[index]
	if not entry then
		ShowRowParts(row, false, false)
	elseif entry.section then
		ShowRowParts(row, false, true)
		row.band:SetColorTexture(0.24, 0.19, 0.08, 1)
		row.section:SetText(ns.professions[entry.section])
		row.right:SetText(entry.count == 1 and "1 recipe" or (entry.count .. " recipes"))
	else
		ShowRowParts(row, true, false)
		local recipe = entry.recipe
		row.band:SetColorTexture(1, 1, 1, index % 2 == 0 and 0.035 or 0)
		row.icon:SetTexture(RecipeIcon(recipe))
		row.name:SetText(recipe[1])
		row.name:SetTextColor(QualityColor(recipe[2]))
		row.right:SetText(recipe[4] > 0 and ("Skill-ups to " .. recipe[4]) or "")
		row.detail:SetText(ReagentList(recipe))
	end
end

local function Redraw()
	for i, row in ipairs(rows) do
		DrawRow(row, offset + i)
	end
	local maximum = MaxOffset()
	track:SetShown(maximum > 0)
	thumb:SetShown(maximum > 0)
	if maximum > 0 then
		local height = math.max(MIN_THUMB, TRACK_HEIGHT * VISIBLE_ROWS / #entries)
		thumb:SetHeight(height)
		thumb:ClearAllPoints()
		thumb:SetPoint("TOP", track, "TOP", 0, -(TRACK_HEIGHT - height) * offset / maximum)
	end
end

local function ScrollTo(value)
	value = math.max(0, math.min(MaxOffset(), value))
	if value ~= offset then
		offset = value
		Redraw()
	end
end

local function FillEntries()
	wipe(entries)
	local counts = {}
	local list = ns.reagents[reagentID][3]
	for _, position in ipairs(list) do
		local profession = ns.recipes[position][3]
		counts[profession] = (counts[profession] or 0) + 1
	end
	local current
	for _, position in ipairs(list) do
		local recipe = ns.recipes[position]
		if recipe[3] ~= current then
			current = recipe[3]
			entries[#entries + 1] = { section = current, count = counts[current] }
		end
		entries[#entries + 1] = { recipe = recipe }
	end
	return #list, counts
end

local function OpenWindow(itemID)
	reagentID = itemID
	offset = 0
	local total, counts = FillEntries()

	local info = ns.reagentInfo[itemID]
	headerIcon:SetTexture(select(5, ItemInfoInstant(itemID)) or QUESTION_MARK)
	title:SetText(info[1])
	title:SetTextColor(QualityColor(info[2]))
	local parts = {}
	for i, profession in ipairs(ns.reagents[itemID][1]) do
		parts[i] = ("%s %d"):format(ns.professions[profession], counts[profession])
	end
	subtitle:SetText(("%d %s: %s"):format(total, total == 1 and "recipe" or "recipes", table.concat(parts, ", ")))

	window:SetScale(math.min(1, (UIParent:GetHeight() - 40) / HEIGHT))
	window:Show()
	Redraw()
end

-- Where the cursor is, in the window's own units from its top left corner.
local function CursorInWindow()
	local left, top = window:GetLeft(), window:GetTop()
	if not left or not top then return nil end
	local x, y = GetCursorPosition()
	local scale = window:GetEffectiveScale()
	return x / scale - left, top - y / scale
end

local function EntryIndexAt(across, down)
	if not across or across < PADDING or across >= PADDING + ROW_WIDTH or down < HEADER_HEIGHT then return nil end
	local line = math.floor((down - HEADER_HEIGHT) / ROW_STEP) + 1
	if line > VISIBLE_ROWS then return nil end
	return offset + line, line
end

local function OverTrack(across, down)
	return across and across >= WIDTH - PADDING - BAR_WIDTH - 3 and across <= WIDTH - PADDING + 3
		and down >= HEADER_HEIGHT and down <= HEADER_HEIGHT + TRACK_HEIGHT + 4
end

local function SetHovered(entry)
	if entry == hoveredEntry then return end
	hoveredEntry = entry
	if entry then
		local recipe = entry.recipe
		GameTooltip:SetOwner(window, "ANCHOR_CURSOR")
		GameTooltip:SetHyperlink(recipe[5] > 0 and ("item:" .. recipe[5]) or ("spell:" .. recipe[6]))
		GameTooltip:Show()
	else
		GameTooltip:Hide()
	end
end

local function DragBar(down)
	local height = math.max(MIN_THUMB, TRACK_HEIGHT * VISIBLE_ROWS / #entries)
	local range = TRACK_HEIGHT - height
	local fraction = range > 0 and (down - HEADER_HEIGHT - 2 - height / 2) / range or 0
	ScrollTo(math.floor(math.max(0, math.min(1, fraction)) * MaxOffset() + 0.5))
end

window:SetScript("OnMouseWheel", function(_, delta)
	ScrollTo(offset - delta * WHEEL_STEP)
end)

window:SetScript("OnMouseDown", function(self, button)
	if button ~= "LeftButton" then return end
	local across, down = CursorInWindow()
	if not across then return end
	if MaxOffset() > 0 and OverTrack(across, down) then
		draggingBar = true
		DragBar(down)
	elseif down <= HEADER_HEIGHT then
		self:StartMoving()
	end
end)

window:SetScript("OnMouseUp", function(self)
	draggingBar = false
	self:StopMovingOrSizing()
end)

window:SetScript("OnUpdate", function()
	local across, down = CursorInWindow()
	if draggingBar and across then DragBar(down) end

	local index, line = EntryIndexAt(across, down)
	local entry = index and entries[index]
	if entry and entry.recipe and not draggingBar then
		highlight:ClearAllPoints()
		highlight:SetPoint("TOPLEFT", PADDING, RowTop(line))
		highlight:Show()
		SetHovered(entry)
	else
		highlight:Hide()
		SetHovered(nil)
	end
end)

window:SetScript("OnHide", function(self)
	draggingBar = false
	self:StopMovingOrSizing()
	highlight:Hide()
	SetHovered(nil)
end)

local function TooltipReagent()
	for _, tooltip in ipairs({ GameTooltip, ItemRefTooltip }) do
		local itemID = tooltipReagents[tooltip]
		if itemID and tooltip:IsShown() then return itemID end
	end
end

-- Called by the key binding (Bindings.xml).
function XanaReagents_ToggleWindow()
	local itemID = TooltipReagent()
	if itemID and not (window:IsShown() and itemID == reagentID) then
		OpenWindow(itemID)
	else
		window:Hide()
	end
end

SLASH_XANAREAGENTS1 = "/xreagents"
SlashCmdList["XANAREAGENTS"] = function()
	local reagents = 0
	for _ in pairs(ns.reagents) do reagents = reagents + 1 end
	print(("XanaReagents: data from build %s, %d reagents, %d recipes, tooltip hook: %s, window key: %s."):format(
		ns.build, reagents, #ns.recipes, hookMethod, BoundKey() or "not set (Options > Keybindings > AddOns)"))
end
