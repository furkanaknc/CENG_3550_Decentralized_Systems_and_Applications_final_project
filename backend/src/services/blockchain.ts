import { ethers } from 'ethers';
import type { PickupRequest } from '../models';

const pickupManagerAbi = [
  'function assignRole(address user, uint8 role)',
  'function createPickup(string pickupId, string material, uint256 weightKg) returns (bytes32)',
  'function acceptPickup(string pickupId)',
  'function completePickup(string pickupId)',
  'function pickups(bytes32 id) view returns (string pickupId,address user,address courier,uint8 status,string material,uint256 weightKg,uint256 createdAt,uint256 assignedAt,uint256 completedAt)',
  'function userRoles(address user) view returns (uint8)'
];

const greenRewardAbi = [
  'function recordActivity(address user, string material, uint256 weightKg) returns (uint256)',
  'function materialWeights(string material) view returns (uint8)'
];

const PICKUP_STATUS = {
  Pending: 0,
  Assigned: 1,
  Completed: 2,
  Cancelled: 3
} as const;

type PickupLike = Pick<PickupRequest, 'id' | 'material' | 'weightKg'>;

type Config = {
  rpcUrl?: string;
  privateKey?: string;
  pickupManagerAddress?: string;
  greenRewardAddress?: string;
};

type RequiredConfig = Required<Config>;

const ROLE = {
  None: 0,
  User: 1,
  Courier: 2,
  Admin: 3
} as const;

let provider: ethers.JsonRpcProvider | null = null;
let signer: ethers.Wallet | null = null;
let pickupManager: ethers.Contract | null = null;
let greenReward: ethers.Contract | null = null;

export interface OnChainActionResult {
  enabled: boolean;
  userRoleTxHash?: string;
  courierRoleTxHash?: string;
  pickupCreatedTxHash?: string;
  pickupAcceptedTxHash?: string;
  pickupCompletedTxHash?: string;
  rewardTxHash?: string;
  rewardAmount?: string;
}

function readConfig(): Config {
  return {
    rpcUrl: process.env.BLOCKCHAIN_RPC_URL,
    privateKey: process.env.BLOCKCHAIN_PRIVATE_KEY,
    pickupManagerAddress: process.env.PICKUP_MANAGER_ADDRESS,
    greenRewardAddress: process.env.GREEN_REWARD_ADDRESS
  };
}

function getRequiredConfig(): RequiredConfig {
  const config = readConfig();

  if (!config.rpcUrl || !config.privateKey || !config.pickupManagerAddress || !config.greenRewardAddress) {
    throw new Error('Blockchain integration is not fully configured');
  }

  return config as RequiredConfig;
}

function ensureProvider(): ethers.JsonRpcProvider {
  if (!provider) {
    const { rpcUrl } = getRequiredConfig();
    provider = new ethers.JsonRpcProvider(rpcUrl);
  }
  return provider;
}

function ensureSigner(): ethers.Wallet {
  if (!signer) {
    const { privateKey } = getRequiredConfig();
    signer = new ethers.Wallet(privateKey, ensureProvider());
  }
  return signer;
}

function ensurePickupManager(): ethers.Contract {
  if (!pickupManager) {
    const { pickupManagerAddress } = getRequiredConfig();
    pickupManager = new ethers.Contract(pickupManagerAddress, pickupManagerAbi, ensureSigner());
  }
  return pickupManager;
}

function ensureGreenReward(): ethers.Contract {
  if (!greenReward) {
    const { greenRewardAddress } = getRequiredConfig();
    greenReward = new ethers.Contract(greenRewardAddress, greenRewardAbi, ensureSigner());
  }
  return greenReward;
}

function normalizeAddress(address?: string | null): string | null {
  if (!address) {
    return null;
  }

  try {
    return ethers.getAddress(address);
  } catch (error) {
    console.error('Invalid address provided for blockchain sync', { address, error });
    return null;
  }
}

function toOnChainWeight(weightKg: number): bigint {
  return BigInt(Math.round(weightKg * 100));
}

async function getOnChainPickupStatus(pickupId: string): Promise<{ exists: boolean; status: number }> {
  const manager = ensurePickupManager();
  const pickupHash = ethers.id(pickupId);

  try {
    const pickup = await manager.pickups(pickupHash);

    const createdAtRaw = pickup.createdAt ?? pickup[6] ?? 0;
    const statusRaw = pickup.status ?? pickup[3] ?? 0;

    const createdAt =
      typeof createdAtRaw === 'bigint' ? createdAtRaw : ethers.toBigInt(createdAtRaw ?? 0);
    const status =
      typeof statusRaw === 'number'
        ? statusRaw
        : typeof statusRaw === 'bigint'
        ? Number(statusRaw)
        : Number(statusRaw ?? 0);

    return { exists: createdAt > 0n, status };
  } catch (error) {
    console.error('Failed to query on-chain pickup status', { pickupId, error });
    return { exists: false, status: PICKUP_STATUS.Pending };
  }
}

