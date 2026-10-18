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

## v0.5 — Design pass (in progress)

- Models stand on something: a soft contact shadow is drawn under each one,
  since there is no floor in the scene for a real shadow to fall on.
- Apps with no picture get a printed cover rather than a flat slab — the
  bright colour runs into the deep one, with a sheen across it and a darker
  band at the foot where the title sits.
- Panels slide in from the right and leave the same way, so a screen arriving
  reads as a move rather than a cut. Input is handed back the moment a panel
  closes, not when its animation ends.

- One type scale (caption, small, body, heading, title) instead of sizes
  picked per screen, and a single gutter and gap used by the bars and every
  panel.
- A rim light with strong specular, so an edge separates from a dark
  background instead of dissolving into it.
- A launcher icon that shows the product — three cases on a shelf — and a
  boot splash using it.

- Both ends of the background gradient take the icon's colour. The second one
  was being crushed to near-black, so every background read as one colour
  fading into the same darkness whatever the art was.
- The colour picker is a small centred grid of 30 chips with no names, over
  whatever you are editing, rather than a full-screen list.
- Panels scale and fade rather than sliding: setting a Control's position
  rewrites its offsets, which threw the centred popup into a corner.

- The cartridge is a Switch-style card: a plastic shell with the corner notch
  and tapered foot, and a sticker sitting proud of the face. The sticker is
  its own surface, which is what lets the art and the plastic be set apart.
- The case has PS4 proportions, thinner than the slab it was.
- Finish (opaque, translucent, clear, metallic, glitter) applies to the art
  only; a separate Material setting (matte, glossy, smoked, metal, rubber)
  controls the plastic. They were one control before, which is why changing
  the finish seemed to do nothing on a cartridge.
- `templates/` holds a .glb per shape to model from, exported from the meshes
  themselves by tools/export_templates.tscn.
- The boot splash is off again: Godot only takes PNG there and the icon is an
  SVG, so it was silently falling back to the Godot logo.

Still to come in v0.5: a theme resource in place of the constants in
style.gd.

### Colours, looping and touch

- Background colours are now the pair in the art that looks best together,
  scored on hue and lightness distance with coverage only as a tie-break,
  rather than the two most common — which were usually two shades of one thing.
- Any folder with four or more apps loops in the carousel, not just long ones.
- The grid loops vertically as well as inside each row.
- Touch in the grid: a vertical swipe changes row, and a tap steps toward
  whatever was tapped on whichever axis is further out.
- Bigger models in both views, and a stronger push in the grid — damped
  vertically, since a full-strength shove put the row below into the bar.

### Grid feel, bevelled shapes, square patterns

- Patterns were stretched: they worked in screen uv, which is 16:9, so every
  cell was an oval. They work in square space now, and the triangle lattice
  is a real sheared grid rather than staggered squares.
- The box, cartridge and card are chamfered, so the edge catches the light at
  a different angle from the face and the shape reads as an object.
- In the grid the selection is larger and shoves its neighbours outward, the
  further off the less they feel it.
- Left and right now wrap inside the row they started on instead of running
  onto the next line.
- Rows other than the middle of the window had no rotatable model: hidden
  nodes kept their old item index, so the lookup could return an invisible
  one. Hidden nodes are cleared, and the lookup only accepts a visible node.
- Inspect is a half-width sheet, so the model stays on screen and changes as
  you move through shape, finish and colours.
- The shelf no longer reads the pad while a panel is open.

### Socket-style chrome, and bicolour backgrounds

- Button prompts, the folder tabs and the title under the model are rounded
  pills; the selected tab is a filled light chip.
- List rows are cards, and a setting that is on or off shows a green ON or
  red OFF pill rather than a tick.
- Per-app background colours can be two swatches of your choosing, picked
  from an 18-colour grid, alongside the icon colours and the palettes.

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

## v0.6 — Fixes from the device, then Slow mode

Fixes first:

- Covers no longer flash white while a grid scrolls. A model handed a new
  app had nothing on its art surface until the cover finished baking. The
  `Covers` autoload now always answers at once — the finished bake, or a
  small draft (gradient and icon) drawn on the CPU on the spot — and swaps
  the real cover in when it lands. The grid also keeps each model on its
  app for as long as the app stays in the window, instead of reassigning
  all 25 on every row step, and both views bake a few rows ahead.
- Changing folder is animated: the old shelf eases out the way you pushed
  it, piece by piece, and the new one eases in from the other side, nearest
  first, with a small overshoot. Pressing again mid-way finishes the swap.
- Inspect no longer covers the model. The 3D view slides left so the
  selection sits in the middle of the part of the screen the sheet leaves
  free, and value lists opened from Inspect open over the sheet rather than
  the whole screen.
- Settings has tabs — Home, Look, Controls, Sound, System — changed with
  L1/R1 or a tap. Home has the Fast/Slow browsing mode.
- The sweep gradient had a seam at nine o'clock: the angle jumps a full
  turn there and the pattern repeated 1.5 times per turn. Whole harmonics
  only now.
- More gradients: aurora, waves, radial, linear, corners. More patterns:
  bubbles (PS5-style), strips (PS4-style), sparkles, hexagons, ripples.
- Patterns were squashed into tall ovals: the view direction already
  carries the screen's aspect, and it was being corrected a second time.

Then Slow mode, chosen under Settings → Home → Browsing mode:

- The shelf: every folder becomes a row of boxes standing on a plank. Each
  box shows its spine — a number, the title running down it, the icon at the
  foot — and the selection is pulled forward and turned to show its cover.
  The shelf has ends; it does not wrap. Shelf boxes are thicker than the
  Fast-mode case, because at real proportions a spine was too narrow to read.
- A opens the box rather than launching. The case lifts off the shelf, the
  shelf steps back, and the lid swings open on the spine like a book. The
  inside of the lid holds the insert (Inspect → Box insert, from the same
  art folder as covers), the tray holds the media in the app's own shape —
  a disc when the app is a plain box.
- A again plays the insert animation and launches; B (or the back gesture,
  or a tap outside the case) closes the lid and puts the box back. The
  right stick, or a drag, turns the media in the tray.
- The bottom prompt says Open on the shelf and Play in the open box.

Also fixed on the way: the disc's label side was wound the wrong way round,
so it was culled and every disc showed its blank back through it.
