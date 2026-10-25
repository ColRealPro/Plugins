local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")

type Options = {
	all: boolean,
	assumeYes: boolean,
	pluginNames: { string },
	pluginsPath: string?,
}

type PluginProject = {
	name: string,
	folder: string,
	-- nil when the plugin folder has no default.project.json, a temporary one is generated at build time
	projectPath: string?,
}

local function color(name: stdio.Color, value: string): string
	return stdio.color(name) .. value .. stdio.color("reset")
end

local function writeLine(value: string?)
	stdio.write((value or "") .. "\n")
end

local function normalizePath(path: string): string
	path = string.gsub(path, "^%s+", "")
	path = string.gsub(path, "%s+$", "")
	path = string.gsub(path, "^[\"']", "")
	path = string.gsub(path, "[\"']$", "")
	path = string.gsub(path, "\\", "/")
	path = string.gsub(path, "/+", "/")
	if #path > 1 then
		path = string.gsub(path, "/$", "")
	end
	return path
end

local function expandPath(path: string): string
	path = normalizePath(path)
	if path == "~" or string.sub(path, 1, 2) == "~/" then
		local userHome = process.env.HOME or process.env.USERPROFILE
		if userHome then
			path = normalizePath(userHome) .. string.sub(path, 2)
		end
	end
	return normalizePath(path)
end

local function joinPath(...: string): string
	local parts = { ... }
	local result = parts[1] or ""
	for index = 2, #parts do
		local part = parts[index]
		if part ~= "" then
			result = string.gsub(result, "/$", "") .. "/" .. string.gsub(part, "^/", "")
		end
	end
	return normalizePath(result)
end

local function parentPath(path: string): string?
	path = normalizePath(path)
	local parent = string.match(path, "^(.*)/[^/]+$")
	if not parent or parent == "" or parent == path then
		return nil
	end
	if string.match(parent, "^%a:$") then
		return parent .. "/"
	end
	return parent
end

local function isDirectory(path: string): boolean
	local ok, result = pcall(fs.isDir, path)
	return ok and result
end

local function isFile(path: string): boolean
	local ok, result = pcall(fs.isFile, path)
	return ok and result
end

local function printHelp()
	writeLine(color("cyan", "Plugin installer"))
	writeLine()
	writeLine("Pick plugins from a menu")
	writeLine("  lune run InstallPlugin")
	writeLine()
	writeLine("Install by name")
	writeLine("  lune run InstallPlugin GroupAsFrame")
	writeLine("  lune run InstallPlugin PluginOne PluginTwo")
	writeLine()
	writeLine("Install everything without prompts")
	writeLine("  lune run InstallPlugin --all --yes")
	writeLine()
	writeLine("Options")
	writeLine("  --all                   Install every plugin")
	writeLine("  --plugins-path <path>   Use a specific Studio plugin folder")
	writeLine("  --yes, -y               Skip confirmation")
	writeLine("  --help, -h              Show help")
end

local function parseOptions(): Options
	local options: Options = {
		all = false,
		assumeYes = false,
		pluginNames = {},
	}

	local index = 1
	while index <= #process.args do
		local argument = process.args[index]
		if argument == "--all" then
			options.all = true
			index += 1
		elseif argument == "--yes" or argument == "-y" then
			options.assumeYes = true
			index += 1
		elseif argument == "--plugins-path" then
			local path = process.args[index + 1]
			if not path or path == "" then
				error("--plugins-path needs a folder path")
			end
			options.pluginsPath = expandPath(path)
			index += 2
		elseif argument == "--help" or argument == "-h" then
			printHelp()
			process.exit(0)
		elseif string.sub(argument, 1, 1) == "-" then
			error(`Unknown option {argument}`)
		else
			table.insert(options.pluginNames, argument)
			index += 1
		end
	end

	if options.all and #options.pluginNames > 0 then
		error("Use plugin names or --all, not both")
	end
	return options
end

local function findRepositoryRoot(): string
	local current = normalizePath(process.cwd)
	while current do
		if isDirectory(joinPath(current, "src")) and isFile(joinPath(current, ".lune", "InstallPlugin.luau")) then
			return current
		end
		current = parentPath(current)
	end
	return error("Could not find the plugins repository in this directory or a parent directory")
end

local PLUGIN_ENTRY_FILES = { "init.server.luau", "init.client.luau", "init.luau", "init.server.lua", "init.client.lua" }

local function hasPluginEntry(folder: string): boolean
	for _, fileName in PLUGIN_ENTRY_FILES do
		if isFile(joinPath(folder, fileName)) then
			return true
		end
	end
	return false
end

