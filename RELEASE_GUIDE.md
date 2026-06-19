# Release Guide

## One-Time Setup

Add these GitHub repository secrets once, then releases can be created by pushing a version tag.

### GitHub repository secrets

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY` or `SUPABASE_KEY`
- `ONESIGNAL_APP_ID` optional for app builds
- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_STORE_PASSWORD`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_PROJECT_REF`

Helper command for the Android keystore secret:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("android\app\upload-keystore.jks"))
```

### Supabase Edge Function secrets

`send-notification` function needs these Supabase project secrets:

- `ONESIGNAL_REST_API_KEY`
- `ONESIGNAL_APP_ID`
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

Example:

```powershell
supabase secrets set ONESIGNAL_REST_API_KEY="<REST_API_KEY>" ONESIGNAL_APP_ID="<ONESIGNAL_APP_ID>" --project-ref <PROJECT_REF>
```

## Update Checks

App update popup is now disabled by default.

- No popup is shown unless you explicitly enable it.
- Android update checks only run if you pass:

```powershell
--dart-define=ENABLE_APP_UPDATE_CHECK=true
```

- Windows update checks stay off unless you explicitly pass:

```powershell
--dart-define=ENABLE_WINDOWS_UPDATE_CHECK=true
```

## Versioning

- Update `version:` in `pubspec.yaml`.
- `1.2.3+45` means:
  - Android: `versionName=1.2.3`, `versionCode=45`
  - Windows installer release: `1.2.3+45`
- Keep build numbers increasing for every published release.

## GitHub Releases

GitHub Releases is the download source for both Android and Windows.

- Android:
  - The project distributes directly as a signed APK.
  - Upload the release APK to GitHub Releases and use that asset URL in `app_versions.download_url`.
  - Keep the same keystore forever; Android updates require the new APK to be signed with the same key as the installed one.
- Windows:
  - Flutter Windows cannot be distributed as only the app `.exe`; the full runner folder is required.
  - The release workflow publishes a versioned setup installer EXE and a stable `istakip-windows-setup.exe` asset on every tag.
  - The workflow also publishes ZIP bundles as fallback.
  - Use the stable setup EXE URL in `app_versions.download_url` so the app can always open the latest installer.
  - Windows updates stay manual: the app shows a notification, the user downloads the installer EXE, closes the old app if needed, and runs the setup file.

## App Update Table

Run `migration_app_versions_platform_support.sql` and `migration_app_versions_guardrails.sql`, then insert one row per platform release.

```sql
insert into public.app_versions (
  platform,
  version_name,
  build_number,
  download_url,
  release_notes,
  github_tag,
  is_mandatory
) values
  (
    'android',
    '1.1.8',
    13,
    'https://github.com/alihanylmz/hcs/releases/download/v1.1.8/istakip-android-v1.1.8+13.apk',
    'Android release notes',
    'v1.1.8',
    false
  ),
  (
    'windows',
    '1.1.8',
    13,
    'https://github.com/alihanylmz/hcs/releases/latest/download/istakip-windows-setup.exe',
    'Windows installer release notes',
    'v1.1.8',
    false
  );
```

Guardrails added by `migration_app_versions_guardrails.sql`:

- only `all`, `android`, `windows` are valid platform values
- platform values must be lowercase and trimmed
- `version_name`, `build_number`, and `download_url` cannot be empty
- duplicate `(platform, build_number)` rows are removed once and blocked going forward

## Android Signing

- Copy `android/key.properties.example` to `android/key.properties`.
- Create your release keystore outside git and point `storeFile` to it.
- The project uses release signing automatically when `android/key.properties` exists.
- Without a release keystore, Gradle falls back to debug signing. Do not publish builds signed that way.
- For friend/internal distribution, build and share the release APK. `appbundle` is not required.
- GitHub Actions can build the signed APK automatically from `ANDROID_*` secrets, so you do not need to create the APK locally every time.

```powershell
flutter build apk --release
```

## Windows Installer Update

- The workflow builds the regular Windows runner and then packages it with Inno Setup as a single installer EXE.
- Publish or share `istakip-windows-setup.exe` with users.
- When the app shows an update prompt, the user downloads the installer, runs it, and completes the setup.
- This is not silent auto-update; it is a notified manual installer flow.

## Release Checklist

After the workflow files in `.github/workflows/` are committed:

1. Update `version:` in `pubspec.yaml`.
2. Commit and push the branch.
3. Create and push the matching tag, for example `v1.1.8`.
4. GitHub Actions will build:
   - `istakip-android-v<version>+<build>.apk`
   - `istakip-windows-v<version>+<build>-setup.exe`
   - `istakip-windows-setup.exe`
   - `istakip-windows-v<version>+<build>.zip`
   - `istakip-windows.zip`
5. The workflow publishes those assets to a GitHub Release automatically.
6. Insert or update matching `app_versions` rows.
7. Smoke test the update prompt on both platforms.

Tag commands:

```powershell
git tag v1.1.8
git push origin main --tags
```

Supabase function deploy is also automated:

- `approve-user` and `send-notification` are redeployed automatically when their folders change on `main` or `master`.
- You can also trigger `Deploy Supabase Functions` manually from the GitHub Actions tab.
