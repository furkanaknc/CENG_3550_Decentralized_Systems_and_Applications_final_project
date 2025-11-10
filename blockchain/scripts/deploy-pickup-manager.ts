import { ethers } from 'hardhat';

async function main() {
  console.log('Deploying PickupManager contract...');

  const [deployer] = await ethers.getSigners();
  console.log('Deploying with account:', deployer.address);

  const balance = await ethers.provider.getBalance(deployer.address);
  console.log('Account balance:', ethers.formatEther(balance), 'ETH');

  // Deploy PickupManager
  const PickupManager = await ethers.getContractFactory('PickupManager');
  const pickupManager = await PickupManager.deploy();
  await pickupManager.waitForDeployment();

  const address = await pickupManager.getAddress();
  console.log('PickupManager deployed to:', address);

  // Optionally deploy GreenReward as well
  const GreenReward = await ethers.getContractFactory('GreenReward');
  const greenReward = await GreenReward.deploy();
  await greenReward.waitForDeployment();

  const greenRewardAddress = await greenReward.getAddress();
  console.log('GreenReward deployed to:', greenRewardAddress);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
