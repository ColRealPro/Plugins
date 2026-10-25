--!nonstrict

local Geometry = require(script.Parent.Parent.Parent.plugins.GroupAsFrame.Geometry)
local GroupAsFrame = require(script.Parent.Parent.Parent.plugins.GroupAsFrame.GroupAsFrame)
local Helpers = require(script.Parent.TestHelpers)

local TOLERANCE = 0.75

local function expectGroupPreserved(expectFn, selection, objects)
	Helpers.settle()
	local before = Helpers.snapshot(objects)
	local result = GroupAsFrame.group(selection)
	Helpers.settle()

	expectFn(result.ok).to.equal(true)
	expectFn(result.frame ~= nil).to.equal(true)

	Helpers.expectPreserved(expectFn, before, TOLERANCE)

	for _, object in objects do
		expectFn(object.Parent).to.equal(result.frame)
	end

	return result, before
end

local function expectGroupUnscrolledPreserved(expectFn, selection, objects)
	Helpers.settle()
	local before = Helpers.snapshotUnscrolled(objects)
	local result = GroupAsFrame.group(selection)
	Helpers.settle()

	expectFn(result.ok).to.equal(true)
	expectFn(result.frame ~= nil).to.equal(true)

	Helpers.expectUnscrolledPreserved(expectFn, before, TOLERANCE)

	for _, object in objects do
		expectFn(object.Parent).to.equal(result.frame)
	end

	return result, before
end

