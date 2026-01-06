# GreenReward Smart Contracts

This Hardhat workspace contains the on-chain incentive logic for the recycling platform. The `GreenReward`
contract mints ERC-20 tokens whenever a verified recycling activity is submitted by the backend orchestration
service.

## Key capabilities
- Configurable material multipliers to reward high-impact recycling (electronics, metals, etc.).
- Transparent activity log stored on-chain per user.
- Deployment script and sample tests targeting the DS4H-compatible network.

## Usage
```bash
cd blockchain
npm install
npm run build
npm test
```

To deploy to DS4H, configure `DS4H_RPC_URL` and `DS4H_PRIVATE_KEY` environment variables and run:
```bash
npx hardhat run scripts/deploy.ts --network ds4h
```
