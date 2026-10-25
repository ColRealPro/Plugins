# Plugins

This is a collection of plugins I made because I was annoyed that studio did not have them. They are all open source so feel free to use them, submit issues, or contribute

Each plugin can be installed on its own, or you can install the whole collection

## Getting started

You'll need Roblox Studio and [Rokit](https://github.com/rojo-rbx/rokit). Clone this repo, then run:

```bash
rokit install
lune run InstallPlugin
```

This opens a menu where you can choose which plugins to install. Reload local plugins in Studio afterwards

To install a specific plugin, pass its folder name:

```bash
lune run InstallPlugin GroupAsFrame
```

Or install everything without prompts:

```bash
lune run InstallPlugin --all --yes
```

The installer finds Studio's plugins folder automatically. You can use `--plugins-path` to choose a different folder, or `--help` to see all options

## Plugins

### [Group As Frame](src/GroupAsFrame/README.md)

Groups selected UI objects into a fitting frame, or moves them into an existing GUI container while preserving their layout

## Development

See [development](docs/development.md) for adding plugins and running tests

[MIT licensed](LICENSE)
