# Release Guide

## One-Time Setup

Add these GitHub repository secrets once, then releases can be created by pushing a version tag.

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY` or `SUPABASE_KEY`
- `ONESIGNAL_APP_ID` optional
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

## Versioning

- Update `version:` in `pubspec.yaml`.
- `1.2.3+45` means:
  - Android: `versionName=1.2.3`, `versionCode=45`
  - Windows: release package version `1.2.3+45`
- Keep build numbers increasing for every published release.

## GitHub Releases

GitHub Releases is the download source for both Android and Windows.

- Android:
  - The project distributes directly as a signed APK.
  - Upload the release APK to GitHub Releases and use that asset URL in `app_versions.download_url`.
  - Keep the same keystore forever; Android updates require the new APK to be signed with the same key as the installed one.
- Windows:
  - Flutter Windows cannot be distributed as only a single `.exe`; the full runner folder is required.
  - The release workflow publishes a versioned ZIP bundle and a stable `istakip-windows.zip` asset on every tag.
  - Use the stable ZIP URL in `app_versions.download_url` so the app can always open the latest package.
  - Windows updates are manual: the app shows a notification, the user downloads the ZIP, extracts it, and replaces the old installation files.

## App Update Table

Run `migration_app_versions_platform_support.sql` and insert one row per platform release.

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
    '1.1.7',
    12,
    'https://github.com/alihanylmz/hcs/releases/download/v1.1.7/istakip-android-v1.1.7+12.apk',
    'Android release notes',
    'v1.1.7',
    false
  ),
  (
    'windows',
    '1.1.7',
    12,
    'https://github.com/alihanylmz/hcs/releases/latest/download/istakip-windows.zip',
    'Windows release notes',
    'v1.1.7',
    false
  );
```

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

## Windows Manual Update

- The workflow builds the regular Windows runner and packages the full folder as ZIP.
- Publish or share `istakip-windows.zip` with users.
- When the app shows an update prompt, the user downloads the ZIP, extracts it, closes the old app, and replaces the old installation folder with the new files.
- This is a notified manual update flow, not an automatic installer.

## Release Checklist

After the workflow files in `.github/workflows/` are committed:

1. Update `version:` in `pubspec.yaml`.
2. Commit and push the branch.
3. Create and push the matching tag, for example `v1.1.7`.
4. GitHub Actions will build:
   - `istakip-android-v<version>+<build>.apk`
   - `istakip-windows-v<version>+<build>.zip`
   - `istakip-windows.zip`
5. The workflow publishes those assets to a GitHub Release automatically.
6. Insert or update matching `app_versions` rows.
7. Smoke test the update prompt on both platforms.

Tag commands:

```powershell
git tag v1.1.7
git push origin main --tags
```

Supabase function deploy is also automated:

- `approve-user` is redeployed automatically when `supabase/functions/approve-user/` changes on `main` or `master`.
- You can also trigger `Deploy Supabase Function` manually from the GitHub Actions tab.
