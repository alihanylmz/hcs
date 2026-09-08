# Supabase yedekleme ve ortam kullanımı

Yedek almak için PostgreSQL `pg_dump` veya Supabase CLI kurulmuş olmalıdır. Veritabanı bağlantı URL'sini repoya yazmayın.

PowerShell oturumunda:

```powershell
$env:SUPABASE_DB_URL = 'postgresql://...'
.\tool\backup_supabase.ps1
```

Script varsayılan olarak `backups/supabase/` altında tarihli custom-format dump ve SHA-256 özeti üretir. Yedek klasörü `.gitignore` içindedir; yedeği ayrıca güvenli, şifreli bir depoya kopyalayın.

Geri yükleme işlemi bu scriptin parçası değildir. Geri yüklemeden önce hedef veritabanının doğru proje olduğundan emin olun ve ayrı bir test veritabanında prova yapın.

## Ortam ayrımı

- Yerel çalışma: kökteki `env.txt` ve `--dart-define`.
- Test/CI: gerçek Supabase veritabanı kullanmadan sahte `SUPABASE_URL`/anon key ile build; testlerde repository injection.
- Canlı: GitHub Secrets veya hosting secret store.
- `SUPABASE_SERVICE_ROLE_KEY` Flutter uygulamasına, `env.txt` örneğine veya CI çıktısına konmaz.

`env.example.txt` yalnız isim ve örnek değer içerir; gerçek anahtar değildir.
