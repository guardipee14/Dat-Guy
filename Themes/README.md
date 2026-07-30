# Phoenix themes

Phoenix themes are lightweight, declarative `.phxtheme` ZIP packages. They can
change colors, typography, spacing, the Phoenix logo, and the low-opacity
background image. A theme cannot contain or execute PowerShell, XAML,
executables, or libraries.

Use `Phoenix-Theme-Studio.cmd` to create or install a theme. The Control
Center can also install a package from **Customize > Install .phxtheme**.

PowerShell users can manage packages directly:

```powershell
Get-PhoenixTheme

Install-PhoenixTheme `
    -LiteralPath .\MyTheme.phxtheme `
    -Confirm:$false

Export-PhoenixTheme `
    -ThemeDirectory .\MyThemeSource `
    -DestinationPath .\MyTheme.phxtheme `
    -Confirm:$false
```

## Package layout

```text
theme.json
Assets/
  BrandImage.png
  BackgroundImage.jpg
  FontFile.ttf
  PreviewImage.png
```

Only `theme.json` is required. Asset paths are relative to the package root.
Installed third-party themes are stored under `Themes\Installed` and are
ignored by Git.

## Resource limits

- 128 files maximum
- 8 MB maximum per file
- 25 MB maximum after extraction
- JSON, PNG, JPEG, BMP, ICO, TTF, and OTF files only
- no parent-directory or absolute paths

These limits keep theme loading predictable on low-spec computers and prevent
a theme package from becoming an executable plug-in.
