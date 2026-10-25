--!strict

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")

local GroupAsFrame = require(script.GroupAsFrame)
local Notifications = require(script.Notifications)

local ICON = "rbxassetid://131620670327497"

local toolbar = plugin:CreateToolbar("Group As Frame")
local button = toolbar:CreateButton(
	"GroupAsFrame",
	"Group selected UI objects into an invisible frame",
	ICON,
	"Group as Frame"
)
local setTargetButton = toolbar:CreateButton(
	"SetReparentTargetFrame",
	"Use the selected GUI object, like a Frame, ImageLabel, or TextButton, as the reparent target",
	ICON,
	"Set Target"
)
local reparentButton = toolbar:CreateButton(
	"ReparentToTargetFrame",
	"Reparent selected UI objects to the target GUI object",
	ICON,
	"Reparent UI"
)

button.ClickableWhenViewportHidden = true
setTargetButton.ClickableWhenViewportHidden = true
reparentButton.ClickableWhenViewportHidden = true

local notifications = Notifications.new(plugin, ICON)
plugin.Unloading:Connect(notifications.destroy)

local targetFrame: GuiObject? = nil
local targetFrameConnection: RBXScriptConnection? = nil

local function pluralize(count: number, noun: string): string
	return `{count} {noun}{if count == 1 then "" else "s"}`
end

local function notifyIgnoredObjects(count: number)
	if count > 0 then
		notifications.notify(
			`Ignored {pluralize(count, "selected instance")} that {if count == 1 then "is" else "are"} not UI objects`,
			{ kind = "warning" }
		)
	end
end

local function notifyFailure(reason: GroupAsFrame.FailureReason?)
	notifications.notify(GroupAsFrame.getFailureMessage(reason), { kind = "error" })
end

local function notifyUnexpectedError(action: string, message: any)
	-- Keep the full error in Output since it points at a bug rather than a bad selection
	warn(`[Group as Frame] Failed while {action}: {tostring(message)}`)
	notifications.notify(`Something went wrong while {action}, see Output for details`, {
		kind = "error",
	})
end

local function notifyRecordingFailed()
	notifications.notify("Could not start an undo recording, so no changes were made", { kind = "error" })
end

local function clearTargetFrame()
	if targetFrameConnection ~= nil then
		targetFrameConnection:Disconnect()
		targetFrameConnection = nil
	end

	targetFrame = nil
	setTargetButton:SetActive(false)
end

local function setTargetFrame(frame: GuiObject)
	clearTargetFrame()
	targetFrame = frame
	targetFrameConnection = frame.AncestryChanged:Connect(function()
		if frame.Parent == nil then
			clearTargetFrame()
			notifications.notify(`Reparent target "{frame.Name}" was removed, so it has been cleared`)
		end
	end)
	setTargetButton:SetActive(true)
end

button.Click:Connect(function()
	local prepared = GroupAsFrame.prepare(Selection:Get())
	if not prepared.ok then
		notifyFailure(prepared.reason)
		return
	end

	notifyIgnoredObjects(#prepared.ignored)

	local recording = ChangeHistoryService:TryBeginRecording("GroupAsFrame", "Group as Frame")
	if recording == nil then
		notifyRecordingFailed()
		return
	end

	local ok, result = pcall(function()
		return GroupAsFrame.apply(prepared)
	end)

	if ok and result.ok and result.frame ~= nil then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
		Selection:Set({ result.frame })
		notifications.notify(
			`Grouped {pluralize(#result.groupedObjects, "object")} into "{result.frame.Name}"`,
			{ kind = "success" }
		)
	else
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Cancel)

		if ok then
			notifyFailure(result.reason)
		else
			notifyUnexpectedError("grouping", result)
		end
	end
end)

setTargetButton.Click:Connect(function()
	local ok, frame, reason = GroupAsFrame.pickTargetFrame(Selection:Get())
	if not ok or frame == nil then
		notifyFailure(reason)
		return
	end

	setTargetFrame(frame)
	notifications.notify(`Reparent target set to "{frame.Name}"`, { kind = "success" })
end)

reparentButton.Click:Connect(function()
	if targetFrame == nil then
		notifyFailure("NoTargetFrame")
		return
	end

	if targetFrame.Parent == nil then
		clearTargetFrame()
		notifyFailure("InvalidTargetFrame")
		return
	end

	local prepared = GroupAsFrame.prepareReparent(Selection:Get(), targetFrame)
	notifyIgnoredObjects(#prepared.ignored)

	if not prepared.ok then
		notifyFailure(prepared.reason)
		return
	end

	local recording = ChangeHistoryService:TryBeginRecording("ReparentToTargetFrame", "Reparent to Target Frame")
	if recording == nil then
		notifyRecordingFailed()
		return
	end

	local ok, result = pcall(function()
		return GroupAsFrame.applyReparent(prepared)
	end)

	if ok and result.ok and result.frame ~= nil then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
		Selection:Set({ result.frame })
		notifications.notify(
			`Moved {pluralize(#result.groupedObjects, "object")} into "{result.frame.Name}"`,
			{ kind = "success" }
		)
	else
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Cancel)

		if ok then
			notifyFailure(result.reason)
		else
			notifyUnexpectedError("reparenting", result)
		end
	end
end)
