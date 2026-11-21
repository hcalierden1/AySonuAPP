# Ay Sonu

Ay sonunu rahat getirmek için basit bir gelir-gider takip uygulaması. Günlük harcamalarını ve gelirlerini kaydet, bakiyeni gör, paranın nereye gittiğini takip et.

Flutter ile yazılmış bir Android uygulamasıdır. Tüm veriler yalnızca telefonda saklanır; hesap açmak ya da internet bağlantısı gerekmez.

## Özellikler

- **Gelir ve gider kaydı:** Tutar, kategori, not ve tarih ile kayıt ekle, düzenle ya da sil. Yanlışlıkla silinen kayıt "Geri al" ile geri getirilebilir.
- **Kategoriler:**
  - Gider: Market, Yemek, Ulaşım, Fatura, Kira, Sağlık, Eğlence, Giyim, Eğitim, Diğer
  - Gelir: Maaş, Ek Gelir, Yatırım, Hediye, Diğer
- **Günlük, haftalık ve aylık özet:** Seçtiğin dönemdeki toplam gelir, gider ve mevcut bakiye. Halka grafikle kategori dağılımı, günlere göre gelir-gider grafiği.
- **Takvimde gezinme:** Önceki ve sonraki günler, haftalar ve aylar arasında kolayca geçiş.
- **Sabit gelir / giderler:** Maaş, kira, fatura gibi her ay tekrar edenleri bir kez tanımla (ör. "her ayın 5'inde maaş"). Günü geldiğinde otomatik olarak kaydedilir, önceden bakiyeyi etkilemez.
- **Bildirimden hızlı kayıt:** İsteğe bağlı kalıcı bildirim sayesinde uygulamayı açmadan, bildirim panelinden kayıt ekle. Sadece `250 market` ya da `maaş 42000` yazman yeterli; tutar ve kategori otomatik anlaşılır. Bildirimde günün toplamları da görünür.
- **Yedekleme:** Tüm kayıtları panoya kopyalayarak dışa aktar, istediğin zaman geri yükle.
- **Uygulama turu:** İlk açılışta özellikleri adım adım tanıtan rehber.
- **Açık ve koyu tema:** Telefonun temasına otomatik uyum sağlar.
- Türkçe arayüz, ₺ ve Türkçe tarih biçimi.

## Kurulum

### APK ile (kullanıcılar için)

1. Uygulamanın APK dosyasını telefona indir.
2. Dosyayı aç. Android "bilinmeyen kaynaklardan yükleme" izni isterse ver.
3. Kurulum bitince **Ay Sonu** uygulamasını aç.

Yeni sürüm aynı şekilde mevcut uygulamanın üzerine kurulur, kayıtların silinmez.

### Kaynak koddan derleme (geliştiriciler için)

Gereken: [Flutter](https://docs.flutter.dev/get-started/install) (Dart SDK 3.10 veya üstü) ve Android SDK.

```bash
git clone https://github.com/hcalierden1/AySonuAPP.git
cd AySonuAPP
flutter pub get
flutter run
```

Yayın sürümü APK oluşturmak için:

```bash
flutter build apk --release
```

Oluşan dosya: `build/app/outputs/flutter-apk/app-release.apk`

> İmza anahtarı (`.jks`) ve `android/key.properties` güvenlik nedeniyle bu depoda yer almaz. Kendi anahtarınla imzalamak için Flutter'ın [Android uygulamasını imzalama](https://docs.flutter.dev/deployment/android#signing-the-app) rehberine bakabilirsin.

## Proje yapısı

```
lib/
├── main.dart                 Uygulamanın giriş noktası
├── data/                     Kayıtların telefonda saklanması
├── models/                   Kayıt, kategori ve sabit kayıt modelleri
├── screens/                  Ana ekran, kayıt formu, sabit kayıtlar ekranı
├── services/                 Bildirimden hızlı kayıt
├── utils/                    Dönem hesaplama, tutar ve hızlı giriş çözümleme
└── widgets/                  Halka grafik ve uygulama turu
```

## Sürüm

Güncel sürüm: **1.4.2**
