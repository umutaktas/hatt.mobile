# CHANGELOG

## 0.1.3 — Maskot: Mürekkep

- **Yeni maskot "Mürekkep":** Figma'da hazırlanan mürekkep hokkası karakteri
  ("Osmanlıca E-Learning — Mürekkep Maskot") uygulamaya alındı. Placeholder
  "Kamış" SVG'leri silindi, `flutter_svg` bağımlılığı kaldırıldı.
- **5 poz varyantı:** Neutral / Thinking / Celebrate / Encourage pozları
  arka planları şeffaflaştırılıp optimize edilmiş PNG olarak eklendi
  (~50 KB/adet). Eksik uyuyan poz Neutral'dan kapalı-göz türetilerek üretildi
  ve Figma dosyasına "Sleeping" frame'i olarak geri yüklendi. Eşleme:
  normal→Neutral, celebrating→Celebrate, sad→Encourage, sleeping→Sleeping.
- **Maskot animasyonları:** `MascotView` artık duruma özel döngülü animasyon
  oynatıyor (flutter_animate): normal = yumuşak süzülme + rastgele göz kırpma
  (kapalı-göz karesiyle), celebrating = enerjik zıplama + salınım,
  sad = yavaş teselli salınımı, sleeping = nefes alma + süzülen "Zzz".
  `animated: false` veya erişilebilirlik "animasyonları kapat" ayarı statik
  görsele düşürür; golden testler bu yolu kullanır.

## 0.1.2 — Bug turu (3'lü analiz raporu, Adım 1)

Analiz: `docs/ANALIZ-2026-07-15.md` (Claude ✕ agy ✕ codex, çapraz doğrulanmış).

- **Çift-tıklama yarışı kapatıldı:** "Kontrol Et"e hızlı çift dokunuş artık çift
  can/FSRS kaydı üretemez (`_grading` kilidi).
- **Eşleştirme artık cezalı:** yanlış çift can düşürür, loglanır, FSRS'e "again"
  gider; final değerlendirme hatalı çiftleri "good" ile ezmez.
- **0 canla derse giriş engellendi** (review/pratik hariç — can kazanma yolu).
- **Can bittiğinde "Pratik yaparak can kazan"** seçeneği eklendi (sentetik
  review oturumu; yol ilerlemesine yazmaz, canları doldurur).
- **Hata kuyruğu:** yanlış cevaplanan egzersiz dersin sonunda doğru cevaplanana
  dek yeniden sorulur; tekrar sorulan soruların doğrusu "ilk denemede doğru"
  sayılmaz.
- **Hareke tercihi** artık Ayarlar'dan okunuyor (egzersiz içi toggle geçici).
- **Zayıf Nokta Analizi ekranı gerçek:** en çok yanılınan harf/kelimeler
  (FSRS lapses) + egzersiz tipine göre doğruluk çubukları (premium).
- **İçerik sürümlemesi:** şema v2 (`content_version` + migration). Uygulama
  güncellemesiyle gelen yeni müfredat, ilerleme korunarak mevcut kurulumlara
  da yansır (unit test'li).
- **Noto Naskh Arabic asset olarak gömüldü** — Osmanlıca artık tamamen offline
  render edilir (google_fonts'a runtime bağımlılık kalktı).
- Testler: 50 geçiyor; v1→v2 migration gerçek cihaz durumunda doğrulandı.

## 0.1.1 — Ses efektleri + streak hatırlatıcısı

- **Ses efektleri gerçek:** doğru (çift tık), yanlış (yumuşak buzz), ders sonu
  fanfarı, seviye atlama (yükseliş) — sentezlenmiş WAV'lar; seviye atlanınca
  fanfar yerine seviye sesi çalar. iOS simülatöründe doğrulandı.
- **Streak hatırlatıcısı bağlandı:** `flutter_local_notifications` ile günlük
  20:00 yerel bildirimi. Kural saf Dart (`nextStreakReminder`, unit testli):
  bugün çalışıldıysa yarına, çalışılmadıysa bugüne kurulur; korunacak seri
  yoksa hiç kurulmaz. Açılışta ve ders bitiminde yeniden zamanlanır; Android
  manifest izin + boot receiver'ları eklendi.
- Android `label` "Hatt" yapıldı. Testler: 48 geçiyor, analyze temiz.

## 0.1.0 — MVP iskeleti (Faz 1–6)

İlk çalışan sürüm. `flutter analyze` temiz, testler geçiyor.

### Faz 1 — Temel
- Flutter + Riverpod proje iskeleti (feature-first).
- Drift (SQLite) şeması: letters, words, reading_passages/passage_lines,
  curriculum_nodes, node_progress, review_states, user_state, exercise_log (§5).
- JSON → DB seed pipeline (idempotent) + içerik modelleri.
- Tema (mürekkep + altın palet), `OttomanText` widget (min 28sp punto kuralı
  burada zorlanır, RTL, hareke toggle), `MascotState` soyutlaması + SVG placeholder'lar.

### Faz 2 — Öğrenme yolu
- `curriculum.json` şeması + `SCHEMA.md`, 2 ünitelik (13 düğüm) örnek müfredat.
- Dikey yol haritası, düğüm kilidi/ilerleme mantığı (bir ders tamamlanınca sonraki açılır).

### Faz 3 — Ders motoru
- 6 egzersiz tipi, ders oturumu akışı (soru → anında geri bildirim + ses → devam).
- Can/XP hesapları, kombo/hatasız bonus, seviye sistemi, ses + kutlama animasyonları.
- Toleranslı transliterasyon karşılaştırıcısı (â/a, î/i, û/u eşdeğer).
- **Birim testleri:** can, XP, seviye, karşılaştırıcı.

### Faz 4 — Aralıklı tekrar
- FSRS-5 motoru (saf Dart). Vadesi gelen kartlardan dinamik `review` düğümleri,
  kuyruk boşsa zayıf/sık kelimelerden karma pratik. Checkpoint sınavı.
- **Birim testleri:** FSRS zamanlama.

### Faz 5 — Backend (feature flag arkasında)
- Backend-agnostik `LeagueService` (offline + korumalı Firestore stub).
- Haftalık lig mantığı (hafta anahtarı Pzt 00:00 UTC, 5 kademe, terfi/tenzil) saf Dart.
- Lig sekmesi "bağlantı yok" durumu. **Birim testleri:** lig haftası.
- Cloud Functions ve Firestore kuralları ayrı depoda (`umutaktas/hatt`).

### Faz 6 — Onboarding & cila
- KVKK açık rıza onboarding ekranı.
- Ayarlar: ses/hareke toggle, "hesabımı ve verilerimi sil" (tam yerel silme).
- Paywall iskeleti (satın alma feature flag arkasında), `EntitlementService`.
- Streak + günlük hedef gösterimi, profil ekranı.

### Bilinen sınırlamalar
- Firebase entegrasyonu korumalı stub (SDK bağlanmayı bekliyor).
- RevenueCat satın alma akışı placeholder.
- Ses/Lottie asset'leri placeholder; maskot basit SVG.
- Local notification (streak hatırlatıcı) bağımlılığı eklendi, zamanlama bağlanacak.
