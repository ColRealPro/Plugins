# Development

## Adding plugins

Add a folder under `src/` with an `init.server.luau`, then run `lune run InstallPlugin` to install it

A plugin can have its own `wally.toml` next to its `init.server.luau`. The installer runs `wally install` in that folder before building, and the packages end up in a `Packages` folder inside the plugin

Run `lune run WallyInstall` from the repo root after changing any `wally.toml`. It installs the root packages and every plugin's packages, regenerates `sourcemap.json`, and patches package types with `wally-package-types` so luau-lsp picks up types from packages like React

## Tests

From the repo root:

```bash
rokit install
lune run WallyInstall
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
