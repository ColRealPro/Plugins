# Development

## Adding plugins

Add a folder under `src/` with an `init.server.luau`, then run `lune run InstallPlugin` to install it

## Tests

From the repo root:

```bash
rokit install
wally install
rojo build -o Plugins.rbxlx
```

Open `Plugins.rbxlx` in Studio and run this in the command bar in edit mode:

```lua
local runner = game.ReplicatedStorage.tests.RunTests:Clone()
local runTests = require(runner)
runner:Destroy()
runTests()
```

The clone picks up edits to the runner on each run, and the runner clones the plugin modules and tests

For live edits, run `rojo serve` and connect Studio through the Rojo plugin
