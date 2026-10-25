local fs = require("@lune/fs")
local process = require("@lune/process")
local stdio = require("@lune/stdio")

local function color(name: stdio.Color, value: string): string
	return stdio.color(name) .. value .. stdio.color("reset")
end

local function writeLine(value: string?)
	stdio.write((value or "") .. "\n")
end

local function isDirectory(path: string): boolean
	local ok, result = pcall(fs.isDir, path)
	return ok and result
end

local function isFile(path: string): boolean
	local ok, result = pcall(fs.isFile, path)
	return ok and result
end

local function findRepositoryRoot(): string
	local current = string.gsub(process.cwd, "\\", "/")
	while true do
		if isFile(`{current}/wally.toml`) and isFile(`{current}/.lune/WallyInstall.luau`) then
			return current
		end

		local parent = string.match(current, "^(.*)/[^/]+$")
		if not parent or parent == "" or parent == current then
			return error("Could not find the plugins repository in this directory or a parent directory")
		end
		current = parent
	end
end

local function run(label: string, program: string, arguments: { string }, cwd: string)
	stdio.write(`{label}... `)
	local result = process.exec(program, arguments, { cwd = cwd })
	if not result.ok then
		writeLine(color("red", "failed"))
		local details = if result.stderr ~= "" then result.stderr else result.stdout
		error(`{program} {table.concat(arguments, " ")} failed in {cwd}\n{details}`)
	end
	writeLine(color("green", "done"))
end

local repositoryRoot = findRepositoryRoot()

-- The root packages hold test tooling, each plugin folder with a wally.toml gets its own Packages folder
local packageFolders = { "Packages" }
run("Installing root packages", "wally", { "install" }, repositoryRoot)

local pluginNames = fs.readDir(`{repositoryRoot}/src`)
table.sort(pluginNames)
for _, name in pluginNames do
	local folder = `{repositoryRoot}/src/{name}`
	if isDirectory(folder) and isFile(`{folder}/wally.toml`) then
		run(`Installing packages for {name}`, "wally", { "install" }, folder)
		table.insert(packageFolders, `src/{name}/Packages`)
	end
end

-- The root project includes every plugin's Packages folder, so one sourcemap covers them all
run("Generating sourcemap", "rojo", { "sourcemap", "default.project.json", "--output", "sourcemap.json" }, repositoryRoot)

local existingFolders = {}
for _, folder in packageFolders do
	if isDirectory(`{repositoryRoot}/{folder}`) then
		table.insert(existingFolders, folder)
	end
end

local typeArguments = { "--sourcemap", "sourcemap.json" }
table.move(existingFolders, 1, #existingFolders, #typeArguments + 1, typeArguments)
run("Patching package types", "wally-package-types", typeArguments, repositoryRoot)

writeLine()
writeLine(color("green", `Installed and patched {#existingFolders} package folder{if #existingFolders == 1 then "" else "s"}`))
for _, folder in existingFolders do
	writeLine(`  {folder}`)
end
