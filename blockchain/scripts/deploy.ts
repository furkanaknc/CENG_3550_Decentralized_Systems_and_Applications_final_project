import { ethers } from 'hardhat';

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log('Deploying contracts with the account:', deployer.address);

  const factory = await ethers.getContractFactory('GreenReward');
  const contract = await factory.deploy();
  await contract.waitForDeployment();

  console.log('GreenReward deployed to:', await contract.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
