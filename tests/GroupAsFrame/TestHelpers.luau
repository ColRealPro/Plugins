--!nonstrict

local Geometry = require(script.Parent.Parent.Parent.plugins.GroupAsFrame.Geometry)

local Helpers = {}

local DEFAULT_ROOT_SIZE = Vector2.new(800, 600)
local DEFAULT_TOLERANCE = 0.05

local function tryParent(instance, parent)
	local ok = pcall(function()
		instance.Parent = parent
	end)

	if ok then
		return true
	end

	instance.Parent = nil
	return false
end

local function resolveMountParent()
	local coreGui = game:GetService("CoreGui")
	local probe = Instance.new("ScreenGui")

	if tryParent(probe, coreGui) then
		probe:Destroy()
		return coreGui
	end

	probe:Destroy()

	local localPlayer = game:GetService("Players").LocalPlayer
	if localPlayer then
		return localPlayer:WaitForChild("PlayerGui")
	end

	return game:GetService("StarterGui")
end

function Helpers.settle()
	task.wait()
end

function Helpers.mountRoot(rootSize)
	local screen = Instance.new("ScreenGui")
	screen.Name = "GroupAsFrameTestScreen"
	screen.IgnoreGuiInset = true
	screen.ResetOnSpawn = false
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Global

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.AnchorPoint = Vector2.zero
	root.Position = UDim2.fromOffset(0, 0)
	root.Size = UDim2.fromOffset((rootSize or DEFAULT_ROOT_SIZE).X, (rootSize or DEFAULT_ROOT_SIZE).Y)
	root.Parent = screen

	screen.Parent = resolveMountParent()
	Helpers.settle()

	return screen, root
end

function Helpers.gui(className, parent, props)
	local gui = Instance.new(className)

	for property, value in props or {} do
		gui[property] = value
	end

	gui.Parent = parent
	return gui
end

function Helpers.snapshot(objects, rectGetter)
	local snapshots = {}
	local getRect = rectGetter or Geometry.getAbsoluteRect

	for _, object in objects do
		snapshots[object] = getRect(object)
	end

	return snapshots
end

function Helpers.snapshotUnscrolled(objects)
	return Helpers.snapshot(objects, Geometry.getUnscrolledAbsoluteRect)
end

function Helpers.expectNumberClose(expectFn, actual, expected, tolerance)
	local allowedDifference = tolerance or DEFAULT_TOLERANCE
	local difference = math.abs(actual - expected)

	expectFn(difference <= allowedDifference).to.equal(true)
end

function Helpers.expectVectorClose(expectFn, actual, expected, tolerance)
	Helpers.expectNumberClose(expectFn, actual.X, expected.X, tolerance)
	Helpers.expectNumberClose(expectFn, actual.Y, expected.Y, tolerance)
end

function Helpers.expectRectClose(expectFn, actual, expected, tolerance)
	Helpers.expectVectorClose(expectFn, actual.position, expected.position, tolerance)
	Helpers.expectVectorClose(expectFn, actual.size, expected.size, tolerance)
end

function Helpers.expectPreservedWithGetter(expectFn, snapshots, rectGetter, tolerance)
	local getRect = rectGetter or Geometry.getAbsoluteRect

	for object, before in snapshots do
		Helpers.expectRectClose(expectFn, getRect(object), before, tolerance)
	end
end

function Helpers.expectPreserved(expectFn, snapshots, tolerance)
	Helpers.expectPreservedWithGetter(expectFn, snapshots, Geometry.getAbsoluteRect, tolerance)
end

function Helpers.expectUnscrolledPreserved(expectFn, snapshots, tolerance)
	Helpers.expectPreservedWithGetter(expectFn, snapshots, Geometry.getUnscrolledAbsoluteRect, tolerance)
end

function Helpers.destroy(instance)
	if instance ~= nil then
		instance:Destroy()
	end
end

return Helpers
