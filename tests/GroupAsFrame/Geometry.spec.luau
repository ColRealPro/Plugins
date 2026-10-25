--!nonstrict

local Geometry = require(script.Parent.Parent.Parent.plugins.GroupAsFrame.Geometry)
local Helpers = require(script.Parent.TestHelpers)

return function()
	describe("Geometry", function()
		it("calculates bounds for one rect", function()
			local rect = {
				position = Vector2.new(12, 34),
				size = Vector2.new(56, 78),
			}

			Helpers.expectRectClose(expect, Geometry.getBounds({ rect }), rect)
		end)

		it("calculates bounds for separated, overlapping, and negative rects", function()
			local bounds = Geometry.getBounds({
				{ position = Vector2.new(50, 70), size = Vector2.new(100, 40) },
				{ position = Vector2.new(-20, 90), size = Vector2.new(30, 60) },
				{ position = Vector2.new(80.5, 20.25), size = Vector2.new(200.5, 300.75) },
			})

			Helpers.expectRectClose(expect, bounds, {
				position = Vector2.new(-20, 20.25),
				size = Vector2.new(301, 300.75),
			})
		end)

		it("converts absolute size and position to scale when parent axes are nonzero", function()
			local parentRect = {
				position = Vector2.new(10, 20),
				size = Vector2.new(800, 400),
			}

			local position, size = Geometry.rectToUDim2({
				position = Vector2.new(210, 120),
				size = Vector2.new(200, 100),
			}, Vector2.zero, parentRect, Enum.SizeConstraint.RelativeXY)

			Helpers.expectNumberClose(expect, position.X.Scale, 0.25)
			Helpers.expectNumberClose(expect, position.Y.Scale, 0.25)
			expect(position.X.Offset).to.equal(0)
			expect(position.Y.Offset).to.equal(0)
			Helpers.expectNumberClose(expect, size.X.Scale, 0.25)
			Helpers.expectNumberClose(expect, size.Y.Scale, 0.25)
			expect(size.X.Offset).to.equal(0)
			expect(size.Y.Offset).to.equal(0)
		end)

		it("falls back to offsets when a parent axis is zero", function()
			local parentRect = {
				position = Vector2.new(10, 20),
				size = Vector2.new(0, 400),
			}

			local position, size = Geometry.rectToUDim2({
				position = Vector2.new(210, 120),
				size = Vector2.new(200, 100),
			}, Vector2.zero, parentRect, Enum.SizeConstraint.RelativeXY)

			expect(position.X.Scale).to.equal(0)
			expect(position.X.Offset).to.equal(200)
			expect(size.X.Scale).to.equal(0)
			expect(size.X.Offset).to.equal(200)
			Helpers.expectNumberClose(expect, position.Y.Scale, 0.25)
			Helpers.expectNumberClose(expect, size.Y.Scale, 0.25)
		end)

		it("positions anchored objects by their absolute anchor point", function()
			local parentRect = {
				position = Vector2.new(0, 0),
				size = Vector2.new(400, 400),
			}

			local position = Geometry.rectToPositionUDim2({
				position = Vector2.new(50, 75),
				size = Vector2.new(100, 150),
			}, Vector2.new(0.5, 1), parentRect)

			Helpers.expectNumberClose(expect, position.X.Scale, 0.25)
			Helpers.expectNumberClose(expect, position.Y.Scale, 0.5625)
		end)

		it("uses RelativeXX and RelativeYY size bases", function()
			local parentSize = Vector2.new(500, 250)

			local relativeXX = Geometry.sizeToUDim2(Vector2.new(100, 50), parentSize, Enum.SizeConstraint.RelativeXX)
			Helpers.expectNumberClose(expect, relativeXX.X.Scale, 0.2)
			Helpers.expectNumberClose(expect, relativeXX.Y.Scale, 0.1)

			local relativeYY = Geometry.sizeToUDim2(Vector2.new(100, 50), parentSize, Enum.SizeConstraint.RelativeYY)
			Helpers.expectNumberClose(expect, relativeYY.X.Scale, 0.4)
			Helpers.expectNumberClose(expect, relativeYY.Y.Scale, 0.2)
		end)

		it("compensates for direct UIScale when calculating size values", function()
			local frame = Instance.new("Frame")
			local uiScale = Instance.new("UIScale")
			uiScale.Scale = 2
			uiScale.Parent = frame

			local _, size = Geometry.rectToUDim2({
				position = Vector2.new(0, 0),
				size = Vector2.new(200, 100),
			}, Vector2.zero, {
				position = Vector2.new(0, 0),
				size = Vector2.new(400, 400),
			}, Enum.SizeConstraint.RelativeXY, Geometry.getDirectUIScale(frame))

			Helpers.expectNumberClose(expect, size.X.Scale, 0.25)
			Helpers.expectNumberClose(expect, size.Y.Scale, 0.125)
			frame:Destroy()
		end)

		it("calculates child coordinate rects with UIPadding", function()
			local screen, root = Helpers.mountRoot()
			local padding = Instance.new("UIPadding")
			padding.PaddingLeft = UDim.new(0.1, 5)
			padding.PaddingRight = UDim.new(0, 25)
			padding.PaddingTop = UDim.new(0.05, 10)
			padding.PaddingBottom = UDim.new(0, 30)
			padding.Parent = root

			local rect = Geometry.getChildCoordinateRect(root)

			Helpers.expectRectClose(expect, rect, {
				position = Vector2.new(85, 40),
				size = Vector2.new(690, 530),
			})

			screen:Destroy()
		end)

		it("clamps padded child coordinate origins when padding exceeds an axis", function()
			local screen, root = Helpers.mountRoot()
			local target = Helpers.gui("Frame", root, {
				Position = UDim2.fromOffset(100, 100),
				Size = UDim2.fromOffset(0, 120),
			})
			local padding = Instance.new("UIPadding")
			padding.PaddingLeft = UDim.new(0, 10)
			padding.PaddingRight = UDim.new(0, 5)
			padding.PaddingTop = UDim.new(0, 20)
			padding.PaddingBottom = UDim.new(0, 8)
			padding.Parent = target
			Helpers.settle()

			local rect = Geometry.getChildCoordinateRect(target)

			Helpers.expectRectClose(expect, rect, {
				position = Vector2.new(95, 120),
				size = Vector2.new(0, 92),
			})

			screen:Destroy()
		end)

		it("calculates unscrolled child coordinate rects for ScrollingFrames", function()
			local screen, root = Helpers.mountRoot()
			local scrollingFrame = Helpers.gui("ScrollingFrame", root, {
				CanvasSize = UDim2.fromOffset(1200, 1200),
				Position = UDim2.fromOffset(100, 120),
				Size = UDim2.fromOffset(300, 200),
			})
			Helpers.settle()
			scrollingFrame.CanvasPosition = Vector2.new(50, 70)
			Helpers.settle()

			local rect = Geometry.getUnscrolledChildCoordinateRect(scrollingFrame)

			Helpers.expectRectClose(expect, rect, {
				position = Vector2.new(100, 120),
				size = Vector2.new(1200, 1200),
			})

			screen:Destroy()
		end)

		it("applies UIPadding to unscrolled ScrollingFrame child coordinate rects", function()
			local screen, root = Helpers.mountRoot()
			local scrollingFrame = Helpers.gui("ScrollingFrame", root, {
				CanvasSize = UDim2.fromOffset(1200, 1200),
				Position = UDim2.fromOffset(100, 120),
				Size = UDim2.fromOffset(300, 200),
			})
			local padding = Instance.new("UIPadding")
			padding.PaddingLeft = UDim.new(0.1, 5)
			padding.PaddingRight = UDim.new(0, 12)
			padding.PaddingTop = UDim.new(0.05, 10)
			padding.PaddingBottom = UDim.new(0, 8)
			padding.Parent = scrollingFrame
			Helpers.settle()
			scrollingFrame.CanvasPosition = Vector2.new(50, 70)
			Helpers.settle()

			local rect = Geometry.getUnscrolledChildCoordinateRect(scrollingFrame)

			Helpers.expectRectClose(expect, rect, {
				position = Vector2.new(135, 140),
				size = Vector2.new(1153, 1172),
			})

			screen:Destroy()
		end)

		it("adds ancestor CanvasPosition values for unscrolled absolute rects", function()
			local screen, root = Helpers.mountRoot()
			local outer = Helpers.gui("ScrollingFrame", root, {
				CanvasSize = UDim2.fromOffset(1600, 1600),
				Position = UDim2.fromOffset(100, 80),
				Size = UDim2.fromOffset(500, 400),
			})
			local inner = Helpers.gui("ScrollingFrame", outer, {
				CanvasSize = UDim2.fromOffset(1000, 1000),
				Position = UDim2.fromOffset(250, 220),
				Size = UDim2.fromOffset(240, 180),
			})
			local child = Helpers.gui("Frame", inner, {
				Position = UDim2.fromOffset(90, 100),
				Size = UDim2.fromOffset(70, 60),
			})
			Helpers.settle()
			outer.CanvasPosition = Vector2.new(20, 30)
			inner.CanvasPosition = Vector2.new(40, 50)
			Helpers.settle()

			Helpers.expectVectorClose(expect, Geometry.getScrollOffset(child), Vector2.new(60, 80))
			Helpers.expectRectClose(expect, Geometry.getUnscrolledAbsoluteRect(child), {
				position = Vector2.new(440, 400),
				size = Vector2.new(70, 60),
			})

			screen:Destroy()
		end)
	end)
end
