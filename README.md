# 🌱 Green Cycle - Blockchain Tabanlı Geri Dönüşüm Platformu

Bu proje, MetaMask cüzdan entegrasyonu, kurye yönetimi, harita tabanlı takip ve blockchain ödül sistemi içeren sürdürülebilir bir geri dönüşüm platformudur.

## ✨ Özellikler

- 🦊 **MetaMask ile Kimlik Doğrulama**: Şifresiz, blockchain tabanlı güvenli giriş
- 👥 **Rol Bazlı Yetkilendirme**: User, Courier ve Admin rolleri
- 🚚 **Kurye Yönetimi**: Gerçek zamanlı talep kabul ve tamamlama
- 📍 **Harita Entegrasyonu**: OpenStreetMap ile geri dönüşüm noktaları
- ⛓️ **Smart Contract**: Ethereum Sepolia test ağında çalışan pickup yönetimi
- 🎁 **Ödül Sistemi**: Geri dönüşüm aktivitelerine göre token kazanımı
- 📱 **Flutter Web**: Chrome tarayıcı üzerinde çalışan modern UI

## 📁 Proje Yapısı

- `backend/`: Node.js (TypeScript) REST API servisi
  - Wallet tabanlı kimlik doğrulama
  - Rol bazlı yetkilendirme middleware
  - Kurye atama ve pickup yönetimi
  - PostgreSQL veritabanı
  
- `blockchain/`: Hardhat blockchain projesi
  - `GreenReward.sol`: ERC-20 ödül token kontratı
  - `PickupManager.sol`: Pickup yönetimi ve kurye atama kontratı
  - Sepolia test network desteği
  
- `mobile/`: Flutter web uygulaması
  - MetaMask entegrasyonu
  - Login/logout sistemi
  - Kullanıcı ve kurye arayüzleri
  - Web3 blockchain etkileşimi

## 🚀 Hızlı Başlangıç

### Gereksinimler

- Node.js 18+ ve npm
- Docker ve Docker Compose
- Flutter SDK 3.3.0+
- Chrome tarayıcı
- MetaMask eklentisi

### 1. Backend Kurulumu
```bash
cd backend
npm install

# PostgreSQL veritabanını başlat
docker compose up -d postgres

# Database migration'ları çalıştır
npm run migrate

# Geliştirme sunucusunu başlat
npm run dev
```

**Not:** Backend varsayılan olarak `http://localhost:4000` adresinde çalışır.

#### Veritabanı Tabloları

Migration'lar aşağıdaki tabloları oluşturur:

- `users`: Kullanıcı bilgileri, wallet adresleri ve roller
- `couriers`: Kurye bilgileri ve lokasyonları
- `recycling_locations`: Geri dönüşüm merkezi lokasyonları
- `pickups`: Toplama talepleri ve durumları
- `carbon_reports`: Karbon tasarruf raporları

### 2. Blockchain (Smart Contracts) Kurulumu

```bash
cd blockchain
npm install

# Kontratları derle
npm run build

# Testleri çalıştır
npm test

# Sepolia test ağına deploy (opsiyonel)
# Önce .env dosyasını oluştur ve private key ekle
npx hardhat run scripts/deploy-pickup-manager.ts --network sepolia
```

