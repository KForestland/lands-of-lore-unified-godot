# Standalone cavern walkthrough — 2026-09-12

Current Act 1 controls, save locations and named limits are in the [player guide](act-one-player-guide.md). Include that guide with the next candidate alongside its build identifier and verification results. The dated results below describe the September build, not the current Act 1 runtime or a newly qualified package.

Separate Linux x86_64 and Windows x86_64 release exports verify the user's
original game executable before opening cave_walkthrough.tscn. Each ZIP includes the engine executable, adjacent PCK,
controls/readme, asset notice, Godot third-party notices and build manifest.
An original game installation is required. No editor, Python or project checkout is needed to run.
The local ZIPs contain extracted original game artwork and recovered map data;
these remain excluded from this source repository. Packaging is not a grant of
redistribution rights for the original game content.

On first launch, select `LOLG.EXE` from the original game installation using
Browse or enter its path. The supported local GOG baseline is 2847 bytes with
SHA-256 `cbd225cebc81cfbf06272456492686340d95c0148b5db9a0acca3c58653902f6`.
This agrees with the RE baseline recorded on 2026-04-25. Other editions are
rejected until their hashes are independently verified and added. A matching
filename alone is insufficient. The executable is read locally, never run,
copied into the package or uploaded. Only its path is saved in
`user://original_game.cfg`; the bytes are verified again at every launch.
Missing, unreadable or changed files keep the startup screen open.
For automated runs, pass `-- --original-game-exe=/path/to/LOLG.EXE`.

Release exports carry `original_game_required`; the walkthrough also checks
the session verification state before initializing, so selecting that scene
directly does not skip verification. Source/editor research scenes remain
available for development. This is a file-possession check, not proof of
purchase or a tamper-resistant DRM system. Original artwork and map data are
still included in the PCK; this change does not remove those assets.

2026-09-12 verification: the Godot validator accepts the baseline and rejects
empty/missing paths, truncation and a same-size one-byte mutation. Linux package
startup checks cover first launch, valid selection, remembered valid path,
remembered changed/missing file; the official release template rejects direct
scene-path overrides before startup. Both
platforms export successfully. On 2026-09-12, the user reported that the demo
works as intended on two Windows computers (functional pass).

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

Windows: user-reported functional pass on two computers (2026-09-12).
OS versions, GPUs and detailed test steps were not supplied. Earlier Wine
startup failures in existing and fresh profiles remain historical environment
results. No full119-route or broad hardware/performance certification. Static dummy positions/scale, lighting and some
materials remain provisional; no combat, AI, interactions or audio.