return function()
	describe("GroupAsFrame.group", function()
		local screen

		afterEach(function()
			Helpers.destroy(screen)
			screen = nil
		end)

		local function mount()
			local root
			screen, root = Helpers.mountRoot()
			return root
		end

		it("groups a single object into an invisible fitting frame", function()
			local root = mount()
			local object = Helpers.gui("Frame", root, {
				Name = "Single",
				Position = UDim2.fromOffset(50, 70),
				Size = UDim2.fromOffset(120, 80),
			})

			local result, before = expectGroupPreserved(expect, { object }, { object })

			expect(result.frame.Name).to.equal("GroupFrame")
			expect(result.frame.BackgroundTransparency).to.equal(1)
			expect(result.frame.BorderSizePixel).to.equal(0)
			expect(result.frame.ClipsDescendants).to.equal(false)
			expect(result.frame.AutomaticSize).to.equal(Enum.AutomaticSize.None)
			Helpers.expectRectClose(expect, Geometry.getAbsoluteRect(result.frame), before[object], TOLERANCE)
			expect(object.Size.X.Offset).to.equal(0)
			expect(object.Size.Y.Offset).to.equal(0)
		end)

		it("fits two separated offset-positioned objects", function()
			local root = mount()
			local left = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(25, 100),
				Size = UDim2.fromOffset(75, 50),
			})
			local right = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(300, 250),
				Size = UDim2.fromOffset(125, 90),
			})

			local result = expectGroupPreserved(expect, { left, right }, { left, right })

			Helpers.expectRectClose(expect, Geometry.getAbsoluteRect(result.frame), {
				position = Vector2.new(25, 100),
				size = Vector2.new(400, 240),
			}, TOLERANCE)
		end)

		it("preserves scale-only and mixed scale/offset objects", function()
			local root = mount()
			local scaleOnly = Helpers.gui("Frame", root, {
				Position = UDim2.fromScale(0.125, 0.25),
				Size = UDim2.fromScale(0.2, 0.15),
			})
			local mixed = Helpers.gui("TextLabel", root, {
				Position = UDim2.new(0.5, -40, 0.1, 20),
				Size = UDim2.new(0.25, 10, 0.2, -5),
				Text = "Mixed",
			})

			expectGroupPreserved(expect, { scaleOnly, mixed }, { scaleOnly, mixed })
			expect(scaleOnly.Size.X.Offset).to.equal(0)
			expect(mixed.Position.X.Offset).to.equal(0)
		end)

		it("handles overlapping objects and negative offsets", function()
			local root = mount()
			local negative = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(-40, -25),
				Size = UDim2.fromOffset(100, 100),
			})
			local overlap = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(20, 10),
				Size = UDim2.fromOffset(120, 80),
			})

			local result = expectGroupPreserved(expect, { negative, overlap }, { negative, overlap })
			Helpers.expectRectClose(expect, Geometry.getAbsoluteRect(result.frame), {
				position = Vector2.new(-40, -25),
				size = Vector2.new(180, 115),
			}, TOLERANCE)
		end)

		it("preserves mixed anchor points", function()
			local root = mount()
			local topLeft = Helpers.gui("Frame", root, {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(40, 60),
				Size = UDim2.fromOffset(80, 90),
			})
			local center = Helpers.gui("Frame", root, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(300, 240),
				Size = UDim2.fromOffset(120, 100),
			})
			local bottomRight = Helpers.gui("Frame", root, {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.fromOffset(700, 500),
				Size = UDim2.fromOffset(150, 125),
			})

			expectGroupPreserved(expect, { topLeft, center, bottomRight }, { topLeft, center, bottomRight })
			expect(center.AnchorPoint).to.equal(Vector2.new(0.5, 0.5))
			expect(bottomRight.AnchorPoint).to.equal(Vector2.new(1, 1))
		end)

		it("ignores non-GuiObject selections while grouping valid objects", function()
			local root = mount()
			local folder = Instance.new("Folder")
			local object = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(20, 30),
				Size = UDim2.fromOffset(60, 70),
			})

			local result = expectGroupPreserved(expect, { folder, object }, { object })
			expect(#result.ignored).to.equal(1)
			folder:Destroy()
		end)

		it("returns a no-op failure for empty or non-UI selections", function()
			local empty = GroupAsFrame.group({})
			expect(empty.ok).to.equal(false)
			expect(empty.reason).to.equal("NoGuiObjects")

			local folder = Instance.new("Folder")
			local nonUi = GroupAsFrame.group({ folder })
			expect(nonUi.ok).to.equal(false)
			expect(nonUi.reason).to.equal("NoGuiObjects")
			expect(#nonUi.ignored).to.equal(1)
			folder:Destroy()
		end)

		it("collapses selected descendants into the selected ancestor", function()
			local root = mount()
			local parent = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(100, 120),
				Size = UDim2.fromOffset(200, 180),
			})
			local child = Helpers.gui("Frame", parent, {
				Position = UDim2.fromOffset(30, 40),
				Size = UDim2.fromOffset(50, 60),
			})

			local result = expectGroupPreserved(expect, { parent, child }, { parent })
			expect(#result.groupedObjects).to.equal(1)
			expect(child.Parent).to.equal(parent)
		end)

		it("groups objects from different parents under their nearest common GUI ancestor", function()
			local root = mount()
			local leftContainer = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(50, 50),
				Size = UDim2.fromOffset(250, 250),
			})
			local rightContainer = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(400, 200),
				Size = UDim2.fromOffset(250, 250),
			})
			local left = Helpers.gui("Frame", leftContainer, {
				Position = UDim2.fromOffset(25, 35),
				Size = UDim2.fromOffset(80, 90),
			})
			local right = Helpers.gui("Frame", rightContainer, {
				Position = UDim2.fromOffset(40, 30),
				Size = UDim2.fromOffset(70, 60),
			})

			local result = expectGroupPreserved(expect, { left, right }, { left, right })
			expect(result.frame.Parent).to.equal(root)
		end)

		it("fails cleanly when selected objects have no shared GUI ancestor", function()
			local screenA, rootA = Helpers.mountRoot()
			local screenB, rootB = Helpers.mountRoot()
			local a = Helpers.gui("Frame", rootA, {
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(10, 10),
			})
			local b = Helpers.gui("Frame", rootB, {
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(10, 10),
			})

			local result = GroupAsFrame.group({ a, b })
			expect(result.ok).to.equal(false)
			expect(result.reason).to.equal("NoCommonParent")
			expect(a.Parent).to.equal(rootA)
			expect(b.Parent).to.equal(rootB)

			screenA:Destroy()
			screenB:Destroy()
		end)

		it("accounts for UIPadding on the target parent", function()
			local root = mount()
			local padding = Instance.new("UIPadding")
			padding.PaddingLeft = UDim.new(0, 20)
			padding.PaddingTop = UDim.new(0, 30)
			padding.PaddingRight = UDim.new(0, 10)
			padding.PaddingBottom = UDim.new(0, 15)
			padding.Parent = root

			local object = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(40, 50),
				Size = UDim2.fromOffset(120, 90),
			})

			expectGroupPreserved(expect, { object }, { object })
		end)

		it("uses top-of-canvas coordinates for objects directly inside a ScrollingFrame", function()
			local root = mount()
			local scrollingFrame = Helpers.gui("ScrollingFrame", root, {
				CanvasSize = UDim2.fromOffset(1000, 1000),
				Position = UDim2.fromOffset(100, 100),
				Size = UDim2.fromOffset(300, 300),
			})
			local object = Helpers.gui("Frame", scrollingFrame, {
				Position = UDim2.fromOffset(150, 175),
				Size = UDim2.fromOffset(80, 60),
			})
			Helpers.settle()
			scrollingFrame.CanvasPosition = Vector2.new(30, 45)
			Helpers.settle()

			local result = expectGroupUnscrolledPreserved(expect, { object }, { object })
			expect(result.frame.Parent).to.equal(scrollingFrame)
			Helpers.expectRectClose(expect, Geometry.getUnscrolledAbsoluteRect(result.frame), {
				position = Vector2.new(250, 275),
				size = Vector2.new(80, 60),
			}, TOLERANCE)
		end)

		it("uses top-of-canvas coordinates when grouping across a ScrollingFrame boundary", function()
			local root = mount()
			local scrollingFrame = Helpers.gui("ScrollingFrame", root, {
				CanvasSize = UDim2.fromOffset(1000, 1000),
				Position = UDim2.fromOffset(100, 100),
				Size = UDim2.fromOffset(300, 300),
			})
			local inside = Helpers.gui("Frame", scrollingFrame, {
				Position = UDim2.fromOffset(160, 180),
				Size = UDim2.fromOffset(50, 60),
			})
			local outside = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(500, 120),
				Size = UDim2.fromOffset(90, 70),
			})
			Helpers.settle()
			scrollingFrame.CanvasPosition = Vector2.new(30, 45)
			Helpers.settle()

			local result = expectGroupUnscrolledPreserved(expect, { inside, outside }, { inside, outside })
			expect(result.frame.Parent).to.equal(root)
			Helpers.expectRectClose(expect, Geometry.getUnscrolledAbsoluteRect(result.frame), {
				position = Vector2.new(260, 120),
				size = Vector2.new(330, 220),
			}, TOLERANCE)
		end)

		it("moves out of layout-controlled parents so UIListLayout does not reposition the group frame", function()
			local root = mount()
			local listParent = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(80, 90),
				Size = UDim2.fromOffset(300, 300),
			})
			local layout = Instance.new("UIListLayout")
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout.Padding = UDim.new(0, 8)
			layout.Parent = listParent

			local first = Helpers.gui("Frame", listParent, {
				LayoutOrder = 1,
				Size = UDim2.fromOffset(100, 40),
			})
			local second = Helpers.gui("Frame", listParent, {
				LayoutOrder = 2,
				Size = UDim2.fromOffset(100, 50),
			})

			local result = expectGroupPreserved(expect, { first, second }, { first, second })
			expect(result.frame.Parent).to.equal(root)
		end)

		it("moves out of grid layout parents so UIGridLayout cannot resize the group frame", function()
			local root = mount()
			local gridParent = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(40, 40),
				Size = UDim2.fromOffset(400, 300),
			})
			local layout = Instance.new("UIGridLayout")
			layout.CellSize = UDim2.fromOffset(90, 70)
			layout.CellPadding = UDim2.fromOffset(12, 14)
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout.Parent = gridParent

			local first = Helpers.gui("Frame", gridParent, {
				LayoutOrder = 1,
			})
			local second = Helpers.gui("Frame", gridParent, {
				LayoutOrder = 2,
			})
			local third = Helpers.gui("Frame", gridParent, {
				LayoutOrder = 3,
			})

			local result = expectGroupPreserved(expect, { first, third }, { first, third })
			expect(result.frame.Parent).to.equal(root)
			expect(second.Parent).to.equal(gridParent)
		end)

		it("preserves objects with size, aspect, and automatic-size constraints", function()
			local root = mount()
			local constrained = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(50, 60),
				Size = UDim2.fromOffset(140, 100),
			})
			local sizeConstraint = Instance.new("UISizeConstraint")
			sizeConstraint.MinSize = Vector2.new(50, 50)
			sizeConstraint.MaxSize = Vector2.new(300, 300)
			sizeConstraint.Parent = constrained

			local aspect = Helpers.gui("ImageLabel", root, {
				Position = UDim2.fromOffset(250, 100),
				Size = UDim2.fromOffset(120, 60),
				Image = "rbxassetid://0",
			})
			local aspectConstraint = Instance.new("UIAspectRatioConstraint")
			aspectConstraint.AspectRatio = 2
			aspectConstraint.Parent = aspect

			local automatic = Helpers.gui("TextLabel", root, {
				AutomaticSize = Enum.AutomaticSize.XY,
				Position = UDim2.fromOffset(450, 160),
				Size = UDim2.fromOffset(20, 20),
				Text = "Automatic",
				TextSize = 24,
			})

			expectGroupPreserved(expect, { constrained, aspect, automatic }, { constrained, aspect, automatic })
		end)

		it("preserves objects under ancestor UIScale and with their own UIScale", function()
			local root = mount()
			local scaledContainer = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(100, 100),
				Size = UDim2.fromOffset(300, 240),
			})
			local ancestorScale = Instance.new("UIScale")
			ancestorScale.Scale = 1.25
			ancestorScale.Parent = scaledContainer

			local object = Helpers.gui("Frame", scaledContainer, {
				Position = UDim2.fromOffset(40, 50),
				Size = UDim2.fromOffset(100, 80),
			})
			local ownScale = Instance.new("UIScale")
			ownScale.Scale = 0.5
			ownScale.Parent = object

			expectGroupPreserved(expect, { object }, { object })
		end)

		it("keeps visual properties, constraints, and descendants intact", function()
			local root = mount()
			local textLabel = Helpers.gui("TextLabel", root, {
				Name = "PreserveMe",
				Position = UDim2.fromOffset(200, 220),
				Size = UDim2.fromOffset(180, 70),
				Visible = false,
				ZIndex = 12,
				LayoutOrder = 99,
				Rotation = 15,
				Text = "Keep text",
				TextColor3 = Color3.fromRGB(12, 34, 56),
			})
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 8)
			corner.Parent = textLabel

			local result = expectGroupPreserved(expect, { textLabel }, { textLabel })

			expect(textLabel.Name).to.equal("PreserveMe")
			expect(textLabel.Visible).to.equal(false)
			expect(textLabel.ZIndex).to.equal(12)
			expect(textLabel.LayoutOrder).to.equal(99)
			expect(textLabel.Rotation).to.equal(15)
			expect(textLabel.Text).to.equal("Keep text")
			expect(textLabel.TextColor3).to.equal(Color3.fromRGB(12, 34, 56))
			expect(corner.Parent).to.equal(textLabel)
			expect(result.frame.ClipsDescendants).to.equal(false)
		end)
	end)
end
