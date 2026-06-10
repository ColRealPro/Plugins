--!strict

local Geometry = require(script.Parent.Geometry)

local GroupAsFrame = {}

local DEFAULT_FRAME_NAME = "GroupFrame"

export type FailureReason =
	"NoGuiObjects"
	| "NoCommonParent"
	| "NoBounds"
	| "InvalidPreparedGroup"

export type GroupRecord = {
	object: GuiObject,
	rect: Geometry.Rect,
	anchorPoint: Vector2,
	layoutOrder: number,
	zIndex: number,
}

export type PreparedGroup = {
	ok: boolean,
	reason: FailureReason?,
	ignored: { Instance },
	records: { GroupRecord },
	commonParent: GuiBase2d?,
	targetParent: GuiBase2d?,
	targetParentRect: Geometry.Rect?,
	bounds: Geometry.Rect?,
	frameName: string,
}

export type GroupResult = {
	ok: boolean,
	reason: FailureReason?,
	ignored: { Instance },
	frame: Frame?,
	groupedObjects: { GuiObject },
	prepared: PreparedGroup?,
}

export type GroupOptions = {
	frameName: string?,
}

local FAILURE_MESSAGES: { [FailureReason]: string } = {
	NoGuiObjects = "Select at least one GuiObject to group.",
	NoCommonParent = "Selected GuiObjects do not share a GUI ancestor that can contain a Frame.",
	NoBounds = "Could not calculate bounds for the selected GuiObjects.",
	InvalidPreparedGroup = "The prepared group is missing required data.",
}

local function asGuiObject(instance: Instance): GuiObject?
	if instance:IsA("GuiObject") then
		return instance :: GuiObject
	end

	return nil
end

local function asGuiBase2d(instance: Instance): GuiBase2d?
	if instance:IsA("GuiBase2d") then
		return instance :: GuiBase2d
	end

	return nil
end

local function uniquePush<T>(array: { T }, seen: { [T]: boolean }, value: T)
	if seen[value] then
		return
	end

	seen[value] = true
	table.insert(array, value)
end

local function collectGuiObjects(selection: { Instance }): ({ GuiObject }, { Instance })
	local guiObjects: { GuiObject } = {}
	local ignored: { Instance } = {}
	local seen: { [GuiObject]: boolean } = {}

	for _, instance in selection do
		local guiObject = asGuiObject(instance)
		if guiObject ~= nil then
			uniquePush(guiObjects, seen, guiObject)
		else
			table.insert(ignored, instance)
		end
	end

	return guiObjects, ignored
end

local function collapseNestedSelections(guiObjects: { GuiObject }): { GuiObject }
	local collapsed: { GuiObject } = {}

	for _, candidate in guiObjects do
		local hasSelectedAncestor = false

		for _, possibleAncestor in guiObjects do
			if candidate ~= possibleAncestor and possibleAncestor:IsAncestorOf(candidate) then
				hasSelectedAncestor = true
				break
			end
		end

		if not hasSelectedAncestor then
			table.insert(collapsed, candidate)
		end
	end

	return collapsed
end

local function getGuiAncestorList(guiObject: GuiObject): { GuiBase2d }
	local ancestors: { GuiBase2d } = {}
	local current = guiObject.Parent

	while current ~= nil do
		local guiBase = asGuiBase2d(current)
		if guiBase ~= nil then
			table.insert(ancestors, guiBase)
		end

		current = current.Parent
	end

	return ancestors
end

local function getGuiAncestorSet(guiObject: GuiObject): { [Instance]: boolean }
	local set: { [Instance]: boolean } = {}

	for _, ancestor in getGuiAncestorList(guiObject) do
		set[ancestor] = true
	end

	return set
end

local function findNearestCommonGuiBase2d(guiObjects: { GuiObject }): GuiBase2d?
	if #guiObjects == 0 then
		return nil
	end

	local firstAncestors = getGuiAncestorList(guiObjects[1])
	local otherAncestorSets: { { [Instance]: boolean } } = {}

	for index = 2, #guiObjects do
		table.insert(otherAncestorSets, getGuiAncestorSet(guiObjects[index]))
	end

	for _, ancestor in firstAncestors do
		local sharedByAll = true

		for _, ancestorSet in otherAncestorSets do
			if not ancestorSet[ancestor] then
				sharedByAll = false
				break
			end
		end

		if sharedByAll then
			return ancestor
		end
	end

	return nil
end

local function hasLayoutController(parent: Instance): boolean
	for _, child in parent:GetChildren() do
		if child:IsA("UILayout") then
			return true
		end
	end

	return false
end

local function findNearestGuiParent(instance: Instance): GuiBase2d?
	local current = instance.Parent

	while current ~= nil do
		local guiBase = asGuiBase2d(current)
		if guiBase ~= nil then
			return guiBase
		end

		current = current.Parent
	end

	return nil
end

local function resolveTargetParent(commonParent: GuiBase2d): GuiBase2d
	local targetParent = commonParent

	while hasLayoutController(targetParent) do
		local parent = findNearestGuiParent(targetParent)
		if parent == nil then
			break
		end

		targetParent = parent
	end

	return targetParent
end

