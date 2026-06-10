--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TestService = game:GetService("TestService")

local function getTestRoot(): Instance
	local testRoot = ReplicatedStorage:FindFirstChild("tests") or ReplicatedStorage:FindFirstChild("Tests")
	if testRoot == nil then
		error("Could not find ReplicatedStorage.tests or ReplicatedStorage.Tests")
	end

	return testRoot
end

local function cloneTestRoot(): Instance
	local testRoot = getTestRoot():Clone()
	testRoot.Name = "_GroupAsFrameTestRun"
	testRoot.Parent = TestService
	return testRoot
end

local function runTests()
	local TestEZ = require(ReplicatedStorage.Packages.TestEZ) :: any
	local testRoot = cloneTestRoot()
	local ok, results = pcall(function()
		return TestEZ.TestBootstrap:run({
			testRoot,
		}, TestEZ.Reporters.TextReporter)
	end)

	testRoot:Destroy()

	if not ok then
		error(results, 0)
	end

	local failureCount = results.failureCount :: number
	local successCount = results.successCount :: number
	local skippedCount = results.skippedCount :: number

	print(("[GroupAsFrame Tests] %d passed, %d failed, %d skipped"):format(successCount, failureCount, skippedCount))

	if failureCount > 0 then
		error(("[GroupAsFrame Tests] %d TestEZ test(s) failed."):format(failureCount))
	end

	return results
end

return runTests
