# istakip_app

Flutter tabanli is takip, servis operasyonu, partner yonetimi ve takim/Kanban uygulamasi.

## Local Run

Use the local wrapper instead of raw `flutter run`:

```powershell
.\run_local.bat
.\run_local.bat test
.\run_local.bat build-web
```

The wrapper reads `env.txt` locally and injects the required `--dart-define` values.

## Core Docs

- [Permission Matrix](docs/permission-matrix.md)
- [Ticket Lifecycle](docs/ticket-lifecycle.md)
- [Technical Overview](docs/technical-overview.md)
- [Release Process](docs/release-process.md)

## CI

GitHub Actions runs dependency install, analyze, test, and build checks from:

- [flutter_ci.yml](.github/workflows/flutter_ci.yml)
