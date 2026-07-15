# Hatt — Backend Mimari Kararı: Firebase'siz Yol (2026-07-16)

**Karar girdisi:** Firebase kullanılmayacak; backend gerekirse MongoDB ya da
PostgreSQL. **Yöntem:** Üçlü bağımsız analiz (Claude ✕ agy ✕ codex) + çapraz
kontrol. Üç analiz de aynı sonuçta birleşti — aşağıdaki tavsiye oybirliğidir.

---

## Karar Özeti (oybirliği)

| Soru | Karar |
|---|---|
| Veritabanı | **PostgreSQL** (MongoDB değil) |
| Backend | **.NET 9 minimal API + EF Core + Hangfire + JWT** (Utilwork/ConnectAlign yığını) |
| En kritik tasarım kararı | DB seçimi değil: **istemcinin XP toplamı yazmasından vazgeçmek** — XP'yi sunucu hesaplar (server-authoritative) |
| Mevcut Firebase backend'i (`umutaktas/hatt`) | Taşınmaz; **küçük, temiz bir .NET API olarak yeniden kurulur** |
| Mobil etkisi | **Minimal** — Firebase SDK'sı hiç eklenmemişti; servis arayüzleri backend-agnostik |

### Neden PostgreSQL (Mongo değil)?

- İş yükü ilişkisel ve constraint ağırlıklı: haftada tek cohort üyeliği
  (UNIQUE), kapasite, refresh-token rotation, XP event idempotency, settlement
  transaction'ı, KVKK cascade silme.
- Lig sıralaması SQL'de doğal: `ROW_NUMBER() OVER (PARTITION BY cohort ...)`.
- İlerleme yedeği (şemasız blob) için `jsonb` yeterli — Mongo'nun tek avantajı
  ortadan kalkıyor.
- Solo dev için belirleyici: **bilinmeyen bileşen sayısı**. ConnectAlign'daki
  .NET 9 + PostgreSQL + EF Core + Hangfire + JWT + GitHub Actions bilgisi ve
  altyapısı birebir yeniden kullanılır; Mongo ikinci bir veritabanı işletme
  yükü demek.

## Firebase Bileşenlerinin Karşılıkları

