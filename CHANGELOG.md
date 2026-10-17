# Changelog

Versions follow the roadmap in the design document. Each one ends with a
working APK.

## v0.4 — Customisation

- Inspect, reachable with X from the shelf or All apps: display name, media
  shape, finish, cover and label art, launch action, folders, reset.
- Four media shapes built as meshes: box, cartridge, disc (a real annulus
  with the art mapped round it) and card.
- Five finishes: opaque, translucent, clear, metallic, glitter.
- Cover and label art read from a watched folder, so files can be dropped on
  the device with a file manager.
- Custom launch actions, parsed by shape: a link, a package/activity pair, or
  another package. `launchIntent(json)` added to the Kotlin plugin, which is
  what games inside GameNative need.
- The carousel shows three items; the grid is a honeycomb with the selection
  centred and alternate rows offset.

### Background shaders

- Gradient styles: pools, irregular blending (domain-warped value noise), and
  a sweep with a noisy edge.
- Pattern overlays drawn over the gradient: dots, mesh, triangles and Chladni
  figures, with adjustable strength.
- Both are settings with their own lists; the colours still come from the app.
- Separate speed settings for the gradient and the pattern, including still.
- The grid is a plain square lattice again, with the selection still centred.

### Fixed after the first v0.4 build on device

- Moving from the end of a row to the start of the next cut instead of
  sliding: the grid clamped its travel as a vector length, turning a
  four-column, one-row move into a short diagonal. Clamped per axis now.
- Panels opened from other panels were invisible: they are siblings, so the
  one on top of the stack has to be the last child too.
- Apps hid themselves: the Y that opened All apps was still "just pressed"
  when the panel first ran, so it also hid the first app. Panels ignore
  input for two frames after opening.
- Metallic and glitter looked like opaque because ambient and reflections
  came from a flat colour; both come from the sky now.
- Bigger art on the carousel models, per-app background palettes, and choice
  lists instead of pressing A to cycle through values.

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
