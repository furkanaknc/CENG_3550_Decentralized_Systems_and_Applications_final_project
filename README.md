# 🌱 Green Cycle - Blockchain-Based Recycling Platform

A sustainable recycling platform with MetaMask wallet integration, courier management, map-based tracking, blockchain rewards, and a coupon system. This project proposes a hybrid recycling model combining courier-based waste collection and map-based drop-off points to increase user participation in recycling. Unlike existing centralized recycling apps, our system uses decentralized incentives and automated verification.

## ✨ Features

- 🦊 **MetaMask Authentication**: Passwordless, blockchain-based secure login
- 👥 **Role-Based Authorization**: User, Courier, and Admin roles
- 🚚 **Courier Management**: Real-time pickup request acceptance and completion
- 📍 **Map Integration**: OpenStreetMap with recycling point locations
- ⛓️ **Smart Contracts**: Pickup management running on Ethereum Sepolia testnet
- 🎁 **Reward System**: ERC-20 token rewards for recycling activities
- 🎟️ **Coupon System**: Redeem green points for partner coupons
- 📱 **Flutter Web**: Modern UI running on Chrome browser

## 📁 Project Structure

```
blockchain-project/
├── backend/          # Node.js (TypeScript) REST API
├── blockchain/       # Hardhat smart contracts (Solidity)
├── mobile/           # Flutter web application
└── scripts/          # Utility scripts
```

---

# 🔧 Backend

The backend is a Node.js/TypeScript REST API that handles authentication, pickup management, courier operations, and blockchain integration.

## Tech Stack

- **Runtime**: Node.js 18+
- **Language**: TypeScript
- **Framework**: Express.js
- **Database**: PostgreSQL
- **Blockchain**: ethers.js (v6)

## Directory Structure

```
backend/
├── src/
│   ├── controllers/     # Request handlers
│   ├── db/              # Database client & migrations
│   ├── jobs/            # Background workers
│   ├── middleware/      # Auth & role middleware
│   ├── models/          # TypeScript interfaces
│   ├── repositories/    # Database queries
│   ├── routes/          # API route definitions
│   ├── services/        # Business logic
│   └── utils/           # Helper functions
├── db/migrations/       # SQL migration files
├── tests/               # Jest test files
└── docker-compose.yml   # PostgreSQL container
```

## Database Tables

| Table                 | Description                                   |
| --------------------- | --------------------------------------------- |
| `users`               | User accounts with wallet addresses and roles |
| `couriers`            | Courier information and current locations     |
| `pickups`             | Pickup requests with status and location      |
| `recycling_locations` | Recycling center locations                    |
| `carbon_reports`      | Carbon savings reports                        |
| `coupons`             | Available coupons with point costs            |
| `user_coupons`        | User-purchased coupons with codes             |

## API Endpoints

### Authentication

| Method | Endpoint            | Description               |
| ------ | ------------------- | ------------------------- |
| POST   | `/api/auth/login`   | Login with wallet address |
| GET    | `/api/auth/profile` | Get user profile          |

### Pickups

| Method | Endpoint       | Description           |
| ------ | -------------- | --------------------- |
| POST   | `/api/pickups` | Create pickup request |
| GET    | `/api/pickups` | List all pickups      |

### Couriers

| Method | Endpoint                             | Description                    |
| ------ | ------------------------------------ | ------------------------------ |
| GET    | `/api/couriers/pickups/pending`      | Get pending pickups            |
| GET    | `/api/couriers/my-pickups`           | Get assigned pickups           |
| POST   | `/api/couriers/pickups/:id/accept`   | Accept a pickup                |
| POST   | `/api/couriers/pickups/:id/complete` | Complete a pickup              |
| GET    | `/api/couriers/nonce`                | Get courier's blockchain nonce |

### Coupons

| Method | Endpoint                    | Description                  |
| ------ | --------------------------- | ---------------------------- |
| GET    | `/api/coupons`              | List available coupons       |
| POST   | `/api/coupons/:id/purchase` | Purchase coupon with points  |
| GET    | `/api/coupons/my`           | Get user's purchased coupons |

### Admin

| Method | Endpoint                    | Description          |
| ------ | --------------------------- | -------------------- |
| GET    | `/api/admin/dashboard`      | Dashboard statistics |
| GET    | `/api/admin/users`          | List all users       |
| PATCH  | `/api/admin/users/:id/role` | Update user role     |
| DELETE | `/api/admin/users/:id`      | Delete user          |
| GET    | `/api/admin/coupons`        | List all coupons     |
| POST   | `/api/admin/coupons`        | Create coupon        |
| PATCH  | `/api/admin/coupons/:id`    | Update coupon        |
| DELETE | `/api/admin/coupons/:id`    | Delete coupon        |

