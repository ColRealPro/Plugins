--!nonstrict

local CoreGui = game:GetService("CoreGui")

local React = require(script.Parent.Packages.React)
local ReactRoblox = require(script.Parent.Packages.ReactRoblox)

local App = require(script.App)
local Types = require(script.Types)

export type Kind = Types.Kind

export type Options = {
	kind: Kind?,
	duration: number?,
}

export type Notifications = {
	notify: (text: string, options: Options?) -> (),
	destroy: () -> (),
}

-- The same notification sound Rojo uses
local SOUND_ID = "rbxassetid://203785492"
-- A few copies take turns so quick notifications overlap instead of cutting each other off
local SOUND_COUNT = 4

local MAX_VISIBLE = 5
-- Closing notifications stay mounted while they animate out, this stops a burst from piling them up
-- Kept well above MAX_VISIBLE so normal spamming never hits it and cards always get to animate out
local MAX_MOUNTED = MAX_VISIBLE * 4

local DEFAULT_DURATIONS: { [Kind]: number } = {
	info = 3.5,
	success = 3.5,
	warning = 5,
	error = 6,
}

local Notifications = {}

function Notifications.new(plugin: Plugin, icon: string): Notifications
	local root = ReactRoblox.createRoot(Instance.new("Folder"))
	local active: { Types.Notification } = {}
	local nextId = 0
	local destroyed = false

	-- Sounds only play in Edit mode when parented to a plugin widget, so this one stays hidden and just holds them
	local soundPlayer = plugin:CreateDockWidgetPluginGuiAsync(
		"GroupAsFrameSoundPlayer",
		DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, true, 10, 10, 10, 10)
	)
	soundPlayer.Name = "GroupAsFrameSoundPlayer"
	soundPlayer.Title = "Group As Frame Sound Player"

	-- Created once and reused so the asset only loads once
	local sounds: { Sound } = {}
	for index = 1, SOUND_COUNT do
		local sound = Instance.new("Sound")
		sound.Name = `Notification{index}`
		sound.SoundId = SOUND_ID
		sound.Parent = soundPlayer
		sounds[index] = sound
	end
	local nextSound = 1

	local function playSound()
		local sound = sounds[nextSound]
		nextSound = nextSound % SOUND_COUNT + 1
		sound.TimePosition = 0
		sound:Play()
	end

	local render: () -> ()

	local function dismiss(id: number)
		for index, notification in active do
			if notification.id == id then
				table.remove(active, index)
				render()
				return
			end
		end
	end

	function render()
		if destroyed then
			return
		end

		root:render(ReactRoblox.createPortal({
			GroupAsFrameNotifications = React.createElement(App, {
				icon = icon,
				notifications = table.clone(active),
				onDismiss = dismiss,
			}),
		}, CoreGui))
	end

	local function notify(text: string, options: Options?)
		if destroyed then
			return
		end

		local kind: Kind = if options and options.kind then options.kind else "info"
		nextId += 1
		table.insert(active, {
			id = nextId,
			text = text,
			kind = kind,
			duration = if options and options.duration then options.duration else DEFAULT_DURATIONS[kind],
			dismissed = false,
		})
		playSound()

		-- Close the oldest ones past the limit so they animate out instead of vanishing
		local open = 0
		for index = #active, 1, -1 do
			local notification = active[index]
			if not notification.dismissed then
				open += 1
				if open > MAX_VISIBLE then
					notification.dismissed = true
				end
			end
		end

		while #active > MAX_MOUNTED do
			table.remove(active, 1)
		end

		render()
	end

	local function destroy()
		if destroyed then
			return
		end

		destroyed = true
		table.clear(active)
		root:unmount()
		soundPlayer:Destroy()
	end

	return {
		notify = notify,
		destroy = destroy,
	}
end

return Notifications
