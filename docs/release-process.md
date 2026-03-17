# Release Process

## Local Validation

Run the local wrapper script instead of raw `flutter run`:

```powershell
.\run_local.bat
.\run_local.bat test
.\run_local.bat build-web
.\run_local.bat build-windows
.\run_local.bat build-apk
```

The wrapper reads `env.txt` locally and injects the required `--dart-define` values.

## Pre-release Checklist

1. Run `.\run_local.bat test`
2. Run `flutter analyze`
3. Confirm no unintended git changes are present
4. Verify Supabase schema / migration status
5. Confirm Edge Function secrets are up to date
6. Validate update metadata in `app_versions` when shipping desktop/mobile builds

## CI Gates

The repository CI pipeline runs:

1. Dependency install
2. `flutter analyze`
3. `flutter test`
4. `flutter build web`

Optional Windows build is included as a separate job for desktop packaging confidence.

## Production Notes

- Do not ship `env.txt`.
- Do not inject `ONESIGNAL_REST_API_KEY` into client builds.
- Build-time values should be passed through CI or secure release scripts using `--dart-define`.
- Rotate exposed local secrets if they were ever committed or distributed.
