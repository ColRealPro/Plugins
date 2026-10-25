--!nonstrict

local React = require(script.Parent.Parent.Packages.React)

local Notification = require(script.Parent.Notification)
local Types = require(script.Parent.Types)
local useTheme = require(script.Parent.useTheme)

local e = React.createElement

export type Props = {
	icon: string,
	notifications: { Types.Notification },
	onDismiss: (id: number) -> (),
}

local function App(props: Props)
	local theme = useTheme()

	local children: { [string]: any } = {
		Layout = e("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
		}),
		-- Each notification carries its own gap below it, so the bottom padding is a little smaller
		Padding = e("UIPadding", {
			PaddingRight = UDim.new(0, 16),
			PaddingBottom = UDim.new(0, 8),
		}),
	}

	for _, notification in props.notifications do
		local id = notification.id
		-- Keyed by id so React keeps each card's animation state as others come and go
		children[`Notification{id}`] = e(Notification, {
			layoutOrder = id,
			icon = props.icon,
			text = notification.text,
			kind = notification.kind,
			duration = notification.duration,
			dismissed = notification.dismissed,
			theme = theme,
			onDismiss = function()
				props.onDismiss(id)
			end,
		})
	end

	return e("ScreenGui", {
		DisplayOrder = 100,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, {
		Container = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}, children),
	})
end

return App
