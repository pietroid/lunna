# Brand

Lunna's source art. The generated files land in the platform folders and
are committed.

| | Lunna |
|---|---|
| Look | light, warm neutrals, red accent |
| Bundle / package | `com.pietroid.lunna[.dev]` |
| Flutter flavors | `lunnaDev`, `lunnaProduction` |
| Env files | `env/lunna.{dev,production}.json` |
| Web | `lunna.pietroteruya.dev` (`lunna-web`) |

## Where it is set

- **Dart:** nothing to pick: `AppColors` in `app_ui` holds Lunna's values.
- **Android:** the `brand` flavor dimension (only `lunna`) in
  `android/app/build.gradle.kts` sets the package and the name;
  `android/app/src/lunna/res` holds the launcher icon and the splash.
- **iOS:** one build configuration per env × mode (`Debug-lunnaDev`,
  `Release-lunnaProduction`, …) and one scheme per flavor. Each sets
  `PRODUCT_BUNDLE_IDENTIFIER`, `FLAVOR_APP_NAME`,
  `ASSETCATALOG_COMPILER_APPICON_NAME` (`AppIcon-lunna`) and
  `LAUNCH_SCREEN_STORYBOARD` (`LaunchScreenLunna`). The Podfile lists
  every configuration, and CocoaPods writes one xcconfig for each, so each
  Runner configuration is based on its own `ios/Flutter/<config>.xcconfig`,
  which includes that Pods file and then `Debug.xcconfig` or
  `Release.xcconfig`. A new configuration needs its file too, or the build
  fails on `/Target Support Files/…xcfilelist`.
- **Web:** `tool/brand_web.sh lunna` after `flutter build web`, which
  fills the placeholders in `web/index.html` and `web/manifest.json` and
  copies `brands/lunna/web/` (icons, favicon, splash) over the build.

## Files

```
lunna/
  mark.svg          the crescent and check, on a 64-unit grid
  icon.svg/.png     launcher icon: the mark at 68% on white
  foreground.svg/.png  Android adaptive foreground: the mark in the safe zone
  splash.png        the mark, for the native splash
  web/              web icons, favicon and splash images
```

The in-app mark (sign-in screen, landing page) is
`packages/app_ui/assets/brand/lunna.png` (`AppAssets.mark`).

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

# Launcher icons (reads flutter_launcher_icons-lunna.yaml)
dart run flutter_launcher_icons

# Native splash (reads flutter_native_splash-lunna.yaml)
dart run flutter_native_splash:create --flavors lunna
```

`flutter_native_splash` also rewrites `ios/Runner/Info.plist`; keep
`UILaunchStoryboardName` as `$(LAUNCH_SCREEN_STORYBOARD)`. The web icons in
`brands/lunna/web/` are plain resizes of `icon.png` (ImageMagick:
`magick icon.png -resize 192x192 web/icons/Icon-192.png`, and so on).
