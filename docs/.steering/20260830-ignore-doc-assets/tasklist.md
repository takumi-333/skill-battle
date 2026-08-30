# Task list

- [x] Record the request in request.md
- [x] Add `docs/.gdignore`
- [x] Add `*.import` to `.gitignore`
- [x] Remove existing `docs/**/*.import` files from Git tracking
- [x] Verify Git ignore behavior and Godot file scanning

## Retrospective

実施日: 2026-08-30

- `docs/.gdignore` excludes issue images from Godot scanning.
- `.gitignore` excludes generated import metadata from future tracking.
- Existing `docs/issues/*.import` files were removed from both the Git index and working tree.
- Godot headless scanning completed. Certificate-store and editor-settings save errors were environment-specific and unrelated to project file scanning.
