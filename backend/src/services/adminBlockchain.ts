import { ethers } from "ethers";
import { isBlockchainConfigured } from "./blockchain";

const greenRewardAbi = [
  "function setMaterialWeight(string calldata material, uint8 weight) external",
  "function materialWeights(string material) view returns (uint8)",
  "function totalSupply() view returns (uint256)",
  "function balanceOf(address account) view returns (uint256)",
];

const pickupManagerAbi = [
  "function assignRole(address user, uint8 role) external",
  "function userRoles(address user) view returns (uint8)",
  "function getPickupCount() view returns (uint256)",
  "function courierActivePickups(address courier) view returns (uint256)",
];

const ROLE_ENUM = {
  None: 0,
  User: 1,
  Courier: 2,
  Admin: 3,
} as const;

const MATERIALS = [
  "plastic",
  "glass",
  "paper",
  "metal",
  "electronics",
] as const;

type RoleName = "None" | "User" | "Courier" | "Admin";

let provider: ethers.JsonRpcProvider | null = null;
let signer: ethers.Wallet | null = null;
let greenReward: ethers.Contract | null = null;
let pickupManager: ethers.Contract | null = null;

function getConfig() {
  return {
    rpcUrl: process.env.BLOCKCHAIN_RPC_URL,
    privateKey: process.env.BLOCKCHAIN_PRIVATE_KEY,
    greenRewardAddress: process.env.GREEN_REWARD_ADDRESS,
    pickupManagerAddress: process.env.PICKUP_MANAGER_ADDRESS,
  };
}

function ensureProvider(): ethers.JsonRpcProvider {
  if (!provider) {
    const { rpcUrl } = getConfig();
    if (!rpcUrl) throw new Error("BLOCKCHAIN_RPC_URL not configured");
    provider = new ethers.JsonRpcProvider(rpcUrl);
  }
  return provider;
}

function ensureSigner(): ethers.Wallet {
  if (!signer) {
    const { privateKey } = getConfig();
    if (!privateKey) throw new Error("BLOCKCHAIN_PRIVATE_KEY not configured");
    signer = new ethers.Wallet(privateKey, ensureProvider());
  }
  return signer;
}

function ensureGreenReward(): ethers.Contract {
  if (!greenReward) {
    const { greenRewardAddress } = getConfig();
    if (!greenRewardAddress)
      throw new Error("GREEN_REWARD_ADDRESS not configured");
    greenReward = new ethers.Contract(
      greenRewardAddress,
      greenRewardAbi,
      ensureSigner()
    );
  }
  return greenReward;
}

function ensurePickupManager(): ethers.Contract {
  if (!pickupManager) {
    const { pickupManagerAddress } = getConfig();
    if (!pickupManagerAddress)
      throw new Error("PICKUP_MANAGER_ADDRESS not configured");
    pickupManager = new ethers.Contract(
      pickupManagerAddress,
      pickupManagerAbi,
      ensureSigner()
    );
  }
  return pickupManager;
}

export async function getMaterialWeight(material: string): Promise<number> {
  if (!isBlockchainConfigured()) {
    throw new Error("Blockchain not configured");
  }

  const contract = ensureGreenReward();
  const weight = await contract.materialWeights(material);
  return Number(weight);
}

export async function getAllMaterialWeights(): Promise<Record<string, number>> {
  if (!isBlockchainConfigured()) {
    throw new Error("Blockchain not configured");
  }

  const contract = ensureGreenReward();
  const weights: Record<string, number> = {};

  for (const material of MATERIALS) {
    const weight = await contract.materialWeights(material);
    weights[material] = Number(weight);
  }

  return weights;
}

export async function setMaterialWeight(
  material: string,
  weight: number
): Promise<{ txHash: string; material: string; weight: number }> {
  if (!isBlockchainConfigured()) {
    throw new Error("Blockchain not configured");
  }

  if (weight < 0 || weight > 255) {
    throw new Error("Weight must be between 0 and 255");
  }

  const contract = ensureGreenReward();

  try {
    const tx = await contract.setMaterialWeight(material, weight);
    const receipt = await tx.wait();

    return {
      txHash: receipt.hash,
      material,
      weight,
    };
  } catch (error: any) {
    if (
      error.code === "UNKNOWN_ERROR" &&
      error.error?.message === "already known"
    ) {
      return { txHash: "pending", material, weight };
    }
    throw error;
  }
}

export async function getUserRoleOnChain(address: string): Promise<RoleName> {
  if (!isBlockchainConfigured()) {
    throw new Error("Blockchain not configured");
  }

  const contract = ensurePickupManager();
  const normalizedAddress = ethers.getAddress(address);
  const roleNum = await contract.userRoles(normalizedAddress);

  const roles: RoleName[] = ["None", "User", "Courier", "Admin"];
  return roles[Number(roleNum)] || "None";
}

export async function assignRoleOnChain(
  address: string,
  role: "User" | "Courier" | "Admin"
): Promise<{ txHash: string; address: string; role: string }> {
  if (!isBlockchainConfigured()) {
    throw new Error("Blockchain not configured");
  }

  const contract = ensurePickupManager();
  const normalizedAddress = ethers.getAddress(address);
  const roleNum = ROLE_ENUM[role];

  try {
    const tx = await contract.assignRole(normalizedAddress, roleNum);
    const receipt = await tx.wait();

    return {
      txHash: receipt.hash,
      address: normalizedAddress,
      role,
    };
  } catch (error: any) {
    if (
      error.code === "UNKNOWN_ERROR" &&
      error.error?.message === "already known"
    ) {
      return { txHash: "pending", address: normalizedAddress, role };
    }
    throw error;
  }
}

export interface BlockchainStats {
  totalPickups: number;
  totalRewardsDistributed: string;
  blockchainConfigured: boolean;
}

export async function getBlockchainStats(): Promise<BlockchainStats> {
  if (!isBlockchainConfigured()) {
    return {
      totalPickups: 0,
      totalRewardsDistributed: "0",
      blockchainConfigured: false,
    };
  }

  try {
    const pickupContract = ensurePickupManager();
    const rewardContract = ensureGreenReward();

    const [pickupCount, totalSupply] = await Promise.all([
      pickupContract.getPickupCount(),
      rewardContract.totalSupply(),
    ]);

    return {
      totalPickups: Number(pickupCount),
      totalRewardsDistributed: totalSupply.toString(),
      blockchainConfigured: true,
    };
  } catch (error) {
    console.error("Failed to get blockchain stats:", error);
    return {
      totalPickups: 0,
      totalRewardsDistributed: "0",
      blockchainConfigured: true,
    };
  }
}

export async function getCourierActivePickupsOnChain(
  address: string
): Promise<number> {
  if (!isBlockchainConfigured()) {
    return 0;
  }

  const contract = ensurePickupManager();
  const normalizedAddress = ethers.getAddress(address);
  const count = await contract.courierActivePickups(normalizedAddress);
  return Number(count);
}
