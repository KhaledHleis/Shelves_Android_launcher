# Changelog

Versions follow the roadmap in the design document. Each one ends with a
working APK.

## v0.2 — Fast mode shell

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