| Firebase | Yerine |
|---|---|
| Anonymous Auth | İlk açılışta rastgele `installationId` (secure storage) → `POST /v1/auth/anonymous` → kısa ömürlü access JWT + **rotating refresh token** (DB'de yalnız hash). Donanım/cihaz kimliği KULLANILMAZ. |
| Account linking | Aynı `user_id` üzerinde `anonymous → registered`; e-posta doğrulama kodu / Apple / Google provider token'ı sunucuda doğrulanır. Otomatik merge yok. |
| Firestore lig | `league_weeks / league_cohorts / league_members` tabloları; sıralama window function. |
| Firestore ilerleme yedeği | `progress_backups` tek satır: `jsonb` snapshot + `schema_version` + `content_version` + `revision` (If-Match/409). Yeni cihazda **açık onaylı restore** (sessiz overwrite yok). |
| Scheduled Function (rollover) | **Hangfire** recurring job (Pzt 00:00 UTC) + `pg_advisory_xact_lock` + `league_weeks.status` durum makinesi (idempotent, yeniden çalıştırılabilir). |
| deleteAccount | `DELETE /v1/account` — FK `ON DELETE CASCADE` ile tam silme (Firebase'deki "zombi doküman" sınıfı sorunlar yapısal olarak çözülür). |
| Crashlytics | MVP dışı; öneri: Sentry (ücretsiz katman) ya da yalnız sunucu structured log. |
| Analytics | MVP dışı ya da rızalı, whitelist'li minimal `events:batch` endpoint'i (öneriler: PostHog/Umami). |
| FCM | Zaten kapsam dışıydı (yalnız local notification) — kayıp yok. |

## Server-Authoritative XP (en önemli değişiklik)

Mevcut tasarımın (Firestore rules'un da düzeltemediği) temel zafiyeti:
istemci `weeklyXp` toplamını kendisi yazıyor. REST'e aynen çevrilirse açık
taşınır. Doğrusu:

> İstemci XP toplamı göndermez; **doğrulanabilir eylem** gönderir
> (ders tamamlama). XP'yi sunucu hesaplar.

- `POST /v1/lesson-sessions/{id}/complete` + `Idempotency-Key` → sunucu XP
  formülünü kendi uygular, `xp_events` ledger'ına `UNIQUE(user, source)` ile
  yazar, lig XP'sini aynı transaction'da artırır.
- **Local XP ↔ doğrulanmış lig XP ayrımı:** offline dersler yerel ilerlemeye
  ve seviyeye sayılır; rekabetçi lig XP'si yalnız sunucu-doğrulamalı
  oturumlardan gelir. (Offline-first ile hile korumasının dürüst dengesi.)
- Ek savunmalar: rate limit, imkânsız süre tespiti, günlük doğrulanmış XP
  tavanı, refresh-token reuse tespiti.

## API Taslağı (MVP)

```
POST   /v1/auth/anonymous          POST  /v1/auth/refresh
POST   /v1/auth/link/email/*       POST  /v1/auth/link/{google|apple}
GET    /v1/me    PATCH /v1/me      DELETE /v1/account
GET    /v1/leagues/current         GET   /v1/leagues/current/standings
POST   /v1/lesson-sessions/{id}/complete   (Idempotency-Key)
GET    /v1/progress-backup         PUT   /v1/progress-backup   (revision/ETag)
GET    /health/live                GET   /health/ready
```

## Mobilde Değişecekler (az)

- `FeatureFlags.firebaseEnabled` → semantik adlar: `backendEnabled`,
  `leagueEnabled`, `cloudBackupEnabled`.
- `FirestoreLeagueService` stub'ı → `ApiLeagueService` (dio + auth
  interceptor + secure token store). `LeagueService.submitWeeklyXp` **arayüzden
  kaldırılır** (istemci toplam yazamaz) → yerine `LessonSyncService`.
- Drift'e senkron destek tabloları: `lesson_sessions`
  (local_only/pending/verified), `pending_operations` (retry kuyruğu).
- Ayarlar'daki silme akışı: önce sunucu silme, başarılıysa yerel wipe;
  başarısızsa "yalnız bu cihaz" ile karıştırılmaz (pending-delete durumu).
- Onboarding KVKK metni backend açılınca güncellenmeli ("kişisel veri
  toplanmaz" ifadesi yumuşatılıp anonim kimlik + sunucu logları anlatılmalı).

## Önceliklendirilmiş Uygulama Planı

- **P0 — Temel:** .NET 9 + PostgreSQL iskeleti; anonymous auth + rotating
  refresh; users/devices/refresh_sessions; nickname; `DELETE /account`;
  rate limit + health + structured log; DB backup prosedürü. (Lig şart değil.)
- **P1 — Güvenli lig:** hafta/cohort/üye şeması; hafta ortası katılım;
  server-calculated XP + idempotent ledger; salt-okunur `ApiLeagueService`;
  Hangfire rollover + advisory lock + testler.
- **P2 — Yedek + account linking:** versiyonlu snapshot, revision kontrolü,
  açık restore; e-posta/Apple/Google bağlama.
- **P3 — Telemetri:** rıza modeli + minimal event batch (ya da tamamen erteleme).

## Açık Kararlar (kullanıcı onayı gerekli)

1. **Altyapı:** ConnectAlign'ın sunucusu/PostgreSQL'i paylaşılsın mı (ayrı DB +
   ayrı şema) yoksa Hatt'a izole VPS mi? (Öneri: başlangıçta paylaşım — sıfır
   ek maliyet; izolasyon gelir gelince.)
2. **Abonelik doğrulama:** RevenueCat (hızlı, solo-dev dostu) mu, kendi store
   webhook doğrulamamız mı? (Öneri: RevenueCat — Firebase'siz de çalışır.)
3. **Crash/analytics:** Sentry + erteleme mi, hiçbiri mi? (Öneri: MVP'de yalnız
   sunucu logları; Sentry'yi ilk beta'da ekle.)
4. **Repo:** `umutaktas/hatt` mevcut Firebase içeriği .NET çözümüyle
   değiştirilsin mi? (Öneri: evet — `git mv` ile `legacy-firebase/` altına
   arşivleyip yeni API'yi köke kurmak.)
