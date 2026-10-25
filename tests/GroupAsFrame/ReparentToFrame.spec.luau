--!nonstrict

local Geometry = require(script.Parent.Parent.Parent.plugins.GroupAsFrame.Geometry)
local GroupAsFrame = require(script.Parent.Parent.Parent.plugins.GroupAsFrame.GroupAsFrame)
local Helpers = require(script.Parent.TestHelpers)

local TOLERANCE = 0.75

local function expectReparentPreserved(expectFn, selection, targetFrame, objects)
	Helpers.settle()

	local before = Helpers.snapshot(objects)
	local targetBefore = {
		rect = Geometry.getAbsoluteRect(targetFrame),
		name = targetFrame.Name,
		parent = targetFrame.Parent,
		position = targetFrame.Position,
		size = targetFrame.Size,
		anchorPoint = targetFrame.AnchorPoint,
		automaticSize = targetFrame.AutomaticSize,
		clipsDescendants = targetFrame.ClipsDescendants,
		backgroundTransparency = targetFrame.BackgroundTransparency,
	}

	local result = GroupAsFrame.reparentToFrame(selection, targetFrame)
	Helpers.settle()

	expectFn(result.ok).to.equal(true)
	expectFn(result.frame).to.equal(targetFrame)
	Helpers.expectPreserved(expectFn, before, TOLERANCE)
	Helpers.expectRectClose(expectFn, Geometry.getAbsoluteRect(targetFrame), targetBefore.rect, TOLERANCE)

	expectFn(targetFrame.Name).to.equal(targetBefore.name)
	expectFn(targetFrame.Parent).to.equal(targetBefore.parent)
	expectFn(targetFrame.Position).to.equal(targetBefore.position)
	expectFn(targetFrame.Size).to.equal(targetBefore.size)
	expectFn(targetFrame.AnchorPoint).to.equal(targetBefore.anchorPoint)
	expectFn(targetFrame.AutomaticSize).to.equal(targetBefore.automaticSize)
	expectFn(targetFrame.ClipsDescendants).to.equal(targetBefore.clipsDescendants)
	expectFn(targetFrame.BackgroundTransparency).to.equal(targetBefore.backgroundTransparency)

	for _, object in objects do
		expectFn(object.Parent).to.equal(targetFrame)
	end

	return result, before
end

local function expectReparentUnscrolledPreserved(expectFn, selection, targetFrame, objects)
	Helpers.settle()

	local before = Helpers.snapshotUnscrolled(objects)
	local targetBefore = {
		rect = Geometry.getUnscrolledAbsoluteRect(targetFrame),
		name = targetFrame.Name,
		parent = targetFrame.Parent,
		position = targetFrame.Position,
		size = targetFrame.Size,
		anchorPoint = targetFrame.AnchorPoint,
		automaticSize = targetFrame.AutomaticSize,
		clipsDescendants = targetFrame.ClipsDescendants,
		backgroundTransparency = targetFrame.BackgroundTransparency,
	}

	local result = GroupAsFrame.reparentToFrame(selection, targetFrame)
	Helpers.settle()

	expectFn(result.ok).to.equal(true)
	expectFn(result.frame).to.equal(targetFrame)
	Helpers.expectUnscrolledPreserved(expectFn, before, TOLERANCE)
	Helpers.expectRectClose(expectFn, Geometry.getUnscrolledAbsoluteRect(targetFrame), targetBefore.rect, TOLERANCE)

	expectFn(targetFrame.Name).to.equal(targetBefore.name)
	expectFn(targetFrame.Parent).to.equal(targetBefore.parent)
	expectFn(targetFrame.Position).to.equal(targetBefore.position)
	expectFn(targetFrame.Size).to.equal(targetBefore.size)
	expectFn(targetFrame.AnchorPoint).to.equal(targetBefore.anchorPoint)
	expectFn(targetFrame.AutomaticSize).to.equal(targetBefore.automaticSize)
	expectFn(targetFrame.ClipsDescendants).to.equal(targetBefore.clipsDescendants)
	expectFn(targetFrame.BackgroundTransparency).to.equal(targetBefore.backgroundTransparency)

	for _, object in objects do
		expectFn(object.Parent).to.equal(targetFrame)
	end

	return result, before
end