### Maps & Analytics

| Method | Endpoint           | Description                 |
| ------ | ------------------ | --------------------------- |
| GET    | `/api/maps/nearby` | Get nearby recycling points |
| GET    | `/api/maps/all`    | Get all recycling points    |
| GET    | `/api/analytics`   | Get user analytics & points |

## Setup

```bash
cd backend
npm install

# Start PostgreSQL
docker compose up -d postgres

# Run migrations
npm run migrate

# Start development server
npm run dev
```

Server runs on `http://localhost:4000`

## Environment Variables

```env
DATABASE_URL=postgresql://admin:secret@localhost:5432/recycle
JWT_SECRET=your-secret-key

# Blockchain Integration
BLOCKCHAIN_RPC_URL=https://sepolia.infura.io/v3/<PROJECT_ID>
BLOCKCHAIN_PRIVATE_KEY=0x<operator-private-key>
PICKUP_MANAGER_ADDRESS=0x87E2d4e74aD436F80b885042b71CdfeC54E7DE68
GREEN_REWARD_ADDRESS=0xd2F0f24694601c6836CA8944995B00FfE3288Ea0
```

---

# ⛓️ Blockchain

Smart contracts built with Hardhat, deployed on Ethereum Sepolia testnet.

## Ethereum Standards Used

This project implements several Ethereum Improvement Proposals (EIPs) and OpenZeppelin contracts:

### ERC-20 (Token Standard)

**Used in:** `GreenReward.sol`

ERC-20 is the most widely used token standard on Ethereum. It defines a common interface for fungible tokens.

| Function                         | Description                                   |
| -------------------------------- | --------------------------------------------- |
| `balanceOf(address)`             | Returns the token balance of an account       |
| `transfer(to, amount)`           | Transfers tokens to another address           |
| `approve(spender, amount)`       | Approves a spender to use tokens              |
| `transferFrom(from, to, amount)` | Transfers tokens on behalf of another address |
| `totalSupply()`                  | Returns total token supply                    |

**In our project:** GRT (Green Reward Token) is minted when users complete recycling activities. The token can be viewed in MetaMask and potentially traded.

---

### EIP-712 (Typed Structured Data Signing)

**Used in:** `PickupManager.sol`

EIP-712 enables secure off-chain message signing with human-readable data. Instead of signing raw bytes, users see exactly what they're signing in MetaMask.

**Why we use it:**

- Couriers sign pickup acceptance/completion without paying gas
- Backend can submit signatures on behalf of couriers
- Prevents replay attacks with nonces and deadlines
- User-friendly: MetaMask shows structured data instead of hex

**Our Type Definitions:**

```solidity
bytes32 private constant ACCEPT_TYPEHASH =
    keccak256("AcceptPickup(string pickupId,address courier,uint256 nonce,uint256 deadline)");

bytes32 private constant COMPLETE_TYPEHASH =
    keccak256("CompletePickup(string pickupId,address courier,uint256 nonce,uint256 deadline)");
```

**Flow:**

1. Courier clicks "Accept Pickup" in mobile app
2. MetaMask opens with human-readable message
3. Courier signs the typed data
4. Signature is sent to backend
5. Backend submits to blockchain with `acceptPickupWithSig()`

---

### Ownable (Access Control)

**Used in:** Both contracts

OpenZeppelin's Ownable pattern restricts certain functions to the contract owner (deployer).

| Modifier                      | Description                           |
| ----------------------------- | ------------------------------------- |
| `onlyOwner`                   | Only contract owner can call          |
| `transferOwnership(newOwner)` | Transfer ownership to another address |
| `renounceOwnership()`         | Permanently remove owner              |

**Protected functions in our contracts:**

- `GreenReward.setMaterialWeight()` - Only owner can change multipliers
- `GreenReward.recordActivity()` - Only owner can mint tokens
- `PickupManager.assignRole()` - Only owner can assign roles

---

### ECDSA (Elliptic Curve Digital Signature Algorithm)

**Used in:** `PickupManager.sol`

ECDSA is used to recover the signer's address from a signature. Combined with EIP-712, it enables gasless transactions.

```solidity
address signer = ECDSA.recover(digest, v, r, s);
require(signer == courier, "Invalid courier signature");
```

**Security features:**

- Nonce tracking prevents replay attacks
- Deadline prevents stale signatures
- Signature validation ensures authenticity

---

## Contracts

### GreenReward.sol (ERC-20 Token)

An ERC-20 token contract that rewards users for recycling activities.

**Features:**

- Material-based reward multipliers
- Configurable weights by admin
- Activity history tracking

**Material Multipliers (Default):**
| Material | Multiplier |
|----------|------------|
| Plastic | 10x |
| Glass | 12x |
| Paper | 8x |
| Metal | 15x |
| Electronics | 20x |