async function ensureRoleAssigned(address: string, role: number): Promise<string | undefined> {
  const manager = ensurePickupManager();
  const currentRoleRaw = await manager.userRoles(address);
  const currentRole = typeof currentRoleRaw === 'number' ? currentRoleRaw : Number(currentRoleRaw);

  if (currentRole === role) {
    return undefined;
  }

  const tx = await manager.assignRole(address, role);
  const receipt = await tx.wait();
  return receipt.hash;
}

async function ensurePickupExists(pickup: PickupLike, userAddress: string): Promise<OnChainActionResult> {
  const summary: OnChainActionResult = { enabled: true };
  const manager = ensurePickupManager();

  const roleTxHash = await ensureRoleAssigned(userAddress, ROLE.User);
  if (roleTxHash) {
    summary.userRoleTxHash = roleTxHash;
  }

  const statusInfo = await getOnChainPickupStatus(pickup.id);

  if (!statusInfo.exists) {
    const weight = toOnChainWeight(pickup.weightKg);
    const tx = await manager.createPickup(pickup.id, pickup.material, weight);
    const receipt = await tx.wait();
    summary.pickupCreatedTxHash = receipt.hash;
  }

  return summary;
}

async function mintReward(userAddress: string, pickup: PickupLike): Promise<{ txHash: string; amount: string }> {
  const rewardContract = ensureGreenReward();
  const weight = toOnChainWeight(pickup.weightKg);
  const multiplierRaw = await rewardContract.materialWeights(pickup.material);
  const multiplier = typeof multiplierRaw === 'number' ? multiplierRaw : Number(multiplierRaw);
  const rewardAmount = (weight * BigInt(multiplier)).toString();

  const tx = await rewardContract.recordActivity(userAddress, pickup.material, weight);
  const receipt = await tx.wait();

  return { txHash: receipt.hash, amount: rewardAmount };
}

export function isBlockchainConfigured(): boolean {
  const config = readConfig();
  return Boolean(
    config.rpcUrl &&
      config.privateKey &&
      config.pickupManagerAddress &&
      config.greenRewardAddress
  );
}

export async function syncPickupAssignment(
  pickup: PickupLike,
  userWallet?: string,
  courierWallet?: string
): Promise<OnChainActionResult> {
  if (!isBlockchainConfigured()) {
    return { enabled: false };
  }

  const userAddress = normalizeAddress(userWallet);
  const courierAddress = normalizeAddress(courierWallet);

  if (!userAddress) {
    throw new Error('Valid user wallet address is required for blockchain assignment');
  }

  if (!courierAddress) {
    throw new Error('Valid courier wallet address is required for blockchain assignment');
  }

  const summary = await ensurePickupExists(pickup, userAddress);
  const statusInfo = await getOnChainPickupStatus(pickup.id);

  const roleTxHash = await ensureRoleAssigned(courierAddress, ROLE.Courier);
  if (roleTxHash) {
    summary.courierRoleTxHash = roleTxHash;
  }

  if (!statusInfo.exists) {
    throw new Error(`Pickup ${pickup.id} could not be created on chain`);
  }

  if (statusInfo.status === PICKUP_STATUS.Assigned || statusInfo.status === PICKUP_STATUS.Completed) {
    return summary;
  }

  const manager = ensurePickupManager();
  const tx = await manager.acceptPickup(pickup.id);
  const receipt = await tx.wait();
  summary.pickupAcceptedTxHash = receipt.hash;

  return summary;
}

export async function syncPickupCompletion(
  pickup: PickupLike,
  userWallet?: string,
  courierWallet?: string
): Promise<OnChainActionResult> {
  if (!isBlockchainConfigured()) {
    return { enabled: false };
  }

  const userAddress = normalizeAddress(userWallet);
  if (!userAddress) {
    throw new Error('Valid user wallet address is required for blockchain completion');
  }

  const summary = await ensurePickupExists(pickup, userAddress);
  const statusInfo = await getOnChainPickupStatus(pickup.id);

  if (!statusInfo.exists) {
    throw new Error(`Pickup ${pickup.id} could not be loaded on chain`);
  }

  if (courierWallet) {
    const courierAddress = normalizeAddress(courierWallet);
    if (!courierAddress) {
      throw new Error('Valid courier wallet address is required for blockchain completion');
    }

    const roleTxHash = await ensureRoleAssigned(courierAddress, ROLE.Courier);
    if (roleTxHash) {
      summary.courierRoleTxHash = summary.courierRoleTxHash ?? roleTxHash;
    }
  }

  if (statusInfo.status === PICKUP_STATUS.Pending) {
    throw new Error('Pickup must be assigned on-chain before completion');
  }

  if (statusInfo.status === PICKUP_STATUS.Assigned) {
    const manager = ensurePickupManager();
    const tx = await manager.completePickup(pickup.id);
    const receipt = await tx.wait();
    summary.pickupCompletedTxHash = receipt.hash;
  }

  const reward = await mintReward(userAddress, pickup);
  summary.rewardTxHash = reward.txHash;
  summary.rewardAmount = reward.amount;

  return summary;
}
