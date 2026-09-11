# Standalone cavern walkthrough — 2026-09-11

Separate Linux x86_64 and Windows x86_64 release exports open directly into
cave_walkthrough.tscn. Each ZIP includes the engine executable, adjacent PCK,
controls/readme, asset notice, Godot third-party notices and build manifest.
No editor, Python, original installation or project checkout is needed to run.
The local ZIPs contain extracted original game artwork and recovered map data;
these remain excluded from this source repository. Packaging is not a grant of
redistribution rights for the original game content.

Preparation from a populated checkout:

```sh
python3 tools/prepare_standalone_demo.py --output /path/to/fresh-build --templates /path/to/templates
godot --headless --path /path/to/fresh-build/project --export-release Linux
godot --headless --path /path/to/fresh-build/project --export-release Windows
```

Use official Godot 4.7.2 release templates linux_release.x86_64 and
windows_release_x86_64.exe. Template archive SHA256:
f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011.
The staging script sets PNG imports to Keep File and explicitly includes JSON
and PNG assets. This preserves raw palette indices for Image.load_from_file.
It stages a separate project; the source checkout still opens the setup scene.
Include Engine.get_license_text(), Engine.get_copyright_info() and
Engine.get_license_info() in the packaged engine notices.

Exported diagnostics use user://captures, normally under the Godot app_userdata
folder for LoL2 Cavern Walkthrough. Editor diagnostics retain res://captures.
Automated direction checks disable live unhandled input so desktop mouse events
cannot change the expected camera heading during an injected key press.

Linux standalone validation on Radeon RX9070XT / Mesa25.2.8:
- Cave loads all2373 wall spans,1939 ceiling faces,1183 ordinary props,
  three special props and four static creature stand-ins.
- Four-view camera/resize/roof/prop compositor check: zero index/marker/RGB
  mismatches across1598400 final pixels.
- All24 camera-relative WASD checks pass; reset clears inherited yaw/roll.
- Short forward walk stays grounded with zero resets.

Windows export completed, but Wine crashed before engine startup in both the
existing and a fresh profile. Native Windows validation is pending with the
user; this is not a Windows runtime pass. No full119-route or broad hardware/
performance certification. Static dummy positions/scale, lighting and some
materials remain provisional; no combat, AI, interactions or audio.
