# Media model templates

One `.glb` per shape, exported from the meshes the launcher builds
(`godot/scripts/box_mesh.gd`). Open one in Blender, model over it, and the
result drops straight into the launcher.

| File | Shape |
| --- | --- |
| `shelves-box.glb` | Game case, PS4 proportions |
| `shelves-cartridge.glb` | Switch-style card with a sticker on the front |
| `shelves-disc.glb` | Disc with a centre hole |
| `shelves-card.glb` | Flat card |

## The contract

Two materials, and the names matter:

- **`art`** — the faces that carry the cover or the sticker. UVs run 0-1
  across them. The app's art goes here, and the **Finish** setting
  (opaque, translucent, clear, metallic, glitter) applies to this material.
- **`body`** — everything else: shell, back, edges, spine. The **Material**
  setting (matte, glossy, smoked, metal, rubber) applies here, so the plastic
  and the sticker are controlled separately.

Keep `art` as the first material slot. Anything beyond two materials is
ignored for now.

Re-export after changing the built-in meshes:

```
godot --headless --path godot tools/export_templates.tscn
```

They land in `user://templates`, which on Linux is
`~/.local/share/godot/app_userdata/Shelves/templates`.