local function discoverPlugins(repositoryRoot: string): { PluginProject }
	local pluginsFolder = joinPath(repositoryRoot, "src")
	local projects = {}
	for _, name in fs.readDir(pluginsFolder) do
		local folder = joinPath(pluginsFolder, name)
		local projectPath = joinPath(folder, "default.project.json")
		if isDirectory(folder) and isFile(projectPath) then
			table.insert(projects, {
				name = name,
				folder = folder,
				projectPath = projectPath,
			})
		elseif isDirectory(folder) and hasPluginEntry(folder) then
			table.insert(projects, {
				name = name,
				folder = folder,
				projectPath = nil,
			})
		end
	end

	table.sort(projects, function(left, right)
		return string.lower(left.name) < string.lower(right.name)
	end)

	if #projects == 0 then
		error(`No plugin projects found in {pluginsFolder}`)
	end
	return projects
end

local function findPlugin(projects: { PluginProject }, name: string): PluginProject?
	local wanted = string.lower(name)
	for _, project in projects do
		if string.lower(project.name) == wanted then
			return project
		end
	end
	return nil
end

local function availablePluginNames(projects: { PluginProject }): string
	local names = {}
	for _, project in projects do
		table.insert(names, project.name)
	end
	return table.concat(names, ", ")
end

local function chooseProjects(projects: { PluginProject }, options: Options): { PluginProject }
	if options.all then
		return projects
	end

	if #options.pluginNames > 0 then
		local selected = {}
		local alreadySelected = {}
		for _, name in options.pluginNames do
			local project = findPlugin(projects, name)
			if not project then
				error(`Unknown plugin "{name}"\nAvailable plugins: {availablePluginNames(projects)}`)
			end
			if not alreadySelected[project.name] then
				table.insert(selected, project)
				alreadySelected[project.name] = true
			end
		end
		return selected
	end

	local names = {}
	for _, project in projects do
		table.insert(names, project.name)
	end

	writeLine(color("cyan", "Plugin installer"))
	writeLine("Use the arrow keys to move")
	writeLine("Press Space to select plugins, then Enter to continue")
	writeLine()
	local selectedIndices: { number } = stdio.prompt("multiselect", "Select plugins", names)
	if #selectedIndices == 0 then
		writeLine("Nothing selected")
		process.exit(0)
	end

	local selected = {}
	for _, selectedIndex in selectedIndices do
		table.insert(selected, projects[selectedIndex])
	end
	return selected
end

local function createDirectory(path: string)
	local ok, message = pcall(fs.writeDir, path)
	if not ok then
		error(`Could not create "{path}"\n{tostring(message)}`)
	end
end

local function ensurePluginFolder(path: string, assumeYes: boolean): string
	path = expandPath(path)
	if path == "" then
		error("The Studio plugin folder path cannot be empty")
	end
	if isDirectory(path) then
		return path
	end

	writeLine(`Plugin folder not found: {path}`)
	if not assumeYes and not stdio.prompt("confirm", "Create it", true) then
		writeLine("Cancelled")
		process.exit(0)
	end
	createDirectory(path)
	return path
end

local function runFolderPicker(program: string, arguments: { string }): (boolean, string?)
	local launched, result = pcall(process.exec, program, arguments)
	if not launched then
		return false, nil
	end
	if not result.ok then
		return true, nil
	end
	local path = expandPath(result.stdout)
	return true, if path == "" then nil else path
end

local function promptForPluginFolder(): string
	writeLine("Studio's plugin folder could not be detected")
	writeLine("Choose it in the folder picker")

	local userHome = process.env.HOME or process.env.USERPROFILE
	local initialDirectory = if userHome and isDirectory(expandPath(userHome))
		then expandPath(userHome)
		else normalizePath(process.cwd)
	local launched = false
	local selectedPath = nil

	if process.os == "windows" then
		local powerShellScript = [[
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
$dialog = New-Object System.Windows.Forms.FolderBrowserDialog
$dialog.Description = 'Select your Roblox Studio plugins folder'
$dialog.ShowNewFolderButton = $true
if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    [Console]::Out.Write($dialog.SelectedPath)
}
]]
		for _, program in { "powershell.exe", "pwsh" } do
			launched, selectedPath = runFolderPicker(program, { "-NoProfile", "-STA", "-Command", powerShellScript })
			if launched then
				break
			end
		end
	elseif process.os == "macos" then
		launched, selectedPath = runFolderPicker("osascript", {
			"-e",
			'POSIX path of (choose folder with prompt "Select your Roblox Studio plugins folder")',
		})
	else
		local pickers = {
			{
				program = "zenity",
				arguments = {
					"--file-selection",
					"--directory",
					"--title=Select your Roblox Studio plugins folder",
					`--filename={initialDirectory}/`,
				},
			},
			{
				program = "kdialog",
				arguments = {
					"--getexistingdirectory",
					initialDirectory,
					"--title",
					"Select your Roblox Studio plugins folder",
				},
			},
			{
				program = "yad",
				arguments = {
					"--file-selection",
					"--directory",
					"--title=Select your Roblox Studio plugins folder",
					`--filename={initialDirectory}/`,
				},
			},
		}
		for _, picker in pickers do
			launched, selectedPath = runFolderPicker(picker.program, picker.arguments)
			if launched then
				break
			end
		end
	end

	if not launched then
		error("No folder picker found, pass --plugins-path instead")
	end
	if not selectedPath then
		writeLine("Cancelled")
		process.exit(0)
	end
	if not isDirectory(selectedPath) then
		error(`Selected folder does not exist: {selectedPath}`)
	end
	return selectedPath
