--!nonstrict

local TextService = game:GetService("TextService")

local React = require(script.Parent.Parent.Packages.React)
local ReactFlow = require(script.Parent.Parent.ReactFlow)

local Types = require(script.Parent.Types)
local useTheme = require(script.Parent.useTheme)

local e = React.createElement

local FONT = Enum.Font.BuilderSans
local TEXT_SIZE = 16
local MAX_TEXT_WIDTH = 280
local ICON_SIZE = 24
local ICON_GAP = 10
local PADDING_X = 12
local PADDING_Y = 10
local GAP = 8
local SLIDE_DISTANCE = 40
-- Close enough to hidden to remove, the spring settles within 0.01 of its goal
local HIDDEN_THRESHOLD = 0.02

local KIND_COLORS: { [Types.Kind]: Color3 } = {
	info = Color3.fromRGB(0, 162, 255),
	success = Color3.fromRGB(65, 190, 110),
	warning = Color3.fromRGB(255, 180, 50),
	error = Color3.fromRGB(235, 75, 75),
}

export type Props = {
	layoutOrder: number,
	icon: string,
	text: string,
	kind: Types.Kind,
	duration: number,
	dismissed: boolean,
	theme: useTheme.Theme,
	onDismiss: () -> (),
}

local function Notification(props: Props)
	-- Presence drives the slot height and slide, opacity drives the fade
	-- Both are critically damped so they never overshoot, which keeps the motion clean
	local presence, setPresence = ReactFlow.useSpring({
		start = 0,
		target = 0,
		speed = 20,
		damper = 1,
	})
	local opacity, setOpacity = ReactFlow.useSpring({
		start = 0,
		target = 0,
		speed = 20,
		damper = 1,
	})
	local closing, setClosing = React.useState(false)
	local hovered, setHovered = React.useState(false)
	local collapsing = React.useRef(false)

	-- The controller can also close a notification, for example when too many are open
	local leaving = closing or props.dismissed

	-- Measured up front so the card has a fixed size to slide and collapse with
	local textSize = React.useMemo(function()
		local size = TextService:GetTextSize(props.text, TEXT_SIZE, FONT, Vector2.new(MAX_TEXT_WIDTH, math.huge))
		-- Rounded up with a pixel spare so the label never wraps differently than measured
		return Vector2.new(math.ceil(size.X) + 1, math.ceil(size.Y))
	end, { props.text })
	local cardSize = Vector2.new(
		PADDING_X + ICON_SIZE + ICON_GAP + textSize.X + PADDING_X,
		PADDING_Y + math.max(ICON_SIZE, textSize.Y) + PADDING_Y
	)

	-- Enters by sliding in and fading up together
	React.useEffect(function()
		setPresence({ target = 1 })
		setOpacity({ target = 1 })
	end, {})

	-- Leaves by fading out in place first, then the empty slot collapses
	React.useEffect(function()
		if leaving then
			setOpacity({ target = 0 })
		end
	end, { leaving })

	ReactFlow.useBindings(function(opacityValue: number, presenceValue: number)
		if not leaving then
			return
		end

		if not collapsing.current and opacityValue < HIDDEN_THRESHOLD then
			collapsing.current = true
			-- Deferred because this runs inside ReactFlow's spring loop, and starting a spring there edits the table it is iterating
			task.defer(setPresence, { target = 0 })
		elseif collapsing.current and presenceValue < HIDDEN_THRESHOLD then
			props.onDismiss()
		end
	end, { opacity, presence }, { leaving })

	-- Hovering pauses the timeout so longer messages can be read
	React.useEffect(function()
		local thread = nil
		if not leaving and not hovered then
			thread = task.delay(props.duration, function()
				setClosing(true)
			end)
		end

		return function()
			if thread then
				task.cancel(thread)
			end
		end
	end, { leaving, hovered, props.duration })

	local theme = props.theme
	local transparency = opacity:map(function(value)
		return 1 - (value or 0)
	end)

	-- The wrapper grows and shrinks with presence so the rest of the stack moves smoothly
	return e("Frame", {
		LayoutOrder = props.layoutOrder,
		BackgroundTransparency = 1,
		Size = presence:map(function(value)
			return UDim2.fromOffset(cardSize.X, (cardSize.Y + GAP) * (value or 0))
		end),
	}, {
		Card = e("TextButton", {
			-- Only noticeable on the way in, by the time the slot collapses the card is already invisible
			Position = presence:map(function(value)
				return UDim2.fromOffset((1 - (value or 0)) * SLIDE_DISTANCE, 0)
			end),
			Size = UDim2.fromOffset(cardSize.X, cardSize.Y),
			BackgroundColor3 = theme.background,
			BackgroundTransparency = transparency,
			AutoButtonColor = false,
			Text = "",
			[React.Event.Activated] = function()
				setClosing(true)
			end,
			[React.Event.MouseEnter] = function()
				setHovered(true)
			end,
			[React.Event.MouseLeave] = function()
				setHovered(false)
			end,
		}, {
			Corner = e("UICorner", {
				CornerRadius = UDim.new(0, 6),
			}),
			Stroke = e("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = theme.border,
				Transparency = transparency,
			}),

			Icon = e("ImageLabel", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, PADDING_X, 0.5, 0),
				Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
				BackgroundTransparency = 1,
				Image = props.icon,
				ImageTransparency = transparency,
			}, {
				-- Small status dot in the corner of the plugin icon shows the kind of notification
				Badge = e("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(1, -2, 1, -2),
					Size = UDim2.fromOffset(10, 10),
					BackgroundColor3 = KIND_COLORS[props.kind],
					BackgroundTransparency = transparency,
				}, {
					Corner = e("UICorner", {
						CornerRadius = UDim.new(1, 0),
					}),
					Stroke = e("UIStroke", {
						Color = theme.background,
						Thickness = 2,
						Transparency = transparency,
					}),
				}),
			}),

			Message = e("TextLabel", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, PADDING_X + ICON_SIZE + ICON_GAP, 0.5, 0),
				Size = UDim2.fromOffset(textSize.X, textSize.Y),
				BackgroundTransparency = 1,
				Font = FONT,
				Text = props.text,
				TextColor3 = theme.text,
				TextTransparency = transparency,
				TextSize = TEXT_SIZE,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		}),
	})
end

return Notification
