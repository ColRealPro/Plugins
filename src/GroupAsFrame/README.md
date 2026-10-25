# Group As Frame

Group selected UI objects into an invisible, tightly fitting `Frame`, or move them into an existing GUI container. The plugin recalculates positions and sizes to preserve the current layout

The **Group As Frame** toolbar has three controls:

| Control | Usage |
| --- | --- |
| **Group as Frame** | Select UI objects in Explorer, then click to wrap them in a new `GroupFrame` |
| **Set Target** | Select exactly one existing GUI container, then click to remember it as the reparent target. Frames, image labels, text buttons, and other `GuiObject` instances are accepted |
| **Reparent UI** | Select the UI objects to move, then click to move them into the remembered target |

Grouping and reparenting support Studio undo. Non-UI selections are ignored; selected descendants stay with their selected ancestor. Warnings appear in Studio's Output window when an operation cannot proceed

## Layout behavior

- Positions and sizes are recalculated; the original mix of `UDim2` scale and offset values is not retained. Check the layout at other viewport sizes after grouping
- Grouping uses the nearest shared GUI ancestor and moves the new frame above layout-controlled containers where possible
- Reparenting rejects targets with `AutomaticSize` enabled or a child `UILayout`, since these can change the resulting layout
- Scrolling frames use unscrolled canvas coordinates. Moving across scrolling boundaries can change the visible screen position
- The existing tests cover anchors, padding, scrolling, size constraints, and UI scaling. Rotated GUI hierarchies are not covered

## Install

From the repository root, run:

```sh
rokit install
lune run InstallPlugin GroupAsFrame
```

See the [collection README](../../README.md) for setup and installer options, or [development](../../docs/development.md) for running tests
