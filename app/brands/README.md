# Brands

One app, two skins. Everything here is source art; the generated files land
in the platform folders and are committed.

| | Focus | Lunna |
|---|---|---|
| Look | dark, true black, lime accent | light, warm neutrals, red accent |
| Bundle / package | `com.pietroid.focus[.dev]` | `com.pietroid.lunna[.dev]` |
| Flutter flavors | `focusDev`, `focusProduction` | `lunnaDev`, `lunnaProduction` |
| Env files | `env/focus.{dev,production}.json` | `env/lunna.{dev,production}.json` |
| Web | `focus.pietroteruya.dev` (`focus-web`) | `lunna.pietroteruya.dev` (`lunna-web`) |

## What picks the brand

- **Dart:** the `BRAND` define (`focus` or `lunna`), read once by `AppBrand`
  in `app_ui`. Every colour token in `AppColors` is a constant chosen by it,
  so a screen never asks which brand it is in. Typography, spacing and radii
  are the same in both.
- **Android:** the `brand` flavor dimension in `android/app/build.gradle.kts`
  sets the package and the name; `android/app/src/<brand>/res` holds the
  launcher icon and the splash.
- **iOS:** one build configuration per brand × env × mode
  (`Debug-lunnaDev`, `Release-focusProduction`, …) and one scheme per
  flavor. Each sets `PRODUCT_BUNDLE_IDENTIFIER`, `FLAVOR_APP_NAME`,
  `ASSETCATALOG_COMPILER_APPICON_NAME` (`AppIcon-<brand>`) and
  `LAUNCH_SCREEN_STORYBOARD` (`LaunchScreen<Brand>`). The Podfile lists
  every configuration.
- **Web:** `tool/brand_web.sh <brand>` after `flutter build web`, which
  fills the placeholders in `web/index.html` and `web/manifest.json` and
  copies `brands/<brand>/web/` (icons, favicon, splash) over the build.

## Files

```
focus/
  icon.png          launcher icon (and Android adaptive foreground)
  web/              web icons, favicon and splash images
lunna/
  mark.svg          the crescent and check, on a 64-unit grid
  icon.svg/.png     launcher icon: the mark at 68% on white
  foreground.svg/.png  Android adaptive foreground: the mark in the safe zone
  splash.png        the mark, for the native splash
  web/              web icons, favicon and splash images
```

The in-app marks (sign-in screen, landing page) are
`packages/app_ui/assets/brand/<brand>.png`.

## Regenerating

After changing the art, from `app/`:

```bash
# SVG to PNG (headless Chrome keeps the gradients ImageMagick drops)
chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
for n in icon foreground; do
  "$chrome" --headless=new --hide-scrollbars --default-background-color=00000000 \
    --window-size=1024,1024 --screenshot="$PWD/brands/lunna/$n.png" \
    "file://$PWD/brands/lunna/$n.svg"
done

# Launcher icons, every brand (reads flutter_launcher_icons-<brand>.yaml)
dart run flutter_launcher_icons

# Native splash, every brand (reads flutter_native_splash-<brand>.yaml)
dart run flutter_native_splash:create --flavors focus,lunna
```

`flutter_native_splash` also rewrites `ios/Runner/Info.plist`; keep
`UILaunchStoryboardName` as `$(LAUNCH_SCREEN_STORYBOARD)`. The web icons in
`brands/<brand>/web/` are plain resizes of `icon.png` (ImageMagick:
`magick icon.png -resize 192x192 web/icons/Icon-192.png`, and so on).
