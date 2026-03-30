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
- `WINDOWS_PFX_BASE64` optional
- `WINDOWS_PFX_PASSWORD` optional

Helper commands for secrets:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("android\\app\\upload-keystore.jks"))
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\\certs\\company-code-sign.pfx"))
```

## Versioning

- Update `version:` in `pubspec.yaml`.
- `1.2.3+45` means:
  - Android: `versionName=1.2.3`, `versionCode=45`
  - Windows: file/product version `1.2.3.45`
- Keep build numbers increasing separately for Android and Windows releases in `app_versions`.

## GitHub Releases

GitHub Releases can be used as the download source for both Android and Windows.

- Android:
  - This project currently distributes directly as a signed APK.
  - Upload the release APK to GitHub Releases and use that asset URL in `app_versions.download_url`.
  - Keep the same keystore forever; Android updates require the new APK to be signed with the same key as the installed one.
- Windows:
  - GitHub Releases is a good fit for signed `.exe`, `.msi`, or `.zip` assets.
  - The current app opens the download URL externally; it does not do silent in-place updates.
  - The release workflow packages the full Windows bundle as a `.zip`, which is safer than uploading only the `.exe`.

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
    '1.2.0',
    12,
    'https://github.com/alihanylmz/hcs/releases/download/v1.2.0/istakip-android-v1.2.0+12.apk',
    'Android release notes',
    'v1.2.0',
    false
  ),
  (
    'windows',
    '1.2.0',
    27,
    'https://github.com/alihanylmz/hcs/releases/download/v1.2.0/istakip-windows-v1.2.0+27.zip',
    'Windows release notes',
    'v1.2.0',
    false
  );
```

## Android Signing

- Copy `android/key.properties.example` to `android/key.properties`.
- Create your release keystore outside git and point `storeFile` to it.
- The project now uses release signing automatically when `android/key.properties` exists.
- Without a release keystore, Gradle falls back to debug signing. Do not publish builds signed that way.
- For friend/internal distribution, build and share the release APK. `appbundle` is not required.
- GitHub Actions can build the signed APK automatically from `ANDROID_*` secrets, so you do not need to create the APK locally every time.

```powershell
flutter build apk --release
```

## Windows Signing

- Build the Windows release artifact first.
- Sign the generated `.exe` or installer with a code-signing certificate.
- Timestamp the signature so it stays valid after certificate expiry.
- If no Windows certificate secrets are configured, the workflow still publishes the unsigned Windows bundle zip.

```powershell
flutter build windows --release
signtool sign /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 /a build\windows\x64\runner\Release\istakip_app.exe
```

If you package with MSIX or an installer, sign that final artifact too.

## Release Checklist

After the workflow files in `.github/workflows/` are committed:

1. Update `version:` in `pubspec.yaml`.
2. Commit and push the branch.
3. Create and push the matching tag, for example `v1.1.0`.
4. GitHub Actions will build:
   - `istakip-android-v<version>+<build>.apk`
   - `istakip-windows-v<version>+<build>.zip`
5. The workflow publishes both assets to a GitHub Release automatically.
6. Insert or update matching `app_versions` rows for `android` and `windows`.
7. Smoke test the update prompt on both platforms.

Tag commands:

```powershell
git tag v1.1.0
git push origin main --tags
```

Supabase function deploy is also automated:

- `approve-user` is redeployed automatically when `supabase/functions/approve-user/` changes on `main` or `master`.
- You can also trigger `Deploy Supabase Function` manually from the GitHub Actions tab.

