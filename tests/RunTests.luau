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

local function getPluginRoot(): Instance
	local pluginRoot = ReplicatedStorage:FindFirstChild("plugins")
	if pluginRoot == nil then
		error("Could not find ReplicatedStorage.plugins")
	end

	return pluginRoot
end

local function cloneRuntime(): (Instance, Instance)
	local runtime = Instance.new("Folder")
	runtime.Name = "_PluginTestRun"
	runtime.Parent = TestService

	local pluginRoot = getPluginRoot():Clone()
	pluginRoot.Name = "plugins"
	pluginRoot.Parent = runtime

	local testRoot = getTestRoot():Clone()
	testRoot.Name = "tests"
	testRoot.Parent = runtime

	return runtime, testRoot
end

local function runTests()
	local TestEZ = require(ReplicatedStorage.Packages.TestEZ) :: any
	local runtime, testRoot = cloneRuntime()
	local ok, results = pcall(function()
		return TestEZ.TestBootstrap:run({
			testRoot,
		}, TestEZ.Reporters.TextReporter)
	end)

	runtime:Destroy()

	if not ok then
		error(results, 0)
	end

	local failureCount = results.failureCount :: number
	local successCount = results.successCount :: number
	local skippedCount = results.skippedCount :: number

	print(("[Plugin Tests] %d passed, %d failed, %d skipped"):format(successCount, failureCount, skippedCount))

	if failureCount > 0 then
		error(("[Plugin Tests] %d TestEZ test(s) failed."):format(failureCount))
	end

	return results
end

return runTests
