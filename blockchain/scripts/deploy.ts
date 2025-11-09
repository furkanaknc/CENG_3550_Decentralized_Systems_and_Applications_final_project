import { ethers } from 'hardhat';

async function main() {
  const [deployer] = await ethers.getSigners();

  const factory = await ethers.getContractFactory('GreenReward');
  const contract = await factory.deploy();
  await contract.waitForDeployment();
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
