# Socket Launcher — v0.2 "Fast mode shell"

[![CI](../../actions/workflows/ci.yml/badge.svg)](../../actions/workflows/ci.yml)

![The Fast-mode carousel](docs/v0.2-fast-mode.png)

An Android home screen that shows your apps as physical game media.
Godot 4.7 for everything you see, a small Kotlin plugin for everything that
needs Android.

This release is the Fast-mode shell from the roadmap: a working 3D carousel
with the full launcher chrome around it. Folders, All apps and Inspect are
stubbed with prompts that say which version brings them.

## What v0.2 adds on top of v0.1

| Area | v0.2 |
| --- | --- |
| View | 3D carousel — selected item centre, neighbours either side, index wraps |
| Models | One generic game case, built as a mesh with the cover face on its own surface |
| Cover | Tinted from the app icon, icon on the front, title on the box |
| Animation | Idle sway, elastic switch, cartridge-insert on launch |
| Rotation | Right stick, or drag on the centre model; springs back after a few seconds |
| Top bar | Clock, folder tabs between L/R prompts, Wi-Fi and battery |
| Bottom bar | Settings / Apps / Inspect prompts, shelf indicator, Launch prompt |
| Background | Moving gradient sky shader, tinted by the selected icon's colours |
| Prompts | Controller Icons addon, with an auto / Xbox / PlayStation / Nintendo / Steam Deck override |
| Sound | Move, select, back, folder, insert |
| Data | `Library` with per-app records and two dynamic folders (All, New) |
| Android | `getBatteryState()`, `getNetworkState()`, `apps_changed` signal |

Everything still works by touch alone, and the two v0.1 input rules are kept:
the focus visuals only appear while a pad is in use, and the first pad press
after touching the screen only wakes the cursor.

## Controls

| Action | Controller | Touch |
| --- | --- | --- |
| Move selection | D-pad / left stick (hold to repeat) | Swipe anywhere outside the centre model, or tap a side item |
| Launch | A | Tap the centre model |
| Rotate the model | Right stick | Drag on the centre model |
| Previous / next folder | L1 / R1 | Tap ‹ › in the top bar |
| Jump 10 at a time | L2 / R2 | — |
| Inspect / Apps / Settings | X / Y / Start | Tap the prompt |

On a keyboard: arrows, Enter, Q/E for folders, `[` `]` to jump, X/Y/F1 for the
three screens.

## Layout

```
godot/
  project.godot              Godot 4.7, mobile renderer, 1920x1080 landscape
  scenes/main.tscn           3D world + chrome; the only scene you need to open
  shaders/sky_gradient.gdshader
  sounds/                    generated UI sounds (no third-party audio)
  scripts/
    settings.gd              autoload — launcher settings, user://settings.json
    app_bridge.gd            autoload — the only code that calls the plugin
    library.gd               autoload — apps, folders, per-app records
    input_mode.gd            autoload — touch vs pad, A/B swap
    audio.gd                 autoload — sound pool, music fade
    carousel.gd              the Fast-mode view
    media_item.gd            one 3D case: materials, sway, insert animation
    box_mesh.gd              the case mesh (cover face on its own surface)
    icon_colors.gd           dominant colours from an app icon
    top_bar.gd / bottom_bar.gd / shelf_indicator.gd / button_prompt.gd
    battery_icon.gd / wifi_icon.gd / style.gd
  addons/controller_icons/   vendored, MIT, Xelu CC0 icons
  addons/socket_launcher/    export plugin (AAR + manifest injection)
  tools/                     dev helpers, not part of the app
android-plugin/              Kotlin plugin -> LauncherPlugin.aar
```

The bars build their children in script rather than as deep scene trees, so the
whole layout of a bar reads top to bottom in one file. Positions and colours
come from `style.gd`.

## Build

1. `cd android-plugin && gradlew.bat assemble` (JDK 17, SDK at `C:\Android\sdk`).
   The AARs are copied into `godot/addons/socket_launcher/bin/`. Set
   `godotVersion` in `plugin/build.gradle.kts` to your editor version.
2. Open `godot/` and run *Project → Install Android Build Template*.
3. *Project → Export → Android*, tick **Use Gradle Build**, min SDK 24, export.
4. Press Home on the device and pick Socket Launcher.

To get back out while testing: Settings → Apps → Default apps → Home app.
Set `REGISTER_AS_HOME = false` in `addons/socket_launcher/export_plugin.gd` to
export it as an ordinary app instead.

On a PC the launcher runs with 36 mock apps and generated icons, so the whole
UI can be worked on without deploying.

## Dev helpers

```
godot --headless --path godot tools/selftest.tscn   # navigation smoke test
godot --path godot tools/shot.tscn                  # writes user://shot.png
```

The self-test covers wrapping, folder switching, the trigger jump, the launch
lock and the fact that only seven models exist however big the library is.

## Working on it

- `main` always builds and passes CI. Work on a branch per milestone —
  `v0.3-library`, `v0.4-customization` — and merge when the milestone ends with
  a working APK.
- Tag each milestone `v0.3.0`, `v0.4.0`, ... and add its section to
  `CHANGELOG.md` in the same commit.
- CI runs on every push and pull request: it imports the project, runs the
  headless self-test, fails on any GDScript error, and assembles the plugin
  AAR (which is the part hardest to check by hand). The AAR is attached to the
  run as an artifact.
- Open questions from the design document are worth filing as issues, so the
  answers live next to the code rather than in a chat.

## Licence

MIT — see `LICENSE`. Third-party code and assets are listed in
`THIRD-PARTY.md`.

## Known gaps in v0.2

- Grid layout per folder, custom folders, All apps and Hide are v0.3.
- The background has the moving gradient but not the texture overlay (v0.6).
- Finishes, shaders and custom launch actions are v0.4.
- The Kotlin side is untested against a device from here — the Gradle build has
  not been compiled, only written.
- `getNetworkState()` replaces the `getWifiState()` in the design doc so the bar
  can tell "no Wi-Fi" from "on mobile data". Rename if you prefer the doc.