local function expectReparentFailure(expectFn, selection, targetFrame, reason, objects)
	Helpers.settle()

	local parents = {}
	local before = Helpers.snapshot(objects or {})
	for _, object in objects or {} do
		parents[object] = object.Parent
	end

	local result = GroupAsFrame.reparentToFrame(selection, targetFrame)
	Helpers.settle()

	expectFn(result.ok).to.equal(false)
	expectFn(result.reason).to.equal(reason)
	expectFn(result.frame).to.equal(nil)

	for _, object in objects or {} do
		expectFn(object.Parent).to.equal(parents[object])
	end
	Helpers.expectPreserved(expectFn, before, TOLERANCE)

	return result
end

return function()
	describe("GroupAsFrame.reparentToFrame", function()
		local mountedScreens

		beforeEach(function()
			mountedScreens = {}
		end)

		afterEach(function()
			for _, screen in mountedScreens do
				Helpers.destroy(screen)
			end
			mountedScreens = nil
		end)

		local function mount(rootSize)
			local screen, root = Helpers.mountRoot(rootSize)
			table.insert(mountedScreens, screen)
			return root, screen
		end

		it("reparents a single object without changing the target frame", function()
			local root = mount()
			local target = Helpers.gui("Frame", root, {
				Name = "ExistingTarget",
				BackgroundTransparency = 0.35,
				ClipsDescendants = false,
				Position = UDim2.fromOffset(300, 50),
				Size = UDim2.fromOffset(240, 180),
			})
			local object = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(40, 70),
				Size = UDim2.fromOffset(120, 80),
			})

			local result = expectReparentPreserved(expect, { object }, target, { object })

			expect(#result.groupedObjects).to.equal(1)
			expect(object.Size.X.Offset).to.equal(0)
			expect(object.Size.Y.Offset).to.equal(0)
		end)

		it("handles multiple separated, overlapping, and negative-offset objects", function()
			local root = mount()
			local target = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(275, 190),
				Size = UDim2.fromOffset(300, 220),
			})
			local negative = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(-35, -20),
				Size = UDim2.fromOffset(90, 100),
			})
			local overlap = Helpers.gui("TextButton", root, {
				Position = UDim2.fromOffset(20, 35),
				Size = UDim2.fromOffset(130, 75),
				Text = "Overlap",
			})
			local separated = Helpers.gui("ImageLabel", root, {
				Position = UDim2.fromOffset(520, 420),
				Size = UDim2.fromOffset(75, 65),
				Image = "rbxassetid://0",
			})

			expectReparentPreserved(expect, { negative, overlap, separated }, target, { negative, overlap, separated })
		end)

		it("preserves offset-only, scale-only, and mixed UDim2 source objects", function()
			local root = mount()
			local target = Helpers.gui("Frame", root, {
				Position = UDim2.new(0.25, 15, 0.2, -10),
				Size = UDim2.new(0.45, 20, 0.35, 15),
			})
			local offsetOnly = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(50, 45),
				Size = UDim2.fromOffset(80, 70),
			})
			local scaleOnly = Helpers.gui("Frame", root, {
				Position = UDim2.fromScale(0.55, 0.25),
				Size = UDim2.fromScale(0.2, 0.18),
			})
			local mixed = Helpers.gui("TextLabel", root, {
				Position = UDim2.new(0.1, 25, 0.65, -30),
				Size = UDim2.new(0.25, -15, 0.12, 20),
				Text = "Mixed",
			})

			expectReparentPreserved(expect, { offsetOnly, scaleOnly, mixed }, target, { offsetOnly, scaleOnly, mixed })
			expect(scaleOnly.Position.X.Offset).to.equal(0)
			expect(mixed.Size.Y.Offset).to.equal(0)
		end)

		it("preserves mixed anchor points and edge-touching objects", function()
			local root = mount()
			local target = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(100, 100),
				Size = UDim2.fromOffset(300, 240),
			})
			local topLeft = Helpers.gui("Frame", root, {
				AnchorPoint = Vector2.zero,
				Position = UDim2.fromOffset(100, 100),
				Size = UDim2.fromOffset(50, 60),
			})
			local center = Helpers.gui("Frame", root, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(250, 220),
				Size = UDim2.fromOffset(80, 70),
			})
			local bottomRight = Helpers.gui("Frame", root, {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.fromOffset(400, 340),
				Size = UDim2.fromOffset(100, 90),
			})

			expectReparentPreserved(expect, { topLeft, center, bottomRight }, target, { topLeft, center, bottomRight })
			expect(center.AnchorPoint).to.equal(Vector2.new(0.5, 0.5))
			expect(bottomRight.AnchorPoint).to.equal(Vector2.new(1, 1))
		end)

		it("falls back to offsets on zero-size target axes", function()
			local root = mount()
			local target = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(200, 100),
				Size = UDim2.fromOffset(0, 240),
			})
			local object = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(260, 150),
				Size = UDim2.fromOffset(90, 70),
			})

			expectReparentPreserved(expect, { object }, target, { object })
			expect(object.Position.X.Scale).to.equal(0)
			expect(object.Size.X.Scale).to.equal(0)
			expect(object.Position.X.Offset).to.equal(60)
			expect(object.Size.X.Offset).to.equal(90)
		end)

		it("accounts for target anchor point, scale sizing, mixed offsets, and UIPadding", function()
			local root = mount()
			local target = Helpers.gui("Frame", root, {
				AnchorPoint = Vector2.new(0.5, 0.25),
				Position = UDim2.new(0.6, -20, 0.4, 35),
				Size = UDim2.new(0.35, 25, 0.3, 10),
			})
			local padding = Instance.new("UIPadding")
			padding.PaddingLeft = UDim.new(0.1, 5)
			padding.PaddingTop = UDim.new(0.05, 8)
			padding.PaddingRight = UDim.new(0, 12)
			padding.PaddingBottom = UDim.new(0, 9)
			padding.Parent = target
			local object = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(150, 210),
				Size = UDim2.fromOffset(110, 85),
			})

			expectReparentPreserved(expect, { object }, target, { object })
		end)

		it("uses top-of-canvas coordinates when reparenting into a target under a ScrollingFrame", function()
			local root = mount()
			local scaledContainer = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(60, 50),
				Size = UDim2.fromOffset(600, 460),
			})
			local scale = Instance.new("UIScale")
			scale.Scale = 1.2
			scale.Parent = scaledContainer

			local scroller = Helpers.gui("ScrollingFrame", scaledContainer, {
				CanvasSize = UDim2.fromOffset(900, 900),
				Position = UDim2.fromOffset(40, 60),
				Size = UDim2.fromOffset(360, 300),
			})
			local target = Helpers.gui("Frame", scroller, {
				Position = UDim2.fromOffset(180, 150),
				Size = UDim2.fromOffset(180, 150),
			})
			local object = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(400, 120),
				Size = UDim2.fromOffset(95, 85),
			})
			Helpers.settle()
			scroller.CanvasPosition = Vector2.new(45, 35)
			Helpers.settle()

			expectReparentUnscrolledPreserved(expect, { object }, target, { object })
		end)

		it("uses top-of-canvas coordinates when reparenting from a ScrollingFrame to an outside target", function()
			local root = mount()
			local scroller = Helpers.gui("ScrollingFrame", root, {
				CanvasSize = UDim2.fromOffset(1000, 1000),
				Position = UDim2.fromOffset(80, 70),
				Size = UDim2.fromOffset(340, 260),
			})
			local target = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(460, 160),
				Size = UDim2.fromOffset(220, 180),
			})
			local object = Helpers.gui("Frame", scroller, {
				Position = UDim2.fromOffset(180, 190),
				Size = UDim2.fromOffset(85, 65),
			})
			Helpers.settle()
			scroller.CanvasPosition = Vector2.new(35, 55)
			Helpers.settle()

			local result, before = expectReparentUnscrolledPreserved(expect, { object }, target, { object })
			expect(result.frame).to.equal(target)
			Helpers.expectRectClose(expect, Geometry.getAbsoluteRect(object), before[object], TOLERANCE)
		end)

		it("uses top-of-canvas coordinates through nested ScrollingFrames", function()
			local root = mount()
			local outer = Helpers.gui("ScrollingFrame", root, {
				CanvasSize = UDim2.fromOffset(1400, 1400),
				Position = UDim2.fromOffset(70, 60),
				Size = UDim2.fromOffset(520, 420),
			})
			local inner = Helpers.gui("ScrollingFrame", outer, {
				CanvasSize = UDim2.fromOffset(900, 900),
				Position = UDim2.fromOffset(210, 180),
				Size = UDim2.fromOffset(260, 220),
			})
			local target = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(500, 260),
				Size = UDim2.fromOffset(220, 180),
			})
			local object = Helpers.gui("Frame", inner, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(120, 110),
				Size = UDim2.fromOffset(90, 70),
			})
			Helpers.settle()
			outer.CanvasPosition = Vector2.new(25, 40)
			inner.CanvasPosition = Vector2.new(45, 30)
			Helpers.settle()

			expectReparentUnscrolledPreserved(expect, { object }, target, { object })
			expect(object.AnchorPoint).to.equal(Vector2.new(0.5, 0.5))
		end)

		it("uses top-of-canvas coordinates with scrolled target padding, anchors, mixed scale, and zero axes", function()
			local root = mount()
			local scroller = Helpers.gui("ScrollingFrame", root, {
				CanvasSize = UDim2.fromOffset(1000, 1000),
				Position = UDim2.fromOffset(100, 90),
				Size = UDim2.fromOffset(360, 280),
			})
			local target = Helpers.gui("Frame", scroller, {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 30, 0, 160),
				Size = UDim2.fromOffset(0, 180),
			})
			local padding = Instance.new("UIPadding")
			padding.PaddingLeft = UDim.new(0, 10)
			padding.PaddingTop = UDim.new(0.1, 4)
			padding.PaddingRight = UDim.new(0, 5)
			padding.PaddingBottom = UDim.new(0, 8)
			padding.Parent = target
			local object = Helpers.gui("Frame", root, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(0.4, 35, 0.5, -20),
				Size = UDim2.new(0.15, 10, 0, 80),
			})
			Helpers.settle()
			scroller.CanvasPosition = Vector2.new(20, 25)
			Helpers.settle()

			expectReparentUnscrolledPreserved(expect, { object }, target, { object })
			expect(object.Position.X.Scale).to.equal(0)
			expect(object.Size.X.Scale).to.equal(0)
		end)

		it("reparents across different ScreenGuis", function()
			local sourceRoot = mount()
			local targetRoot = mount()
			local target = Helpers.gui("Frame", targetRoot, {
				Position = UDim2.fromOffset(250, 100),
				Size = UDim2.fromOffset(260, 220),
			})
			local object = Helpers.gui("Frame", sourceRoot, {
				Position = UDim2.fromOffset(75, 90),
				Size = UDim2.fromOffset(120, 95),
			})

			expectReparentPreserved(expect, { object }, target, { object })
		end)

		it("preserves objects originally controlled by list and grid layouts", function()
			local root = mount()
			local target = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(430, 70),
				Size = UDim2.fromOffset(300, 300),
			})
			local listParent = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(40, 50),
				Size = UDim2.fromOffset(170, 260),
			})
			local listLayout = Instance.new("UIListLayout")
			listLayout.Padding = UDim.new(0, 6)
			listLayout.SortOrder = Enum.SortOrder.LayoutOrder
			listLayout.Parent = listParent
			local listItem = Helpers.gui("Frame", listParent, {
				LayoutOrder = 1,
				Size = UDim2.fromOffset(120, 45),
			})

			local gridParent = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(230, 70),
				Size = UDim2.fromOffset(170, 170),
			})
			local gridLayout = Instance.new("UIGridLayout")
			gridLayout.CellSize = UDim2.fromOffset(70, 50)
			gridLayout.CellPadding = UDim2.fromOffset(8, 10)
			gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
			gridLayout.Parent = gridParent
			local gridItem = Helpers.gui("Frame", gridParent, {
				LayoutOrder = 2,
			})

			expectReparentPreserved(expect, { listItem, gridItem }, target, { listItem, gridItem })
		end)

		it("preserves constraints, automatic-size children, own UIScale, and visual properties", function()
			local root = mount()
			local target = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(320, 160),
				Size = UDim2.fromOffset(320, 260),
			})
			local constrained = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(40, 70),
				Size = UDim2.fromOffset(140, 100),
				Visible = false,
				ZIndex = 15,
				LayoutOrder = 44,
				Rotation = 12,
			})
			local sizeConstraint = Instance.new("UISizeConstraint")
			sizeConstraint.MinSize = Vector2.new(80, 70)
			sizeConstraint.MaxSize = Vector2.new(220, 200)
			sizeConstraint.Parent = constrained
			local ownScale = Instance.new("UIScale")
			ownScale.Scale = 0.75
			ownScale.Parent = constrained

			local aspect = Helpers.gui("ImageLabel", root, {
				Position = UDim2.fromOffset(205, 90),
				Size = UDim2.fromOffset(150, 75),
				Image = "rbxassetid://0",
			})
			local aspectConstraint = Instance.new("UIAspectRatioConstraint")
			aspectConstraint.AspectRatio = 2
			aspectConstraint.Parent = aspect

			local automatic = Helpers.gui("TextLabel", root, {
				AutomaticSize = Enum.AutomaticSize.XY,
				Position = UDim2.fromOffset(100, 250),
				Size = UDim2.fromOffset(20, 20),
				Text = "Automatic",
				TextSize = 22,
				TextColor3 = Color3.fromRGB(10, 20, 30),
			})

			expectReparentPreserved(expect, { constrained, aspect, automatic }, target, { constrained, aspect, automatic })
			expect(constrained.Visible).to.equal(false)
			expect(constrained.ZIndex).to.equal(15)
			expect(constrained.LayoutOrder).to.equal(44)
			expect(constrained.Rotation).to.equal(12)
			expect(sizeConstraint.Parent).to.equal(constrained)
			expect(ownScale.Parent).to.equal(constrained)
			expect(aspectConstraint.Parent).to.equal(aspect)
			expect(automatic.Text).to.equal("Automatic")
			expect(automatic.TextColor3).to.equal(Color3.fromRGB(10, 20, 30))
		end)

		it("handles objects already inside the target and collapses nested selections", function()
			local root = mount()
			local target = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(100, 120),
				Size = UDim2.fromOffset(300, 260),
			})
			local parent = Helpers.gui("Frame", target, {
				Position = UDim2.fromOffset(40, 50),
				Size = UDim2.fromOffset(120, 100),
			})
			local child = Helpers.gui("Frame", parent, {
				Position = UDim2.fromOffset(20, 25),
				Size = UDim2.fromOffset(50, 40),
			})

			local result = expectReparentPreserved(expect, { target, parent, child }, target, { parent })
			expect(#result.groupedObjects).to.equal(1)
			expect(child.Parent).to.equal(parent)
		end)

		it("preserves absolute rects when the unchanged target clips descendants", function()
			local root = mount()
			local target = Helpers.gui("Frame", root, {
				ClipsDescendants = true,
				Position = UDim2.fromOffset(300, 240),
				Size = UDim2.fromOffset(140, 120),
			})
			local object = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(80, 90),
				Size = UDim2.fromOffset(100, 80),
			})

			expectReparentPreserved(expect, { object }, target, { object })
			expect(target.ClipsDescendants).to.equal(true)
		end)

		it("ignores non-GuiObject selections while reparenting valid objects", function()
			local root = mount()
			local folder = Instance.new("Folder")
			local target = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(250, 100),
				Size = UDim2.fromOffset(200, 160),
			})
			local object = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(40, 50),
				Size = UDim2.fromOffset(80, 90),
			})

			local result = expectReparentPreserved(expect, { folder, object }, target, { object })
			expect(#result.ignored).to.equal(1)
			folder:Destroy()
		end)

		it("fails cleanly for empty, non-UI-only, and target-only selections", function()
			local root = mount()
			local target = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(150, 100),
				Size = UDim2.fromOffset(200, 160),
			})
			local folder = Instance.new("Folder")

			expectReparentFailure(expect, {}, target, "NoGuiObjects", {})
			local nonUi = expectReparentFailure(expect, { folder }, target, "NoGuiObjects", {})
			expect(#nonUi.ignored).to.equal(1)
			expectReparentFailure(expect, { target }, target, "NoGuiObjects", {})
			folder:Destroy()
		end)

		it("reparents into ImageLabel, TextLabel, ImageButton, and TextButton targets", function()
			local root = mount()
			local targets = {
				Helpers.gui("ImageLabel", root, {
					Position = UDim2.fromOffset(300, 40),
					Size = UDim2.fromOffset(200, 150),
				}),
				Helpers.gui("TextLabel", root, {
					Position = UDim2.fromOffset(520, 40),
					Size = UDim2.fromOffset(220, 160),
					Text = "Target",
				}),
				Helpers.gui("ImageButton", root, {
					Position = UDim2.fromOffset(300, 260),
					Size = UDim2.fromOffset(240, 180),
				}),
				Helpers.gui("TextButton", root, {
					Position = UDim2.fromOffset(560, 260),
					Size = UDim2.fromOffset(180, 200),
					Text = "Target",
				}),
			}

			for index, target in targets do
				local object = Helpers.gui("Frame", root, {
					Position = UDim2.fromOffset(20, 30 + (index - 1) * 110),
					Size = UDim2.fromOffset(110, 70),
				})

				local result = expectReparentPreserved(expect, { object }, target, { object })
				expect(result.frame.ClassName).to.equal(target.ClassName)
			end
		end)

		it("fails cleanly for missing, destroyed, and non-GuiObject targets", function()
			local root = mount()
			local object = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(30, 40),
				Size = UDim2.fromOffset(70, 80),
			})
			local folderTarget = Instance.new("Folder")
			folderTarget.Parent = root
			local destroyedTarget = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(200, 180),
				Size = UDim2.fromOffset(100, 100),
			})
			destroyedTarget:Destroy()

			expectReparentFailure(expect, { object }, nil, "NoTargetFrame", { object })
			expectReparentFailure(expect, { object }, destroyedTarget, "InvalidTargetFrame", { object })
			expectReparentFailure(expect, { object }, folderTarget, "InvalidTargetFrame", { object })
			expectReparentFailure(expect, { object }, root.Parent, "InvalidTargetFrame", { object })
		end)

		it("fails cleanly when a selected object is an ancestor of the target", function()
			local root = mount()
			local container = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(80, 90),
				Size = UDim2.fromOffset(360, 300),
			})
			local target = Helpers.gui("Frame", container, {
				Position = UDim2.fromOffset(40, 50),
				Size = UDim2.fromOffset(160, 120),
			})

			expectReparentFailure(expect, { container }, target, "TargetDescendantOfSelection", { container })
		end)

		it("fails cleanly for target frames that can change child layout", function()
			local root = mount()
			local object = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(35, 45),
				Size = UDim2.fromOffset(90, 70),
			})
			local automaticTarget = Helpers.gui("Frame", root, {
				AutomaticSize = Enum.AutomaticSize.XY,
				Position = UDim2.fromOffset(200, 80),
				Size = UDim2.fromOffset(150, 120),
			})
			local layoutTarget = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(410, 80),
				Size = UDim2.fromOffset(180, 140),
			})
			local layout = Instance.new("UIListLayout")
			layout.Parent = layoutTarget

			expectReparentFailure(expect, { object }, automaticTarget, "TargetAutomaticSize", { object })
			expectReparentFailure(expect, { object }, layoutTarget, "TargetHasLayout", { object })
		end)

		it("picks an existing GuiObject target only from an exact single selection", function()
			local root = mount()
			local frame = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(10, 20),
				Size = UDim2.fromOffset(100, 80),
			})
			local otherFrame = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(150, 20),
				Size = UDim2.fromOffset(100, 80),
			})
			local textLabel = Helpers.gui("TextLabel", root, {
				Position = UDim2.fromOffset(20, 130),
				Size = UDim2.fromOffset(100, 40),
				Text = "Label target",
			})

			local ok, picked, reason = GroupAsFrame.pickTargetFrame({ frame })
			expect(ok).to.equal(true)
			expect(picked).to.equal(frame)
			expect(reason).to.equal(nil)

			local emptyOk, _, emptyReason = GroupAsFrame.pickTargetFrame({})
			expect(emptyOk).to.equal(false)
			expect(emptyReason).to.equal("NoTargetFrame")

			local manyOk, _, manyReason = GroupAsFrame.pickTargetFrame({ frame, otherFrame })
			expect(manyOk).to.equal(false)
			expect(manyReason).to.equal("AmbiguousTargetFrame")

			local labelOk, labelPicked, labelReason = GroupAsFrame.pickTargetFrame({ textLabel })
			expect(labelOk).to.equal(true)
			expect(labelPicked).to.equal(textLabel)
			expect(labelReason).to.equal(nil)

			local folder = Instance.new("Folder")
			folder.Parent = root
			local folderOk, _, folderReason = GroupAsFrame.pickTargetFrame({ folder })
			expect(folderOk).to.equal(false)
			expect(folderReason).to.equal("InvalidTargetFrame")
		end)
	end)
end
