import { expect } from "chai";
import { ethers } from "hardhat";
import { Signer } from "ethers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { PickupManager } from "../typechain-types";

const ACCEPT_TYPES = {
  AcceptPickup: [
    { name: "pickupId", type: "string" },
    { name: "courier", type: "address" },
    { name: "nonce", type: "uint256" },
    { name: "deadline", type: "uint256" },
  ],
};

const COMPLETE_TYPES = {
  CompletePickup: [
    { name: "pickupId", type: "string" },
    { name: "courier", type: "address" },
    { name: "nonce", type: "uint256" },
    { name: "deadline", type: "uint256" },
  ],
};

describe("PickupManager meta-transactions", function () {
  async function deployFixture() {
    const [owner, courier, backend, user] = await ethers.getSigners();
    const PickupManagerFactory = await ethers.getContractFactory("PickupManager");
    const contract = (await PickupManagerFactory.deploy()) as PickupManager;
    await contract.waitForDeployment();

    return { contract, owner, courier, backend, user };
  }

  async function signAccept(
    contract: PickupManager,
    pickupId: string,
    courier: Signer,
    deadline: bigint
  ) {
    const nonce = await contract.nonces(await courier.getAddress());

    const network = await ethers.provider.getNetwork();
    const signature = await courier.signTypedData(
      {
        name: "PickupManager",
        version: "1",
        chainId: network.chainId,
        verifyingContract: await contract.getAddress(),
      },
      ACCEPT_TYPES,
      {
        pickupId,
        courier: await courier.getAddress(),
        nonce,
        deadline,
      }
    );

    return ethers.Signature.from(signature);
  }

  async function signComplete(
    contract: PickupManager,
    pickupId: string,
    courier: Signer,
    deadline: bigint
  ) {
    const nonce = await contract.nonces(await courier.getAddress());

    const network = await ethers.provider.getNetwork();
    const signature = await courier.signTypedData(
      {
        name: "PickupManager",
        version: "1",
        chainId: network.chainId,
        verifyingContract: await contract.getAddress(),
      },
      COMPLETE_TYPES,
      {
        pickupId,
        courier: await courier.getAddress(),
        nonce,
        deadline,
      }
    );

    return ethers.Signature.from(signature);
  }

  it("allows accepting a pickup with a courier signature", async function () {
    const { contract, owner, courier, backend, user } = await deployFixture();

    await expect(contract.connect(owner).assignRole(await courier.getAddress(), 2)).to.emit(
      contract,
      "RoleAssigned"
    );

    await contract.connect(user).createPickup("PK-1", "Plastic", 100);

    const deadline = BigInt(Math.floor(Date.now() / 1000) + 3600);
    const sig = await signAccept(contract, "PK-1", courier, deadline);

    await expect(
      contract
        .connect(backend)
        .acceptPickupWithSig("PK-1", await courier.getAddress(), deadline, sig.v, sig.r, sig.s)
    )
      .to.emit(contract, "PickupAssigned")
      .withArgs(ethers.keccak256(ethers.toUtf8Bytes("PK-1")), "PK-1", await courier.getAddress(), anyValue);

    const pickup = await contract.getPickup("PK-1");
    expect(pickup.courier).to.equal(await courier.getAddress());
    expect(pickup.status).to.equal(1);
    expect(await contract.courierActivePickups(await courier.getAddress())).to.equal(1n);
  });

  it("prevents signature replay and supports completion via signature", async function () {
    const { contract, owner, courier, backend, user } = await deployFixture();

    await contract.connect(owner).assignRole(await courier.getAddress(), 2);
    await contract.connect(user).createPickup("PK-2", "Paper", 200);

    const acceptDeadline = BigInt(Math.floor(Date.now() / 1000) + 3600);
    const acceptSig = await signAccept(contract, "PK-2", courier, acceptDeadline);

    await contract
      .connect(backend)
      .acceptPickupWithSig("PK-2", await courier.getAddress(), acceptDeadline, acceptSig.v, acceptSig.r, acceptSig.s);

    await expect(
      contract
        .connect(backend)
        .acceptPickupWithSig("PK-2", await courier.getAddress(), acceptDeadline, acceptSig.v, acceptSig.r, acceptSig.s)
    ).to.be.revertedWith("Invalid courier signature");

    const completeDeadline = BigInt(Math.floor(Date.now() / 1000) + 3600);
    const completeSig = await signComplete(contract, "PK-2", courier, completeDeadline);

    await expect(
      contract
        .connect(backend)
        .completePickupWithSig("PK-2", await courier.getAddress(), completeDeadline, completeSig.v, completeSig.r, completeSig.s)
    )
      .to.emit(contract, "PickupCompleted")
      .withArgs(ethers.keccak256(ethers.toUtf8Bytes("PK-2")), "PK-2", await courier.getAddress(), anyValue);

    expect(await contract.courierActivePickups(await courier.getAddress())).to.equal(0n);
  });
});