end

local function resolvePluginFolder(options: Options): string
	if options.pluginsPath then
		return ensurePluginFolder(options.pluginsPath, options.assumeYes)
	end

	local ok, detectedPath = pcall(roblox.studioPluginPath)
	if ok and type(detectedPath) == "string" and expandPath(detectedPath) ~= "" then
		return ensurePluginFolder(detectedPath, options.assumeYes)
	end
	return promptForPluginFolder()
end

local function confirmInstall(projects: { PluginProject }, pluginFolder: string, assumeYes: boolean)
	writeLine()
	writeLine(color("cyan", "Install"))
	for _, project in projects do
		local destination = joinPath(pluginFolder, project.name .. ".rbxm")
		local action = if isFile(destination) then color("yellow", "update") else color("green", "new")
		writeLine(`  {project.name}  {action}`)
	end
	writeLine(`  to {pluginFolder}`)
	writeLine()

	if not assumeYes and not stdio.prompt("confirm", "Continue", true) then
		writeLine("Cancelled")
		process.exit(0)
	end
end

local function removeTemporaryFile(path: string)
	if isFile(path) then
		local ok = pcall(fs.removeFile, path)
		if not ok then
			writeLine(color("yellow", `Could not remove temporary file {path}`))
		end
	end
end

local function temporaryFolder(repositoryRoot: string): string
	for _, variable in { "TEMP", "TMPDIR", "TMP" } do
		local path = process.env[variable]
		if path and isDirectory(expandPath(path)) then
			return expandPath(path)
		end
	end
	return repositoryRoot
end

-- Plugin folders without their own project file get a throwaway one so Rojo builds the folder as the plugin root
local function writeGeneratedProject(project: PluginProject, repositoryRoot: string): string
	local projectPath = joinPath(temporaryFolder(repositoryRoot), `.{project.name}.install.project.json`)
	local contents = serde.encode("json", {
		name = project.name,
		tree = {
			["$path"] = project.folder,
		},
	}, true)
	local ok, message = pcall(fs.writeFile, projectPath, contents)
	if not ok then
		error(`Could not write a temporary project for {project.name}\n{tostring(message)}`)
	end
	return projectPath
end

local function installProject(project: PluginProject, repositoryRoot: string, pluginFolder: string): string
	local destination = joinPath(pluginFolder, project.name .. ".rbxm")
	local temporary = joinPath(pluginFolder, `.{project.name}.installing.rbxm`)
	removeTemporaryFile(temporary)

	-- Plugins with their own Wally packages need them installed before Rojo can build them
	local projectFolder = project.folder
	if isFile(joinPath(projectFolder, "wally.toml")) then
		stdio.write(`Installing packages for {project.name}... `)
		local packages = process.exec("wally", { "install" }, { cwd = projectFolder })
		if not packages.ok then
			writeLine(color("red", "failed"))
			local details = if packages.stderr ~= "" then packages.stderr else packages.stdout
			error(`Wally could not install packages for {project.name}\n{details}`)
		end
		writeLine(color("green", "done"))
	end

	local generatedProjectPath = if project.projectPath then nil else writeGeneratedProject(project, repositoryRoot)
	local projectPath = project.projectPath or generatedProjectPath :: string

	stdio.write(`Building {project.name}... `)
	local result = process.exec("rojo", { "build", projectPath, "--output", temporary }, {
		cwd = repositoryRoot,
	})
	if generatedProjectPath then
		removeTemporaryFile(generatedProjectPath)
	end
	if not result.ok then
		writeLine(color("red", "failed"))
		removeTemporaryFile(temporary)
		local details = if result.stderr ~= "" then result.stderr else result.stdout
		error(`Rojo could not build {project.name}\n{details}`)
	end
	writeLine(color("green", "done"))

	local moved, moveError = pcall(fs.move, temporary, destination, true)
	if not moved then
		removeTemporaryFile(temporary)
		error(`Could not install {project.name}\n{tostring(moveError)}`)
	end
	return destination
end

local options = parseOptions()
local repositoryRoot = findRepositoryRoot()
local projects = discoverPlugins(repositoryRoot)
local selectedProjects = chooseProjects(projects, options)
local pluginFolder = resolvePluginFolder(options)

confirmInstall(selectedProjects, pluginFolder, options.assumeYes)

local installedPaths = {}
for _, project in selectedProjects do
	table.insert(installedPaths, installProject(project, repositoryRoot, pluginFolder))
end

writeLine()
writeLine(color("green", `Installed {#installedPaths} plugin{if #installedPaths == 1 then "" else "s"}`))
for _, path in installedPaths do
	writeLine(`  {path}`)
end
writeLine("Reload local plugins in Studio to use the new build")
