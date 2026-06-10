--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local runTests = require(ReplicatedStorage:WaitForChild("tests"):WaitForChild("RunTests"))

runTests()
