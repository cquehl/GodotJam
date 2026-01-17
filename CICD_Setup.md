# Godot CI/CD Setup for itch.io

This document describes how to set up automatic deployment of a Godot 4.x game to itch.io using GitHub Actions.

## Prerequisites

1. A GitHub repository with your Godot project
2. An itch.io account and game page created
3. An itch.io API key

## Setup Steps

### 1. Get itch.io API Key

1. Go to https://itch.io/user/settings/api-keys
2. Generate a new API key
3. Save it securely

### 2. Add GitHub Secrets

In your GitHub repository, go to **Settings → Secrets and variables → Actions** and add:

| Secret Name | Value |
|-------------|-------|
| `ITCH_USER` | Your itch.io username |
| `ITCH_API_KEY` | Your itch.io API key |

You can set these via CLI:
```bash
gh secret set ITCH_USER -b "your-username"
gh secret set ITCH_API_KEY -b "your-api-key"
```

### 3. Create Export Preset

Create `export_presets.cfg` in your Godot project directory:

```ini
[preset.0]

name="Web"
platform="Web"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="../build/web/index.html"
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false

[preset.0.options]

custom_template/debug=""
custom_template/release=""
variant/extensions_support=false
variant/thread_support=true
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
html/export_icon=true
html/custom_html_shell=""
html/head_include=""
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
html/experimental_virtual_keyboard=false
progressive_web_app/enabled=false
progressive_web_app/offline_page=""
progressive_web_app/display=1
progressive_web_app/orientation=0
progressive_web_app/icon_144x144=""
progressive_web_app/icon_180x180=""
progressive_web_app/icon_512x512=""
progressive_web_app/background_color=Color(0, 0, 0, 1)
```

**Important notes:**
- `export_path` must be set (not empty)
- `variant/thread_support=true` uses the standard web template
- `variant/thread_support=false` uses the `nothreads` variant

### 4. Create GitHub Actions Workflow

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to itch.io

on:
  push:
    branches: [main]
  workflow_dispatch:

env:
  GAME_NAME: "your-game-name"  # Must match your itch.io game URL

jobs:
  export-web:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Export Web
        id: export
        uses: firebelley/godot-export@v7.0.0
        with:
          godot_executable_download_url: https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_linux.x86_64.zip
          godot_export_templates_download_url: https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_export_templates.tpz
          relative_project_path: ./your-project-folder
          archive_output: false

      - name: Copy build to workspace
        run: |
          mkdir -p build/web
          cp -r ${{ steps.export.outputs.build_directory }}/Web/* build/web/

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: web-build
          path: build/web

      - name: Deploy to itch.io
        uses: robpc/itchio-upload-action@v1
        with:
          path: build/web
          project: ${{ secrets.ITCH_USER }}/${{ env.GAME_NAME }}
          channel: html5
          api-key: ${{ secrets.ITCH_API_KEY }}
```

### 5. Update for Your Project

Replace these values:
- `GAME_NAME`: Your itch.io game URL slug (e.g., `my-awesome-game`)
- `relative_project_path`: Path to your Godot project folder containing `project.godot`
- Godot version URLs if using a different version

## Godot Version Compatibility

### Finding Download URLs

Get URLs from: https://github.com/godotengine/godot/releases

Format:
- Executable: `Godot_v{VERSION}-stable_linux.x86_64.zip`
- Templates: `Godot_v{VERSION}-stable_export_templates.tpz`

### Version Examples

**Godot 4.3:**
```yaml
godot_executable_download_url: https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_linux.x86_64.zip
godot_export_templates_download_url: https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_export_templates.tpz
```

**Godot 4.4:**
```yaml
godot_executable_download_url: https://github.com/godotengine/godot/releases/download/4.4-stable/Godot_v4.4-stable_linux.x86_64.zip
godot_export_templates_download_url: https://github.com/godotengine/godot/releases/download/4.4-stable/Godot_v4.4-stable_export_templates.tpz
```

## Troubleshooting

### "Cannot export project with preset due to configuration errors"

This vague error can mean:
1. **Script errors** - Check the full logs for `SCRIPT ERROR` messages
2. **Missing export_path** - Ensure `export_path` is set in `export_presets.cfg`
3. **Type inference issues** - Godot 4.3+ is stricter; use explicit types:
   ```gdscript
   # Bad - may fail in CI
   var width := some_value * 2.0

   # Good - explicit type
   var width: float = some_value * 2.0
   ```

### "No such file or directory" in itch.io deploy

The itch.io Docker action can only access the workspace directory. Copy files first:
```yaml
- name: Copy build to workspace
  run: cp -r ${{ steps.export.outputs.build_directory }}/Web/* build/web/
```

### Build succeeds but uploads 0 files

Check that:
1. The export preset name matches exactly (case-sensitive)
2. `archive_output: false` is set
3. The copy step path is correct

## Multiple Platforms

To export for multiple platforms, add more presets to `export_presets.cfg` and duplicate the workflow steps:

```yaml
- name: Deploy Windows to itch.io
  uses: robpc/itchio-upload-action@v1
  with:
    path: build/windows
    project: ${{ secrets.ITCH_USER }}/${{ env.GAME_NAME }}
    channel: windows
    api-key: ${{ secrets.ITCH_API_KEY }}

- name: Deploy Linux to itch.io
  uses: robpc/itchio-upload-action@v1
  with:
    path: build/linux
    project: ${{ secrets.ITCH_USER }}/${{ env.GAME_NAME }}
    channel: linux
    api-key: ${{ secrets.ITCH_API_KEY }}
```

## Resources

- [firebelley/godot-export](https://github.com/firebelley/godot-export) - Godot export action
- [robpc/itchio-upload-action](https://github.com/robpc/itchio-upload-action) - itch.io upload action
- [Godot Web Export Docs](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)
- [itch.io butler docs](https://itch.io/docs/butler/)
