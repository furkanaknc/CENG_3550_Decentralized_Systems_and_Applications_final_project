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
```
Bu komut PostgreSQL 16 konteynerini başlatır ve varsayılan kimlik bilgilerini `.env` dosyanızdan alır.

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

## Yol Haritası
- Gerçek Google Maps ve kurye API entegrasyonlarının tamamlanması.
- PostgreSQL bağlantısının yapılandırılması ve veri analiz raporlarının zenginleştirilmesi.
- Mobil istemcinin backend ve blokzincir ile gerçek zamanlı entegrasyonu.
