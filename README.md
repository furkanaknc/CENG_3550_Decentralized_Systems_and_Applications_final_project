# Sürdürülebilir Geri Dönüşüm Platformu

Bu depo, kurye entegrasyonu, harita tabanlı takip ve blokzincir ödül sistemi içeren sürdürülebilir geri
dönüşüm platformunun uçtan uca bileşenlerini barındırır.

## Proje yapısı
- `backend/`: Node.js (TypeScript) tabanlı REST API. Kurye atama, harita servisleri, karbon hesaplama ve PostgreSQL
tablosu için başlangıç şeması içerir.
- `blockchain/`: Hardhat projesi ve `GreenReward` akıllı sözleşmesi. Geri dönüşüm faaliyetlerine göre ERC-20 token
mint eden ödül sistemi.
- `mobile/`: Flutter uygulaması için temel ekranlar. Harita, teslimat talebi ve ödül görünümü içerir.

## Başlangıç
### Backend
```bash
cd backend
npm install
npm test
npm run dev
```

Backend veri tabanı için Docker Compose kullanabilirsiniz:
```bash
cd backend
cp .env.example .env
docker compose up -d postgres
npm run migrate
```
Bu komut PostgreSQL 16 konteynerini başlatır ve varsayılan kimlik bilgilerini `.env` dosyanızdan alır.
`npm run migrate` komutu ise `db/migrations` dizinindeki SQL betiklerini çalıştırarak aşağıdaki tabloları oluşturur:

- `users`: Talep sahiplerini ve biriken `green_points` değerlerini saklar.
- `couriers`: Kurye durumları ile en son bilinen koordinatlarını tutar.
- `recycling_locations`: OSM tabanlı geri dönüşüm noktalarını önbelleğe alır.
- `pickups`: Kurye atama akışındaki toplama isteklerini kayıt altına alır.
- `carbon_reports`: Tamamlanan toplama için hesaplanan karbon tasarrufunu saklar.

### Akıllı Sözleşmeler
```bash
cd blockchain
npm install
npm run build
npm test
```

### Mobil Uygulama
Flutter SDK kurulumunun ardından:
```bash
cd mobile
flutter pub get
flutter test
flutter run
```

Depoda, CI veya konteyner ortamlarında Flutter kurulumunu otomatikleştirmek için bir yardımcı betik de
sunuyoruz. Bu betik varsayılan olarak Flutter 3.22.1 sürümünü indirir ve `mobile/` testlerini çalıştırır:

```bash
./scripts/flutter_test.sh
```

`FLUTTER_VERSION`, `FLUTTER_CHANNEL` veya `FLUTTER_HOME` değişkenleri ile farklı sürüm ya da kurulum yolu
seçebilirsiniz.

## Yol Haritası
- Gerçek Google Maps ve kurye API entegrasyonlarının tamamlanması.
- PostgreSQL bağlantısının yapılandırılması ve veri analiz raporlarının zenginleştirilmesi.
- Mobil istemcinin backend ve blokzincir ile gerçek zamanlı entegrasyonu.