**Reward Calculation:**

```
reward = weightKg × materialMultiplier
```

**Key Functions:**

```solidity
function setMaterialWeight(string material, uint8 weight) external onlyOwner
function recordActivity(address user, string material, uint256 weightKg) external onlyOwner
function getUserActivities(address user) external view returns (RecyclingActivity[])
```

### PickupManager.sol

Manages pickup lifecycle and courier assignments on-chain with EIP-712 signature verification.

**Pickup States:**

```
Pending → Assigned → Completed
                  ↘ Cancelled
```

**User Roles:**
| Role | Permissions |
|------|-------------|
| None | Default, auto-upgraded to User |
| User | Create pickups |
| Courier | Accept and complete pickups |
| Admin | All permissions + role management |

**Key Functions:**

```solidity
function createPickup(string pickupId, string material, uint256 weightKg) external
function acceptPickup(string pickupId) external onlyCourier
function acceptPickupWithSig(string pickupId, address courier, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external
function completePickup(string pickupId) external onlyCourier
function completePickupWithSig(string pickupId, address courier, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external
function assignRole(address user, UserRole role) external onlyOwner
```

**Events:**

```solidity
event PickupCreated(bytes32 indexed pickupIdHash, string pickupId, address indexed user, string material, uint256 weightKg)
event PickupAssigned(bytes32 indexed pickupIdHash, string pickupId, address indexed courier, uint256 timestamp)
event PickupCompleted(bytes32 indexed pickupIdHash, string pickupId, address indexed courier, uint256 timestamp)
event RoleAssigned(address indexed user, UserRole role)
```

## Setup

```bash
cd blockchain
npm install

# Compile contracts
npm run build

# Run tests
npm test

# Deploy to Sepolia
npx hardhat run scripts/deploy-pickup-manager.ts --network sepolia
```

## Environment Variables

```env
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/<PROJECT_ID>
PRIVATE_KEY=0x<deployer-private-key>
```

---

# 📱 Mobile (Flutter Web)

A Flutter web application with MetaMask and WalletConnect integration.

## Tech Stack

- **Framework**: Flutter 3.3+
- **Language**: Dart
- **Maps**: flutter_map (OpenStreetMap)
- **Wallet**: MetaMask (web), WalletConnect (mobile)
- **QR Codes**: qr_flutter

## Screens

| Screen                 | Description                              |
| ---------------------- | ---------------------------------------- |
| `LoginScreen`          | MetaMask/WalletConnect authentication    |
| `MapScreen`            | Interactive map with recycling locations |
| `PickupRequestScreen`  | Create new pickup requests               |
| `RewardsScreen`        | View points, coupons, and purchases      |
| `CourierPickupsScreen` | Courier-specific pickup management       |
| `AdminScreen`          | Admin dashboard and management           |

## Features by Role

### 👤 User Role

Users can create recycling pickup requests and earn green points.

**Available Screens:**

| Screen      | Features                                                                                                                                                                                                                                |
| ----------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Map**     | • View all recycling locations on interactive OpenStreetMap<br>• See location details (accepted materials)<br>• Find nearby recycling points                                                                                            |
| **Pickup**  | • Select material type (plastic, glass, paper, metal, electronics)<br>• Enter weight in kg<br>• Add address details (neighborhood, district, city)<br>• Submit pickup request<br>• View nearby drop-off suggestions                     |
| **Rewards** | • View current green points balance<br>• See total carbon savings (CO₂ kg)<br>• Browse available coupons with point costs<br>• Purchase coupons using points<br>• View purchased coupons with codes<br>• Copy coupon codes to clipboard |

**Navigation Bar:** Map → Pickup → Rewards

---

### 🚚 Courier Role

Couriers accept and complete pickup requests, earning on each delivery.

**Available Screens:**

| Screen       | Features                                                                                                                                                                                                                                                                                                       |
| ------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Requests** | • View all pending pickup requests<br>• See material type and weight<br>• See pickup address and location<br>• Accept pickup (triggers MetaMask EIP-712 signature)<br>• View accepted pickups in "My Pickups" tab<br>• Complete pickup (triggers blockchain transaction)<br>• Pull-to-refresh for new requests |
| **Map**      | • View recycling locations<br>• See pickup locations on map                                                                                                                                                                                                                                                    |

**Navigation Bar:** Requests → Map

**Blockchain Integration:**

- Accepting a pickup requires signing an EIP-712 typed message via MetaMask
- Completing a pickup records the transaction on Sepolia blockchain
- Courier nonce is tracked to prevent replay attacks

---

### 👑 Admin Role

Admins have full platform control with a comprehensive dashboard.

