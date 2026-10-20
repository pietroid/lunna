# Instant deploys on the phone with Shorebird

2026-10-20. RFC. Status: proposed (issue #3), written unattended. Phases 1
to 3 done; the deep-research pass (Phase 4) not run.

## Thesis

**Ship every push to `main` to the phones as a Shorebird patch, from the
same workflow that already ships the web and the backend, and keep store
releases for the one change in four that touches native code, assets or
the Flutter version.**

Today the web and the server are live minutes after a push
([`.github/workflows/deploy.yml`](../../../.github/workflows/deploy.yml)),
while the phones get a change only when someone runs `flutter build ipa` /
`appbundle` by hand on the Mac and uploads it
([SETUP.md "Mobile builds"](../../../SETUP.md)). The version in
`app/pubspec.yaml:3` has been `1.0.0+1` since the first commit, so no
build can be told from another. Two things follow: the phone app lags the code,
and the old phone binary talks to a server that moved on. Shorebird closes
that gap for Dart changes: it ships the compiled Dart of a commit to devices
that already run a release built with it, and the patch runs on the next
cold start. Measured on this repo's history, **18 of the 27 commits that
touched `app/` (67%) changed only Dart, and 17 of the 22 (77%) since the
initial import** ([`data/patchable.csv`](./data/patchable.csv), from
[`code/patchable.mjs`](./code/patchable.mjs)). The other five added a
plugin, an Android `<queries>` entry, an iOS permission, an SVG asset, or
the second brand: those still need the stores, and always will.

The move is small because the pipeline is already there: a `patch` job per
brand and platform, after `test`, running `shorebird patch
--flavor <brand>Production --release-version=latest` with the same defines
the release was built with. Releases stay on the Mac, by hand, through a
script that bumps the version and tags the commit. Patches on iOS can be
built unsigned (`--no-codesign`), and the repo is public, so the macOS
runner is free and no Apple certificate goes into CI.

What it does **not** need: Codemagic or fastlane (two manual releases a
week at most, both from a Mac that already signs), a paid Shorebird plan
(the free tier is 5,000 patch installs a month; this app has one allowed
user on two brands), or moving more UI to the server. The agent's surface
is already server-driven A2UI and updates with the backend; the rest of the
app is the timeline, which is better compiled.

## How it works today

```
push to main ──▶ deploy.yml: test ─┬─▶ backend image ─┐
                                   └─▶ web images ────┴─▶ Pi pulls ──▶ web live (minutes)

Mac, by hand ──▶ flutter build ipa|appbundle --flavor <brand>Production
             ──▶ upload to App Store Connect / Play Console ──▶ review ──▶ phone (days)
```

- Four flavors (`focusDev`, `focusProduction`, `lunnaDev`,
  `lunnaProduction`), Android `app/android/app/build.gradle.kts:63-85`,
  iOS schemes in `Runner.xcodeproj/xcshareddata/xcschemes/`.
- Each build is fixed by `--dart-define-from-file env/<brand>.<env>.json`
  (`app/lib/config.dart`). Only the `*.example.json` files are committed;
  the real ones are on the Mac (`git ls-files app/env`).
- Android release signing already reads the keystore from
  `ANDROID_KEYSTORE_*` env vars when set (`build.gradle.kts:44-51`), which
  is what CI needs.
- iOS signs automatically with team `K3U55XXNRM` (`project.pbxproj`).
- Flutter is pinned to **3.44.1**, locally and in CI (`deploy.yml`).
- The app runs Dart in the background too: `workmanager` wakes it every
  ~6 h to refresh reminders (`app/lib/notifications/background_refresh.dart`).
- No CI job builds a phone binary. `pubspec.yaml` version: `1.0.0+1`.

## Diagnosis

| # | Symptom | Root cause | Where |
|---|---------|------------|-------|
| 1 | A fix reaches the web in minutes and the phone in days, or never | Mobile is a manual build and a store upload; no CI job builds it | `SETUP.md` "Mobile builds"; `deploy.yml` has no mobile job |
| 2 | The phone runs older Dart than the server expects | The server deploys on every push; the app only when uploaded. Nothing checks the pair | `deploy.yml` `deploy` job; the interceptor sends only `Authorization` (`api_client/lib/src/interceptors/auth_interceptor.dart:29`) |
| 3 | No record of which build a phone runs | The version is never bumped and no release is tagged | `app/pubspec.yaml:3` |
| 4 | A release can't be reproduced from the repo alone | Production defines live only in uncommitted `env/*.production.json` | `git ls-files app/env` |
| 5 | Some changes can never be patched | Native code, plugins, manifests/Info.plist, Flutter assets and the Flutter version are baked into the binary | `data/patchable.csv`: `ac9782c`, `4392bdd`, `63d4d08`, `5cfcfdb`, `098f447` |

## What the literature says, applied here

1. **What a patch can carry.** Shorebird patches Dart code, including
   pure-Dart packages; it "does not support changing native code", cannot
   add a package with native code, and cannot change the Flutter version
   of a release [1]. *For us:* the ARB strings, the blocs, the timeline,
   the agent's decoder, all patchable; `speech_to_text`, `workmanager`,
   `url_launcher`'s Android `<queries>`, a new SVG in
   `app_ui/assets/` are not.
2. **Assets are not patched yet.** `shorebird patch` warns "The release
   artifact contains asset changes, which will not be included in the
   patch" and asks to continue; patched Dart that needs a new asset will
   find it missing [2]. *For us:* `63d4d08` (the agent icon) would have
   broken as a patch. New icons go in a release, or the Dart falls back
   when the asset is absent.
3. **When a patch runs.** The updater checks once per process, on the
   first engine's start, and the patch boots on the next process start;
   a foreground service or a long-lived process delays it [1][3]. *For
   us:* an iPhone that keeps Lunna suspended for days stays on the old
   Dart. The `workmanager` background wake is a process start too, so it
   can download the patch; the UI still needs a cold start to run it.
4. **CI.** `setup-shorebird` plus `shorebird patch` on `ubuntu-latest`
   for Android, `macos-latest` for iOS; Android needs the release keystore
   on the runner; iOS patches can be built with `--no-codesign`; in CI the
   CLI is non-interactive and *fails* on native diffs unless
   `--allow-native-diffs`; `--release-version=latest` targets the newest
   release; GitHub OIDC replaces a stored `SHOREBIRD_TOKEN` [4][5]. *For
   us:* the patch job needs no Apple secret, one Android keystore secret,
   and no Shorebird secret at all, matching the deploy's "nothing
   long-lived" rule.
5. **Flavors.** `shorebird init` creates one Shorebird app per flavor and
   writes them under `flavors:` in `shorebird.yaml`; every command takes
   `--flavor` [6]. *For us:* four apps, two of which matter
   (`lunnaProduction`, `focusProduction`). Dev flavors run as debug builds
   from `flutter run`, which are never patched.
6. **Defines are code.** Dart defines are compiled into the Dart, so a
   patch built with different defines changes them [5]. *For us:* the
   patch job must rebuild `env/<brand>.production.json` exactly as the
   release had it, or a patch could repoint `API_BASE_URL`.
7. **iOS speed.** On iOS, changed code runs in an interpreter; the linker
   keeps unchanged functions on the CPU. Typical 3.44 patches link 95% of
   code natively, the worst tenth 77%, and "large patches gradually cause
   unexpected slowdowns" as a release drifts [7][8]. *For us:* a patch
   that rewrites the calendar painter or the drag code could jank on
   iPhone. The native changes already force a release every few days
   (5 in 17 days), which resets the drift; between them, keep an eye on
   the link percentage the CLI prints.
8. **Safety.** Each patch is hashed and checked on install and boot; a
   patch that fails to load is marked bad and the release code runs;
   patches can be rolled back from the console; optional patch signing
   embeds a public key in the release so only patches signed with the
   private key load [9]. *For us:* a bad patch costs one launch, not a
   bricked app; signing guards against a leaked Shorebird credential
   pushing code to the phone.
9. **Store rules.** Apple's guideline 2.5.2 forbids downloading code that
   "introduces or changes features or functionality of the app" [10];
   Shorebird's position is that interpreted Dart fits the interpreter
   carve-out as long as patches don't change the app's primary purpose,
   and Play is more permissive [2][1]. *For us:* bug fixes and iterating
   on existing screens are patches; a new tab or capability goes through
   review as a release. (The carve-out lives in Apple's Developer Program
   License Agreement, not in 2.5.2 itself: unverified here, Phase 4.)
10. **Price.** Free: 5,000 patch installs a month; Pro $20 for 50,000. A
    patch install is a successful apply on a device, and several patches
    between launches count once [11][1]. *For us:* well under 100 a month.

## Recommendations

### P1. One release per production flavor, from the Mac

- `shorebird init` in `app/` (needs the CLI: `curl … install.sh | bash`,
  then `shorebird login`). Commit `app/shorebird.yaml`; its `app_id`s are
  not secret [6].
- Check `shorebird flutter versions list` for a 3.44 build. Prefer
  **3.44.9** (newest 3.44 patch, which Shorebird recommends) and bump the CI
  pin in `deploy.yml` with it; 3.44.1 only if it is listed.
- `app/tool/release_mobile.sh <brand>`: bumps `version:` in
  `pubspec.yaml` (`+N` build number), runs
  `shorebird release ios|android --flavor <brand>Production
  --flutter-version=<pin> -- --dart-define-from-file env/<brand>.production.json`,
  and tags the commit `mobile/<brand>/<version>`. Upload as today. Install
  that build on the phone (TestFlight / Play internal testing); a
  `flutter run` build never receives patches.
- Move the production defines to repo variables
  (`LUNNA_GOOGLE_WEB_CLIENT_ID`, …: client IDs are not secrets) and make the
  script and CI write the same `env/<brand>.production.json` from them.

### P1. A `patch` job in `deploy.yml`

```yaml
  patch:
    name: Patch (${{ matrix.brand }}, ${{ matrix.platform }})
    needs: test
    runs-on: ${{ matrix.platform == 'ios' && 'macos-latest' || 'ubuntu-latest' }}
    permissions:
      contents: read
      id-token: write                 # OIDC sign-in to Shorebird
    strategy:
      fail-fast: false
      matrix:
        brand: [focus, lunna]
        platform: [android, ios]
    env:
      SHOREBIRD_PROJECT_ID: ${{ vars.SHOREBIRD_PROJECT_ID }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0              # the release tags, for P2
      - uses: shorebirdtech/setup-shorebird@v1
        with:
          cache: true
      - run: node .tool/mobile-patchable.mjs ${{ matrix.brand }}   # see P2
      - run: # write env/<brand>.production.json from vars, as the web job does
      - run: # Android only: decode ANDROID_KEYSTORE_BASE64 outside the checkout
      - working-directory: app
        run: >
          shorebird patch ${{ matrix.platform }}
          --flavor ${{ matrix.brand }}Production --release-version=latest
          ${{ matrix.platform == 'ios' && '--no-codesign' || '' }}
          -- --dart-define-from-file env/${{ matrix.brand }}.production.json
```

Not in `deploy`'s `needs`: a patch that can't be made must not hold back
the server and the web.

### P2. Decide "patch or release" in the repo, not only in the CLI

Shorebird's native-diff check runs on the built artifact and fails the job
in CI [4]. Whether it sees an `AndroidManifest.xml` `<queries>` change
(`098f447`) or an `Info.plist` permission (`5cfcfdb`) is not documented.
Add `.tool/mobile-patchable.mjs`: the rules of
[`code/patchable.mjs`](./code/patchable.mjs) applied to
`git diff --name-only mobile/<brand>/<latest>..HEAD`. On a native path it
skips the patch and writes "needs a release: <files>" to the job summary
(and the queue's ntfy topic), green, instead of a red build. One rule set,
used by both the measurement and the gate.

### P2. Keep the server compatible with the last release

A patch reaches a phone only on its next cold start (literature 3), so for
a while the server talks to the release's Dart. Additive API changes only;
a field the app needs gets a default on the server until the next release.
Cheap guard: the app sends `X-App-Version: <version>+<patch>` from
`ShorebirdUpdater().readCurrentPatch()` in the Dio interceptor, and the
server logs it, so a breaking change can be checked against what phones
actually run.

### P3. Let the app know a patch is waiting

With `shorebird_code_push`, call `update()` when the app comes back to the
foreground (an iPhone keeps it suspended for days), and when
`checkForUpdate()` says `restartRequired`, show a quiet line in Menu
(`l10n`: e.g. "Atualização pronta. Feche e abra o app."). Menu also shows
the version and patch number. Not needed on day one; auto-update on start
already covers most launches.

### P3. Patch signing

`shorebird release --public-key-path` on the Mac, `shorebird patch
--private-key-path` in CI with the private key as a secret [9]. Worth it
because the repo is public and the phone runs whatever a patch carries.

## Decided unattended

- Scope: the two **production** flavors only; dev flavors stay
  `flutter run`.
- Patches go out on the **same trigger** as the web (push to `main`),
  since that is what "instant" asked for; see decision 1 for a staging step.
- Releases stay **manual on the Mac**; only patches run in CI.
- Signing in to Shorebird from CI with **OIDC**, not a stored token.

## Decisions for you

1. **What triggers a patch.**
   *(recommended)* every push to `main`, straight to `stable`: same as the
   web, nothing to remember. / Push to a `staging` track and promote by
   hand (`shorebird patches promote`): safer, one more step, needs the
   app to pick a track. / `workflow_dispatch` only: no surprise patches,
   loses "instant".
2. **When a commit can't be patched.**
   *(recommended)* skip green and notify "needs a release" (P2). / Fail the
   job red: louder, but red on every push until the release is cut.
3. **Where releases are built.**
   *(recommended)* the Mac, by script: no Apple or Play upload credentials
   in a public repo. / CI with an App Store Connect API key and fastlane:
   fully hands-off, several new secrets, more setup than releases are
   frequent.
4. **Distribution channel.**
   *(recommended)* TestFlight + Play internal testing, if the allow-list is
   just you: no review per release on Play internal, short on TestFlight. /
   Public listings: review on every release, and Apple's "primary purpose"
   rule matters more for patches.
5. **Flutter version.**
   *(recommended)* 3.44.9 on both the release and CI, if Shorebird lists
   it. / Stay on 3.44.1 if listed. / Jump to 3.47: newest, but a bigger
   change than this RFC needs.
6. **Patch signing (P3) now or later.**
   *(recommended)* with the first release: adding it later needs a new
   release anyway, since the key is embedded in the binary. / Later.

## Open question

- How do the phones get a build today: TestFlight and Play internal
  testing, public listings, or `flutter run --release` from the Mac?
  Decision 4 and the first step of Phase 1 depend on it.

## Rollout

| Phase | Ships | Fixes | Size |
|-------|-------|-------|------|
| 0 | Baseline: `node code/patchable.mjs`; note how long the last fix took to reach the phone; `shorebird flutter versions list` | the numbers to compare against | 30 min |
| 1 | CLI, `shorebird init`, `app/shorebird.yaml`, `release_mobile.sh`, defines in repo vars, first release of both brands on both stores' test tracks | #3, #4 | half a day (most of it store upload) |
| 2 | `patch` job in `deploy.yml` (OIDC, keystore secret, `--no-codesign`) + `.tool/mobile-patchable.mjs` | #1, #5 | half a day |
| 3 | `X-App-Version` header and server log; additive-API rule in AGENTS.md | #2 | 1–2 h |
| 4 | `shorebird_code_push`: update on resume, "Atualização pronta" in Menu; patch signing if decided | #2 (the long-suspended phone) | 2–3 h |

## References

1. Shorebird FAQ, <https://docs.shorebird.dev/code-push/faq/>: native code, native packages and the Flutter version need a release; stable channel only; updates check on start and apply on the next process start; Play and App Store positions; patch install definition.
2. Shorebird docs, "Your app contains asset changes" warning and "App Store and Play Store compliance", in <https://docs.shorebird.dev/llms-full.txt>: assets are not patched yet (issue [#318](https://github.com/shorebirdtech/shorebird/issues/318)); the interpreter carve-out reading of 2.5.2.
3. Shorebird docs, "Checking for updates" (multiple engines, `auto_update: false`, foreground services), same file: one check per process, patch is for the next start.
4. Shorebird docs, CI: generic, <https://docs.shorebird.dev/code-push/ci/generic/>: `--no-codesign` for iOS releases and patches, non-interactive mode fails on native diffs, `--release-version=latest`, `--dry-run`.
5. Shorebird docs, CI: GitHub Actions, <https://docs.shorebird.dev/code-push/ci/github/>: `setup-shorebird`, `macos-latest` for iOS, Android keystore on the runner, OIDC with `SHOREBIRD_PROJECT_ID` (Shorebird ≥ 1.6.129); defines passed after `--` and compiled into patches.
6. Shorebird docs, Android and iOS flavors guides, <https://docs.shorebird.dev/code-push/guides/flavors/ios/>: one app per flavor under `flavors:` in `shorebird.yaml`; `--flavor` on every command; `app_id` is not secret.
7. Shorebird docs, Patch Performance, <https://docs.shorebird.dev/code-push/performance/>: changed code runs interpreted on iOS; inlining and type-flow analysis can spread a small change.
8. E. Seidel, "Shorebird's ongoing iOS performance work", 2026-07-23, <https://shorebird.dev/blog/shorebirds-ongoing-performance-work>: link percentage 95% typical / 77% worst 10% on 3.44; drift grows with patches.
9. Shorebird docs, "Patch integrity and automatic rollback" and "Patch Signing", in <https://docs.shorebird.dev/llms-full.txt>: hash check, bad-patch fallback, rollback, `--public-key-path` / `--private-key-path`.
10. Apple App Review Guidelines 2.5.2, <https://developer.apple.com/app-store/review/guidelines/#software-requirements>: no downloaded code that changes features or functionality.
11. Shorebird pricing, <https://shorebird.dev/pricing/>: Free 5,000 patch installs/month, Pro $20 / 50,000, unlimited apps and releases.

## Unverified (for a Phase 4 pass)

- Whether Shorebird has published a build of Flutter **3.44.1** or only
  later 3.44 patches (needs the CLI: `shorebird flutter versions list`).
- Whether its native-diff check catches `AndroidManifest.xml` and
  `Info.plist`-only changes (P2 guards either way).
- The exact Apple text of the interpreter carve-out (DPLA §3.3), which
  Shorebird attributes to 2.5.2.
- That `shorebird patch android` needs the release keystore on the runner
  (the docs say so; the patch artifact itself is not an APK).