local function computeFrameLayoutOrder(records: { GroupRecord }): number
	if #records == 0 then
		return 0
	end

	local layoutOrder = records[1].layoutOrder

	for index = 2, #records do
		layoutOrder = math.min(layoutOrder, records[index].layoutOrder)
	end

	return layoutOrder
end

local function computeFrameZIndex(records: { GroupRecord }): number
	if #records == 0 then
		return 1
	end

	local zIndex = records[1].zIndex

	for index = 2, #records do
		zIndex = math.min(zIndex, records[index].zIndex)
	end

	return zIndex
end

local function getGroupedObjects(records: { GroupRecord }): { GuiObject }
	local groupedObjects: { GuiObject } = {}

	for _, record in records do
		table.insert(groupedObjects, record.object)
	end

	return groupedObjects
end

local function failure(reason: FailureReason, ignored: { Instance }?): PreparedGroup
	return {
		ok = false,
		reason = reason,
		ignored = ignored or {},
		records = {},
		commonParent = nil,
		targetParent = nil,
		targetParentRect = nil,
		bounds = nil,
		frameName = DEFAULT_FRAME_NAME,
	}
end

function GroupAsFrame.getFailureMessage(reason: FailureReason?): string
	if reason == nil then
		return "An unknown error occurred."
	end

	return FAILURE_MESSAGES[reason] or "An unknown error occurred."
end

function GroupAsFrame.prepare(selection: { Instance }, options: GroupOptions?): PreparedGroup
	local guiObjects, ignored = collectGuiObjects(selection)
	local collapsedObjects = collapseNestedSelections(guiObjects)

	if #collapsedObjects == 0 then
		return failure("NoGuiObjects", ignored)
	end

	local commonParent = findNearestCommonGuiBase2d(collapsedObjects)
	if commonParent == nil then
		return failure("NoCommonParent", ignored)
	end

	local targetParent = resolveTargetParent(commonParent)
	local records: { GroupRecord } = {}
	local rects: { Geometry.Rect } = {}

	for _, object in collapsedObjects do
		local rect = Geometry.getAbsoluteRect(object)
		table.insert(rects, rect)
		table.insert(records, {
			object = object,
			rect = rect,
			anchorPoint = object.AnchorPoint,
			layoutOrder = object.LayoutOrder,
			zIndex = object.ZIndex,
		})
	end

	local bounds = Geometry.getBounds(rects)
	if bounds == nil then
		return failure("NoBounds", ignored)
	end

	return {
		ok = true,
		reason = nil,
		ignored = ignored,
		records = records,
		commonParent = commonParent,
		targetParent = targetParent,
		targetParentRect = Geometry.getChildCoordinateRect(targetParent),
		bounds = bounds,
		frameName = if options and options.frameName then options.frameName else DEFAULT_FRAME_NAME,
	}
end

function GroupAsFrame.apply(prepared: PreparedGroup): GroupResult
	if not prepared.ok or prepared.targetParent == nil or prepared.targetParentRect == nil or prepared.bounds == nil then
		return {
			ok = false,
			reason = "InvalidPreparedGroup",
			ignored = prepared.ignored,
			frame = nil,
			groupedObjects = {},
			prepared = prepared,
		}
	end

	local frame = Instance.new("Frame")
	frame.Name = prepared.frameName
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = false
	frame.AnchorPoint = Vector2.zero
	frame.AutomaticSize = Enum.AutomaticSize.None
	frame.LayoutOrder = computeFrameLayoutOrder(prepared.records)
	frame.ZIndex = computeFrameZIndex(prepared.records)
	frame.SizeConstraint = Enum.SizeConstraint.RelativeXY
	frame.Size = Geometry.sizeToUDim2(prepared.bounds.size, prepared.targetParentRect.size, frame.SizeConstraint)
	frame.Position = Geometry.rectToPositionUDim2(prepared.bounds, frame.AnchorPoint, prepared.targetParentRect)
	frame.Parent = prepared.targetParent

	local frameRect = Geometry.getChildCoordinateRect(frame)

	for _, record in prepared.records do
		local object = record.object
		local position, size = Geometry.rectToUDim2(
			record.rect,
			record.anchorPoint,
			frameRect,
			object.SizeConstraint,
			Geometry.getDirectUIScale(object)
		)

		object.Parent = frame
		object.Size = size
		object.Position = position
	end

	return {
		ok = true,
		reason = nil,
		ignored = prepared.ignored,
		frame = frame,
		groupedObjects = getGroupedObjects(prepared.records),
		prepared = prepared,
	}
end

function GroupAsFrame.group(selection: { Instance }, options: GroupOptions?): GroupResult
	local prepared = GroupAsFrame.prepare(selection, options)
	if not prepared.ok then
		return {
			ok = false,
			reason = prepared.reason,
			ignored = prepared.ignored,
			frame = nil,
			groupedObjects = {},
			prepared = prepared,
		}
	end

	return GroupAsFrame.apply(prepared)
end

GroupAsFrame._private = {
	collectGuiObjects = collectGuiObjects,
	collapseNestedSelections = collapseNestedSelections,
	findNearestCommonGuiBase2d = findNearestCommonGuiBase2d,
	hasLayoutController = hasLayoutController,
	resolveTargetParent = resolveTargetParent,
}

return GroupAsFrame
