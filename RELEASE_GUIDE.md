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
- `WINDOWS_PFX_BASE64` optional but recommended
- `WINDOWS_PFX_PASSWORD` optional but recommended

Helper commands for secrets:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("android\\app\\upload-keystore.jks"))
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\\certs\\company-code-sign.pfx"))
```

## Versioning

- Update `version:` in `pubspec.yaml`.
- `1.2.3+45` means:
  - Android: `versionName=1.2.3`, `versionCode=45`
  - Windows MSIX: `1.2.3.45`
- Keep build numbers increasing for every published release.

## GitHub Releases

GitHub Releases is the download source for both Android and Windows.

- Android:
  - The project distributes directly as a signed APK.
  - Upload the release APK to GitHub Releases and use that asset URL in `app_versions.download_url`.
  - Keep the same keystore forever; Android updates require the new APK to be signed with the same key as the installed one.
- Windows:
  - The release workflow now publishes these assets on every tag:
    - versioned ZIP bundle
    - versioned MSIX package
    - stable `istakip-windows.msix`
    - stable `istakip-windows.appinstaller`
    - signing certificate `.cer`
  - The stable App Installer URL is the one that should be used in `app_versions.download_url`.
  - Once the app is installed through `.appinstaller`, future Windows updates can flow through App Installer.

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
    '1.1.2',
    7,
    'https://github.com/alihanylmz/hcs/releases/download/v1.1.2/istakip-android-v1.1.2+7.apk',
    'Android release notes',
    'v1.1.2',
    false
  ),
  (
    'windows',
    '1.1.2',
    7,
    'https://github.com/alihanylmz/hcs/releases/latest/download/istakip-windows.appinstaller',
    'Windows release notes',
    'v1.1.2',
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

## Windows MSIX + App Installer

- The workflow builds the regular Windows runner, then creates an MSIX package and a matching `.appinstaller` file.
- If `WINDOWS_PFX_BASE64` and `WINDOWS_PFX_PASSWORD` are configured, the workflow signs the EXE and the MSIX with your certificate.
- If those secrets are missing, the workflow creates a temporary self-signed certificate and uploads `istakip-windows.cer`.
- On test machines, install that `.cer` first if Windows does not trust the MSIX signature.
- The first Windows migration should be done by opening `istakip-windows.appinstaller`.
- After the app is installed through App Installer once, future releases can be offered through the same stable App Installer URL.

## Release Checklist

After the workflow files in `.github/workflows/` are committed:

1. Update `version:` in `pubspec.yaml`.
2. Commit and push the branch.
3. Create and push the matching tag, for example `v1.1.3`.
4. GitHub Actions will build:
   - `istakip-android-v<version>+<build>.apk`
   - `istakip-windows-v<version>+<build>.zip`
   - `istakip-windows-v<version>+<build>.msix`
   - `istakip-windows-v<version>+<build>.appinstaller`
   - `istakip-windows.appinstaller`
5. The workflow publishes those assets to a GitHub Release automatically.
6. Insert or update matching `app_versions` rows.
7. Smoke test the update prompt on both platforms.

Tag commands:

```powershell
git tag v1.1.3
git push origin main --tags
```

Supabase function deploy is also automated:

- `approve-user` is redeployed automatically when `supabase/functions/approve-user/` changes on `main` or `master`.
- You can also trigger `Deploy Supabase Function` manually from the GitHub Actions tab.
