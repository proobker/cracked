# Android export boundary

This folder contains the Godot Android template. Generated build outputs are
distinct from first-party gameplay. project.godot and export_presets.cfg
configure exports and plugin integration.

Keep package com.cracked.pro and landscape Android behavior. Signing secrets
belong outside tracked files. [release.md](../release.md) records uploaded
versions and the known project/export version mismatch.

Prefer standard export settings over template-internal edits. Expansion
gameplay belongs in scripts. Check background pause, offline startup,
sign-in and release-signed save compatibility on a real device.
