--!strict

local Geometry = {}

local EPSILON = 1e-6

export type Rect = {
	position: Vector2,
	size: Vector2,
}

export type PaddingPixels = {
	left: number,
	right: number,
	top: number,
	bottom: number,
}

local function vectorMin(a: Vector2, b: Vector2): Vector2
	return Vector2.new(math.min(a.X, b.X), math.min(a.Y, b.Y))
end

local function vectorMax(a: Vector2, b: Vector2): Vector2
	return Vector2.new(math.max(a.X, b.X), math.max(a.Y, b.Y))
end

local function multiplyComponents(a: Vector2, b: Vector2): Vector2
	return Vector2.new(a.X * b.X, a.Y * b.Y)
end

local function divideByScale(value: number, scale: number): number
	if math.abs(scale) <= EPSILON then
		return value
	end

	return value / scale
end

local function toUDim(value: number, basis: number): UDim
	if math.abs(basis) > EPSILON then
		return UDim.new(value / basis, 0)
	end

	return UDim.new(0, value)
end

local function paddingValue(udim: UDim, basis: number): number
	return udim.Scale * basis + udim.Offset
end

local function getChildCoordinateSize(parent: GuiBase2d, parentRect: Rect): Vector2
	if parent:IsA("ScrollingFrame") then
		return (parent :: ScrollingFrame).AbsoluteCanvasSize
	end

	return parentRect.size
end

function Geometry.getAbsoluteRect(gui: GuiBase2d): Rect
	return {
		position = gui.AbsolutePosition,
		size = gui.AbsoluteSize,
	}
end

function Geometry.getScrollOffset(gui: Instance): Vector2
	local offset = Vector2.zero
	local current = gui.Parent

	while current ~= nil do
		if current:IsA("ScrollingFrame") then
			offset += (current :: ScrollingFrame).CanvasPosition
		end

		current = current.Parent
	end

	return offset
end

function Geometry.getUnscrolledAbsoluteRect(gui: GuiBase2d): Rect
	local rect = Geometry.getAbsoluteRect(gui)

	return {
		position = rect.position + Geometry.getScrollOffset(gui),
		size = rect.size,
	}
end

function Geometry.getBounds(rects: { Rect }): Rect?
	if #rects == 0 then
		return nil
	end

	local minPosition = rects[1].position
	local maxPosition = rects[1].position + rects[1].size

	for index = 2, #rects do
		local rect = rects[index]
		minPosition = vectorMin(minPosition, rect.position)
		maxPosition = vectorMax(maxPosition, rect.position + rect.size)
	end

	return {
		position = minPosition,
		size = maxPosition - minPosition,
	}
end

function Geometry.getPaddingPixels(parent: Instance, parentSize: Vector2): PaddingPixels
	local padding = parent:FindFirstChildWhichIsA("UIPadding") :: UIPadding?
	if padding == nil then
		return {
			left = 0,
			right = 0,
			top = 0,
			bottom = 0,
		}
	end

	return {
		left = paddingValue(padding.PaddingLeft, parentSize.X),
		right = paddingValue(padding.PaddingRight, parentSize.X),
		top = paddingValue(padding.PaddingTop, parentSize.Y),
		bottom = paddingValue(padding.PaddingBottom, parentSize.Y),
	}
end

local function getChildCoordinateRectFromParentRect(parent: GuiBase2d, parentRect: Rect): Rect
	local padding = Geometry.getPaddingPixels(parent, parentRect.size)
	local coordinateSize = getChildCoordinateSize(parent, parentRect)
	local insetX = math.min(padding.left, coordinateSize.X - padding.right)
	local insetY = math.min(padding.top, coordinateSize.Y - padding.bottom)

	local position = parentRect.position + Vector2.new(insetX, insetY)
	local size = Vector2.new(
		math.max(0, coordinateSize.X - padding.left - padding.right),
		math.max(0, coordinateSize.Y - padding.top - padding.bottom)
	)

	return {
		position = position,
		size = size,
	}
end

function Geometry.getChildCoordinateRect(parent: GuiBase2d): Rect
	return getChildCoordinateRectFromParentRect(parent, Geometry.getAbsoluteRect(parent))
end

function Geometry.getUnscrolledChildCoordinateRect(parent: GuiBase2d): Rect
	return getChildCoordinateRectFromParentRect(parent, Geometry.getUnscrolledAbsoluteRect(parent))
end

function Geometry.getDirectUIScale(gui: Instance): number
	local scale = 1

	for _, child in gui:GetChildren() do
		local uiScale: UIScale? = nil
		if child:IsA("UIScale") then
			uiScale = child :: UIScale
		end

		if uiScale ~= nil then
			scale *= uiScale.Scale
		end
	end

	return scale
end

function Geometry.divideVectorByScale(vector: Vector2, scale: number): Vector2
	return Vector2.new(divideByScale(vector.X, scale), divideByScale(vector.Y, scale))
end

function Geometry.sizeBasisForAxis(parentSize: Vector2, axis: "X" | "Y", sizeConstraint: Enum.SizeConstraint): number
	if sizeConstraint == Enum.SizeConstraint.RelativeXX then
		return parentSize.X
	elseif sizeConstraint == Enum.SizeConstraint.RelativeYY then
		return parentSize.Y
	elseif axis == "X" then
		return parentSize.X
	else
		return parentSize.Y
	end
end

function Geometry.sizeToUDim2(
	absoluteSize: Vector2,
	parentSize: Vector2,
	sizeConstraint: Enum.SizeConstraint
): UDim2
	local x = toUDim(absoluteSize.X, Geometry.sizeBasisForAxis(parentSize, "X", sizeConstraint))
	local y = toUDim(absoluteSize.Y, Geometry.sizeBasisForAxis(parentSize, "Y", sizeConstraint))

	return UDim2.new(x.Scale, x.Offset, y.Scale, y.Offset)
end

function Geometry.absolutePositionToUDim2(absoluteAnchorPosition: Vector2, parentRect: Rect): UDim2
	local relativePosition = absoluteAnchorPosition - parentRect.position
	local x = toUDim(relativePosition.X, parentRect.size.X)
	local y = toUDim(relativePosition.Y, parentRect.size.Y)

	return UDim2.new(x.Scale, x.Offset, y.Scale, y.Offset)
end

function Geometry.rectToPositionUDim2(rect: Rect, anchorPoint: Vector2, parentRect: Rect): UDim2
	local anchorOffset = multiplyComponents(rect.size, anchorPoint)
	return Geometry.absolutePositionToUDim2(rect.position + anchorOffset, parentRect)
end

function Geometry.rectToUDim2(
	rect: Rect,
	anchorPoint: Vector2,
	parentRect: Rect,
	sizeConstraint: Enum.SizeConstraint,
	ownScale: number?
): (UDim2, UDim2)
	local scale = ownScale or 1
	local unscaledSize = Geometry.divideVectorByScale(rect.size, scale)

	return Geometry.rectToPositionUDim2(rect, anchorPoint, parentRect),
		Geometry.sizeToUDim2(unscaledSize, parentRect.size, sizeConstraint)
end

function Geometry.rectsNearlyEqual(a: Rect, b: Rect, tolerance: number): boolean
	return (a.position - b.position).Magnitude <= tolerance and (a.size - b.size).Magnitude <= tolerance
end

return Geometry
