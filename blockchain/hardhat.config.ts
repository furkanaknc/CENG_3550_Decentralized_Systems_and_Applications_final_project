import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';

const config: HardhatUserConfig = {
  solidity: {
    version: '0.8.23',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    ds4h: {
      url: process.env.DS4H_RPC_URL || 'https://rpc.ds4h.example',
      accounts: process.env.DS4H_PRIVATE_KEY ? [process.env.DS4H_PRIVATE_KEY] : []
    }
  }
};

export default config;
