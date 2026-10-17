# Changelog

Versions follow the roadmap in the design document. Each one ends with a
working APK.

## v0.3 — Library and folders

- Custom folders: create, rename, delete, reorder; an app can be in several.
- Per-folder layout: carousel or a looping grid, remembered per folder.
- All apps screen: search, folder filing, hiding, launching.
- Hidden apps leave every shelf and are restored from Settings.
- New folder means recently installed and not yet filed, so filing an app is
  what takes it out.
- Settings screen: prompt style, A/B swap, sounds and volume, idle animation,
  clock format, folder management, hidden apps, plugin diagnostics.
- Shared list panel behind all four screens, with pad repeat, touch rows and
  per-screen prompts.
- Fixed: the model changing size after a switch, rotation picking up pitch,
  yaw stopping at half a turn, manual folders never matching any app, and the
  self-test inheriting the previous run's saved library.

## v0.2 — Fast mode shell

Named Shelves. The Android package is `com.khaled.shelves`; a device running
the v0.1 build will see this as a separate app rather than an update.

- 3D carousel: selected item centred, neighbours either side, index wraps.
  Exactly seven models exist however large the library is.
- Generic game-case mesh with the cover face on its own surface, ready for
  spines (v0.5) and other media shapes (v0.4).
- Cover tinted from the app icon, icon on the front, title on the box.
- Idle sway, elastic switch animation, cartridge-insert animation on launch.
- Model rotation with the right stick or by dragging the centre model, with a
  spring back to rest.
- Top bar: clock, folder tabs between L/R prompts, Wi-Fi and battery.
- Bottom bar: Settings / Apps / Inspect prompts, shelf indicator, Launch prompt.
- Moving gradient background, tinted by the selected icon's colours.
- Controller Icons with an auto / Xbox / PlayStation / Nintendo / Steam Deck
  override, plus a Nintendo A/B swap setting.
- Five generated UI sounds.
- `Library` autoload with per-app records and two dynamic folders, All and New.
- Kotlin plugin gains `getBatteryState()`, `getNetworkState()` and an
  `apps_changed` signal driven by a package broadcast receiver.
- Headless self-test covering wrapping, folder switching, the trigger jump,
  the launch lock and the model budget.

## v0.1 — Grid launcher

- Scrollable 2D grid of installed apps, sorted A to Z, lazy icon loading.
- Touch and controller input, drag-safe launching, focus ring only on pad.
- Kotlin plugin: `getInstalledApps()`, `getAppIcon()`, `launchApp()`.
- Export plugin injecting the AAR and the HOME intent-filter.
