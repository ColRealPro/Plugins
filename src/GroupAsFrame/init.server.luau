--!strict

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")

local GroupAsFrame = require(script.GroupAsFrame)

local toolbar = plugin:CreateToolbar("Group As Frame")
local button = toolbar:CreateButton(
	"GroupAsFrame",
	"Group selected UI objects into an invisible frame",
	"rbxassetid://131620670327497",
	"Group as Frame"
)
local setTargetButton = toolbar:CreateButton(
	"SetReparentTargetFrame",
	"Use the selected GUI object (Frame, ImageLabel, TextButton, etc.) as the reparent target",
	"rbxassetid://131620670327497",
	"Set Target"
)
local reparentButton = toolbar:CreateButton(
	"ReparentToTargetFrame",
	"Reparent selected UI objects to the target GUI object",
	"rbxassetid://131620670327497",
	"Reparent UI"
)

button.ClickableWhenViewportHidden = true
setTargetButton.ClickableWhenViewportHidden = true
reparentButton.ClickableWhenViewportHidden = true

local targetFrame: GuiObject? = nil
local targetFrameConnection: RBXScriptConnection? = nil

local function warnIgnoredObjects(count: number)
	if count > 0 then
		warn(("[Group as Frame] Ignored %d selected instance(s) that are not GuiObjects."):format(count))
	end
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
		end
	end)
	setTargetButton:SetActive(true)
end

local function warnFailure(prefix: string, reason: GroupAsFrame.FailureReason?)
	warn(("[%s] %s"):format(prefix, GroupAsFrame.getFailureMessage(reason)))
end

button.Click:Connect(function()
	local prepared = GroupAsFrame.prepare(Selection:Get())
	if not prepared.ok then
		warnFailure("Group as Frame", prepared.reason)
		return
	end

	warnIgnoredObjects(#prepared.ignored)

	local recording = ChangeHistoryService:TryBeginRecording("GroupAsFrame", "Group as Frame")
	if recording == nil then
		warn("[Group as Frame] Could not start an undo recording, so no changes were made.")
		return
	end

	local ok, result = pcall(function()
		return GroupAsFrame.apply(prepared)
	end)

	if ok and result.ok and result.frame ~= nil then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
		Selection:Set({ result.frame })
	else
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Cancel)

		if ok then
			warnFailure("Group as Frame", result.reason)
		else
			warn(("[Group as Frame] Failed while grouping: %s"):format(tostring(result)))
		end
	end
end)

setTargetButton.Click:Connect(function()
	local ok, frame, reason = GroupAsFrame.pickTargetFrame(Selection:Get())
	if not ok or frame == nil then
		warnFailure("Group as Frame", reason)
		return
	end

	setTargetFrame(frame)
end)

reparentButton.Click:Connect(function()
	if targetFrame == nil then
		warnFailure("Group as Frame", "NoTargetFrame")
		return
	end

	if targetFrame.Parent == nil then
		clearTargetFrame()
		warnFailure("Group as Frame", "InvalidTargetFrame")
		return
	end

	local prepared = GroupAsFrame.prepareReparent(Selection:Get(), targetFrame)
	warnIgnoredObjects(#prepared.ignored)

	if not prepared.ok then
		warnFailure("Group as Frame", prepared.reason)
		return
	end

	local recording = ChangeHistoryService:TryBeginRecording("ReparentToTargetFrame", "Reparent to Target Frame")
	if recording == nil then
		warn("[Group as Frame] Could not start an undo recording, so no changes were made.")
		return
	end

	local ok, result = pcall(function()
		return GroupAsFrame.applyReparent(prepared)
	end)

	if ok and result.ok and result.frame ~= nil then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
		Selection:Set({ result.frame })
	else
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Cancel)

		if ok then
			warnFailure("Group as Frame", result.reason)
		else
			warn(("[Group as Frame] Failed while reparenting: %s"):format(tostring(result)))
		end
	end
end)