**Sepolia Test Network için:**
1. `.env` dosyası oluştur
2. Private key'inizi ekleyin (test cüzdanı kullanın!)
3. [Sepolia Faucet](https://sepoliafaucet.com/) ile test ETH alın
4. Deploy scriptini çalıştırın

### 3. Frontend (Flutter Web) Kurulumu

```bash
cd mobile
flutter pub get

# Web için çalıştır (Chrome)
flutter run -d chrome

# Veya production build
flutter build web
```

**Önemli:** `.env` dosyasını oluşturun:
```bash
# mobile/.env
API_BASE_URL=http://localhost:4000
```

### 4. MetaMask Kurulumu

Detaylı MetaMask kurulum talimatları için [METAMASK_KULLANIM_KILAVUZU.md](METAMASK_KULLANIM_KILAVUZU.md) dosyasını okuyun.

**Hızlı Adımlar:**
1. Chrome'a [MetaMask eklentisi](https://metamask.io/download/) yükleyin
2. Yeni cüzdan oluşturun veya mevcut cüzdanı içe aktarın
3. Sepolia Test Network ekleyin
4. [Faucet](https://sepoliafaucet.com/) ile test ETH alın
5. Green Cycle uygulamasına giriş yapın

## 🔐 Kullanıcı Rolleri

### User (Kullanıcı)
- Geri dönüşüm talepleri oluşturabilir
- Haritada noktaları görüntüleyebilir
- Ödül puanlarını takip edebilir

### Courier (Kurye)
- Bekleyen talepleri görüntüleyebilir
- Talepleri kabul edebilir
- Talepleri tamamlayabilir

### Admin (Yönetici)
- Tüm yetkiler
- Kullanıcı rollerini yönetebilir
- Smart contract'ları yönetebilir

**Not:** İlk giriş yapan kullanıcılar otomatik olarak "user" rolü alır. Courier veya admin olmak için veritabanında manuel rol ataması gerekir.

## 🧪 Test Kullanıcıları

Database migration'ları demo hesaplar oluşturur:

- **Admin:** `0xAdminWalletAddressHere`
- **Courier 1:** `0xCourierWallet1Here`
- **Courier 2:** `0xCourierWallet2Here`
- **User:** `0xUserWallet1Here`

**Not:** Bu demo adresleri üretim için geçerli değildir, backend çalıştıktan sonra gerçek MetaMask cüzdan adresleriyle değiştirin.

## 🛠️ API Endpoints

### Auth
- `POST /api/auth/login` - MetaMask ile giriş
- `GET /api/auth/profile` - Kullanıcı profili

### Pickups
- `POST /api/pickups` - Yeni talep oluştur
- `GET /api/pickups` - Tüm talepleri listele

### Couriers
- `GET /api/couriers` - Kuryeler listesi
- `GET /api/couriers/pickups/pending` - Bekleyen talepler (courier)
- `POST /api/couriers/pickups/:id/accept` - Talep kabul et (courier)
- `POST /api/couriers/pickups/:id/complete` - Talep tamamla (courier)

### Maps
- `GET /api/maps/nearby` - Yakındaki geri dönüşüm noktaları

### Analytics
- `GET /api/analytics` - Kullanıcı istatistikleri

## 📚 Dokümantasyon

- [MetaMask Kullanım Kılavuzu (Türkçe)](METAMASK_KULLANIM_KILAVUZU.md)
- [Backend API Dokümantasyonu](backend/README.md)
- [Smart Contract Dokümantasyonu](blockchain/README.md)
- [Flutter Web Geliştirme Notları](mobile/README.md)

## 🐛 Sorun Giderme

### Backend bağlantı hatası
- Backend'in çalıştığından emin olun (`http://localhost:4000`)
- PostgreSQL container'ının çalıştığından emin olun
- `.env` dosyasında doğru bağlantı ayarları olduğunu kontrol edin

### MetaMask bağlanamıyor
- MetaMask eklentisinin yüklü olduğunu kontrol edin
- Sepolia ağında olduğunuzdan emin olun
- Tarayıcı konsolunda hata mesajlarını kontrol edin

### Smart contract hatası
- Sepolia ağında yeterli test ETH'iniz olduğundan emin olun
- Contract adreslerinin doğru olduğunu kontrol edin
- Gas limit ayarlarını kontrol edin

## 🤝 Katkıda Bulunma

1. Fork edin
2. Feature branch oluşturun (`git checkout -b feature/amazing-feature`)
3. Değişikliklerinizi commit edin (`git commit -m 'Add amazing feature'`)
4. Branch'inizi push edin (`git push origin feature/amazing-feature`)
5. Pull Request açın

## 📄 Lisans

Bu proje MIT lisansı altında lisanslanmıştır.

## 🙏 Teşekkürler

- OpenStreetMap topluluğu
- Ethereum ve Sepolia test network
- MetaMask ekibi
- Flutter ve Dart ekibi
