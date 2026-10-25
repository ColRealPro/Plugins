--!nonstrict

local React = require(script.Parent.Parent.Packages.React)

local useEventConnection = require(script.Parent.useEventConnection)

export type Theme = {
	background: Color3,
	border: Color3,
	text: Color3,
}

local function getTheme(): Theme
	local studioTheme = settings().Studio.Theme
	return {
		background = studioTheme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
		border = studioTheme:GetColor(Enum.StudioStyleGuideColor.Border),
		text = studioTheme:GetColor(Enum.StudioStyleGuideColor.MainText),
	}
end

-- Follows Studio's light and dark themes
local function useTheme(): Theme
	local theme, setTheme = React.useState(getTheme)

	useEventConnection(settings().Studio.ThemeChanged, function()
		setTheme(getTheme())
	end, {})

	return theme
end

return useTheme