**Available Screens (5 Tabs):**

| Tab           | Features                                                                                                                                                                                                                                   |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Dashboard** | • Total users count (by role: user/courier/admin)<br>• Pickup statistics (pending/assigned/completed)<br>• Active couriers count<br>• Blockchain connection status<br>• Total on-chain pickups<br>• Total rewards distributed (GRT tokens) |
| **Users**     | • List all registered users<br>• See wallet addresses and green points<br>• Change user roles (user → courier → admin)<br>• Delete users (with confirmation)<br>• "You" badge for current admin                                            |
| **Pickups**   | • View all pickup requests<br>• See status (pending/assigned/completed)<br>• See user name and material details                                                                                                                            |
| **Rewards**   | • View material reward multipliers<br>• Edit multipliers (triggers blockchain transaction)<br>• See blockchain transaction confirmation<br>• Real-time multiplier updates on-chain                                                         |
| **Coupons**   | • List all coupons (active/inactive)<br>• Edit coupon point costs<br>• Delete coupons<br>• See partner names and discount values                                                                                                           |

**Navigation Bar:** Admin → Map

**Admin-Only Actions:**

- Change any user's role
- Update blockchain material weights
- Manage coupon catalog
- View platform-wide statistics

## Setup

```bash
cd mobile
flutter pub get

# Create .env file
echo "API_BASE_URL=http://localhost:4000" > .env
echo "PICKUP_MANAGER_ADDRESS=0x<contract-address>" >> .env

# Run on Chrome
flutter run -d chrome

# Build for production
flutter build web
```

## Key Services

| Service         | Description                           |
| --------------- | ------------------------------------- |
| `AuthService`   | Authentication and session management |
| `ApiService`    | REST API communication                |
| `WalletService` | WalletConnect integration             |
| `metamask.dart` | MetaMask web3 integration             |

---

# 🚀 Quick Start

## Prerequisites

- Node.js 18+ and npm
- Docker and Docker Compose
- Flutter SDK 3.3.0+
- Chrome browser
- MetaMask browser extension

## 1. Start Backend

```bash
cd backend
npm install
docker compose up -d postgres
npm run migrate
npm run dev
```

## 2. Deploy Contracts (Optional)

```bash
cd blockchain
npm install
npm run build
npx hardhat run scripts/deploy-pickup-manager.ts --network sepolia
```

## 3. Start Frontend

```bash
cd mobile
flutter pub get
# Create .env with API_BASE_URL=http://localhost:4000
flutter run -d chrome
```

## 4. MetaMask Setup

1. Install [MetaMask extension](https://metamask.io/download/)
2. Create or import wallet
3. Add Sepolia Test Network
4. Get test ETH from [Sepolia Faucet](https://sepoliafaucet.com/)
5. Connect to Green Cycle app

---

# 🔐 User Roles

| Role        | Description                                             |
| ----------- | ------------------------------------------------------- |
| **User**    | Create pickups, view map, earn points, purchase coupons |
| **Courier** | Accept and complete pickups, blockchain signing         |
| **Admin**   | Full access, user management, contract configuration    |

First-time users are automatically assigned the "user" role. Courier or admin roles require manual assignment via the admin panel or database.

---

# 🎟️ Coupon System

Users can redeem their green points for partner coupons:

| Example Coupons | Partner   | Points |
| --------------- | --------- | ------ |
| 25₺ Gift Card   | BİM       | 400    |
| Free Drink      | Starbucks | 450    |
| 10% Discount    | Migros    | 500    |
| 15% Discount    | Gratis    | 600    |
| 50₺ Gift Card   | A101      | 750    |
| 100₺ Discount   | Trendyol  | 1000   |

Admins can manage coupons (add, edit point costs, delete) via the admin panel.

---

# 🐛 Troubleshooting

### Backend connection error

- Ensure backend is running (`http://localhost:4000`)
- Check PostgreSQL container is running
- Verify `.env` connection settings

### MetaMask not connecting

- Verify MetaMask extension is installed
- Ensure you're on Sepolia network
- Check browser console for errors

### Smart contract error

- Ensure you have enough Sepolia test ETH
- Verify contract addresses are correct
- Check gas limit settings
---

# System Architecture Diagram

![System Architecture](https://github.com/furkanaknc/CENG_3550_Decentralized_Systems_and_Applications_final_project/blob/d1f43a5e9c502ce76c3987fd56f990ea274b1b4f/system_architecture_diagram.jpg?raw=true)

---

---

# 📄 License

This project is licensed under the MIT License.

---

# 🙏 Acknowledgments

- OpenStreetMap community
- Ethereum and Sepolia testnet
- MetaMask team
- Flutter and Dart team
- OpenZeppelin contracts
