import { expect } from 'chai';
import { ethers } from 'hardhat';

describe('GreenReward', () => {
  it('mints rewards based on recycling activity', async () => {
    const [deployer, user] = await ethers.getSigners();
    const factory = await ethers.getContractFactory('GreenReward');
    const contract = await factory.deploy();
    await contract.waitForDeployment();

    const tx = await contract.recordActivity(user.address, 'plastic', 5);
    await tx.wait();

    const balance = await contract.balanceOf(user.address);
    expect(balance).to.equal(50n);

    const activities = await contract.getUserActivities(user.address);
    expect(activities.length).to.equal(1);
    expect(activities[0].weightKg).to.equal(5n);
  });
});
