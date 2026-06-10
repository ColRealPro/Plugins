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

button.ClickableWhenViewportHidden = true

local function warnIgnoredObjects(count: number)
	if count > 0 then
		warn(("[Group as Frame] Ignored %d selected instance(s) that are not GuiObjects."):format(count))
	end
end

button.Click:Connect(function()
	local prepared = GroupAsFrame.prepare(Selection:Get())
	if not prepared.ok then
		warn(("[Group as Frame] %s"):format(GroupAsFrame.getFailureMessage(prepared.reason)))
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
			warn(("[Group as Frame] %s"):format(GroupAsFrame.getFailureMessage(result.reason)))
		else
			warn(("[Group as Frame] Failed while grouping: %s"):format(tostring(result)))
		end
	end
end)
