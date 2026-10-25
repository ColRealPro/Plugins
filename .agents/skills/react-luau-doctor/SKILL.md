---
name: react-luau-doctor
description: Use before committing changes to React-Luau code (Roblox `.lua`/`.luau` components or hooks), and whenever the user asks to run, use, or check with react-luau-doctor
---

# React-Luau Doctor

Static analyzer for React-Luau code. It finds hook, effect, state, rendering, and performance mistakes that typecheckers and linters miss

## Check for updates first

Run this once per session before scanning:

```bash
react-luau-doctor update --check
```

If it reports `Update available`, always tell the user the current and latest versions. Don't update unless they ask, then run `react-luau-doctor update`. The automatic update notice is hidden in non-interactive shells, so this check is the only way you'll see it

## Usage

Run from the project root so `react-luau-doctor.config.json` is picked up. If the command isn't installed, use `npx -y @colrealpro/react-luau-doctor`

```bash
react-luau-doctor --staged --verbose                 # before committing, scans staged content only
react-luau-doctor --scope changed --base main --verbose  # changes on the current branch
react-luau-doctor src/path/File.luau --verbose       # a specific file or directory
```

Without `--verbose` only a summary and the highest severity findings are shown. Use the text output when reading findings yourself, `--json` is much larger and only worth it when code or a script needs to parse the report

Understanding and fixing findings:

```bash
react-luau-doctor why src/path/File.luau:12   # explain findings at a location
react-luau-doctor rules explain <rule>        # rule explanation and repair example
```

Fix the code rather than suppressing findings. Only suppress intentional cases with `-- react-luau-doctor-disable-next-line <rule>`, and only change rule severities in the config if the user asks

Run `react-luau-doctor --help` for other options
