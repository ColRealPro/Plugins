--!strict

local Geometry = require(script.Parent.Geometry)

local GroupAsFrame = {}

local DEFAULT_FRAME_NAME = "GroupFrame"

export type FailureReason =
	"NoGuiObjects"
	| "NoCommonParent"
	| "NoBounds"
	| "InvalidPreparedGroup"
	| "NoTargetFrame"
	| "AmbiguousTargetFrame"
	| "InvalidTargetFrame"
	| "TargetDescendantOfSelection"
	| "TargetAutomaticSize"
	| "TargetHasLayout"
	| "InvalidPreparedReparent"

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

export type PreparedReparent = {
	ok: boolean,
	reason: FailureReason?,
	ignored: { Instance },
	records: { GroupRecord },
	targetFrame: GuiObject?,
	targetFrameRect: Geometry.Rect?,
}

export type PreparedOperation = PreparedGroup | PreparedReparent

export type GroupResult = {
	ok: boolean,
	reason: FailureReason?,
	ignored: { Instance },
	frame: GuiObject?,
	groupedObjects: { GuiObject },
	prepared: PreparedOperation?,
}

export type GroupOptions = {
	frameName: string?,
}

local FAILURE_MESSAGES: { [FailureReason]: string } = {
	NoGuiObjects = "Select at least one GuiObject to group.",
	NoCommonParent = "Selected GuiObjects do not share a GUI ancestor that can contain a Frame.",
	NoBounds = "Could not calculate bounds for the selected GuiObjects.",
	InvalidPreparedGroup = "The prepared group is missing required data.",
	NoTargetFrame = "Set an existing GUI object (Frame, ImageLabel, TextButton, etc.) as the reparent target before reparenting.",
	AmbiguousTargetFrame = "Select exactly one GUI object to set as the reparent target.",
	InvalidTargetFrame = "The reparent target must be an existing GuiObject (Frame, ImageLabel, TextLabel, ImageButton, etc.).",
	TargetDescendantOfSelection = "The reparent target cannot be inside one of the selected GuiObjects.",
	TargetAutomaticSize = "The target uses AutomaticSize, so exact preservation cannot be guaranteed.",
	TargetHasLayout = "The target contains a UILayout, so exact preservation cannot be guaranteed.",
	InvalidPreparedReparent = "The prepared reparent operation is missing required data.",
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

local function asTargetGuiObject(instance: Instance?): GuiObject?
	if instance ~= nil and instance:IsA("GuiObject") then
		return instance :: GuiObject
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

local function removeTargetFrameFromSelection(guiObjects: { GuiObject }, targetFrame: GuiObject): { GuiObject }
	local filtered: { GuiObject } = {}

	for _, guiObject in guiObjects do
		if guiObject ~= targetFrame then
			table.insert(filtered, guiObject)
		end
	end

	return filtered
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

local function getTargetFrameFailure(targetFrame: Instance?): (GuiObject?, FailureReason?)
	local frame = asTargetGuiObject(targetFrame)
	if targetFrame == nil then
		return nil, "NoTargetFrame"
	end

	if frame == nil or frame.Parent == nil then
		return nil, "InvalidTargetFrame"
	end

	if frame.AutomaticSize ~= Enum.AutomaticSize.None then
		return nil, "TargetAutomaticSize"
	end

	if hasLayoutController(frame) then
		return nil, "TargetHasLayout"
	end

	return frame, nil
end

local function hasSelectedAncestorOfTarget(guiObjects: { GuiObject }, targetFrame: GuiObject): boolean
	for _, guiObject in guiObjects do
		if guiObject:IsAncestorOf(targetFrame) then
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

local function reparentFailure(reason: FailureReason, ignored: { Instance }?, targetFrame: GuiObject?): PreparedReparent
	return {
		ok = false,
		reason = reason,
		ignored = ignored or {},
		records = {},
		targetFrame = targetFrame,
		targetFrameRect = nil,
	}
end

function GroupAsFrame.getFailureMessage(reason: FailureReason?): string
	if reason == nil then
		return "An unknown error occurred."
	end

	return FAILURE_MESSAGES[reason] or "An unknown error occurred."
end

function GroupAsFrame.pickTargetFrame(selection: { Instance }): (boolean, GuiObject?, FailureReason?)
	if #selection == 0 then
		return false, nil, "NoTargetFrame"
	end

	if #selection > 1 then
		return false, nil, "AmbiguousTargetFrame"
	end

	local frame = asTargetGuiObject(selection[1])
	if frame == nil or frame.Parent == nil then
		return false, nil, "InvalidTargetFrame"
	end

	return true, frame, nil
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
		local rect = Geometry.getUnscrolledAbsoluteRect(object)
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
		targetParentRect = Geometry.getUnscrolledChildCoordinateRect(targetParent),
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

	local frameRect = Geometry.getUnscrolledChildCoordinateRect(frame)

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

function GroupAsFrame.prepareReparent(selection: { Instance }, targetFrame: Instance?): PreparedReparent
	local guiObjects, ignored = collectGuiObjects(selection)
	local validTargetFrame, targetFailure = getTargetFrameFailure(targetFrame)
	if validTargetFrame == nil then
		local reason: FailureReason = if targetFailure ~= nil then targetFailure else "InvalidTargetFrame"
		return reparentFailure(reason, ignored, nil)
	end

	local targetlessObjects = removeTargetFrameFromSelection(guiObjects, validTargetFrame)
	local collapsedObjects = collapseNestedSelections(targetlessObjects)

	if #collapsedObjects == 0 then
		return reparentFailure("NoGuiObjects", ignored, validTargetFrame)
	end

	if hasSelectedAncestorOfTarget(collapsedObjects, validTargetFrame) then
		return reparentFailure("TargetDescendantOfSelection", ignored, validTargetFrame)
	end

	local records: { GroupRecord } = {}

	for _, object in collapsedObjects do
		table.insert(records, {
			object = object,
			rect = Geometry.getUnscrolledAbsoluteRect(object),
			anchorPoint = object.AnchorPoint,
			layoutOrder = object.LayoutOrder,
			zIndex = object.ZIndex,
		})
	end

	return {
		ok = true,
		reason = nil,
		ignored = ignored,
		records = records,
		targetFrame = validTargetFrame,
		targetFrameRect = Geometry.getUnscrolledChildCoordinateRect(validTargetFrame),
	}
end

function GroupAsFrame.applyReparent(prepared: PreparedReparent): GroupResult
	if not prepared.ok or prepared.targetFrame == nil or prepared.targetFrameRect == nil then
		return {
			ok = false,
			reason = "InvalidPreparedReparent",
			ignored = prepared.ignored,
			frame = nil,
			groupedObjects = {},
			prepared = prepared,
		}
	end

	local targetFrame = prepared.targetFrame

	for _, record in prepared.records do
		local object = record.object
		local position, size = Geometry.rectToUDim2(
			record.rect,
			record.anchorPoint,
			prepared.targetFrameRect,
			object.SizeConstraint,
			Geometry.getDirectUIScale(object)
		)

		object.Parent = targetFrame
		object.Size = size
		object.Position = position
	end

	return {
		ok = true,
		reason = nil,
		ignored = prepared.ignored,
		frame = targetFrame,
		groupedObjects = getGroupedObjects(prepared.records),
		prepared = prepared,
	}
end

function GroupAsFrame.reparentToFrame(selection: { Instance }, targetFrame: Instance?): GroupResult
	local prepared = GroupAsFrame.prepareReparent(selection, targetFrame)
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

	return GroupAsFrame.applyReparent(prepared)
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
	getTargetFrameFailure = getTargetFrameFailure,
	hasSelectedAncestorOfTarget = hasSelectedAncestorOfTarget,
	resolveTargetParent = resolveTargetParent,
}

return GroupAsFrame
