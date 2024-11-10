import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers, upgrades, web3 } from "hardhat";

describe("StableAssetFactory", function () {
  it("create pool", async () => {
    const StableAssetFactory = await ethers.getContractFactory("StableAssetFactory");
    const StableAsset = await ethers.getContractFactory("StableAsset");
    const TapETH = await ethers.getContractFactory("TapETH");
    const stableAssetImpl = await StableAsset.deploy();
    const tapETHImpl = await TapETH.deploy();

    /// Deploy swap and tokens
    const factory = await upgrades.deployProxy(StableAssetFactory, [stableAssetImpl.address, tapETHImpl.address]);
    const MockToken = await ethers.getContractFactory("MockToken");
    /// Deploy token1 with name "test 1", symbol "T1", decimals 18
    const token1 = await MockToken.deploy("test 1", "T1", 18);
    /// Deploy token2 with name "test 2", symbol "T2", decimals 18
    const token2 = await MockToken.deploy("test 2", "T2", 18);
    const [owner, feeRecipient, user] = await ethers.getSigners();

    const args = {
      tokenA: token1.address,
      tokenB: token2.address,
      precisionA: 1,
      precisionB: 1,
      mintFee: 0,
      swapFee: 0,
      redeemFee: 0,
      A: 100,
    }

    const tx = await factory.createPool(args);
    const receipt = await tx.wait();
    const event = receipt.events?.filter((x) => {
      return x.event == "PoolCreated"
    });
    const poolToken = event[0].args.poolToken;
    const stableAsset = event[0].args.stableAsset;

    const poolTokenDeployed = TapETH.attach(poolToken);
    const stableAssetDeployed = StableAsset.attach(stableAsset);
    await poolTokenDeployed.acceptGovernance();
    await stableAssetDeployed.acceptGovernance();

    await stableAssetDeployed.unpause();
    /// Mint 100 token1 to user
    await token1.mint(user.address, web3.utils.toWei("100"));
    /// Mint 100 token2 to user
    await token2.mint(user.address, web3.utils.toWei("100"));
    /// Approve swap contract to spend 100 token1
    await token1.connect(user).approve(stableAssetDeployed.address, web3.utils.toWei("100"));
    /// Approve swap contract to spend 100 token2
    await token2.connect(user).approve(stableAssetDeployed.address, web3.utils.toWei("100"));

    await stableAssetDeployed.connect(user).mint([web3.utils.toWei("100"),
      web3.utils.toWei("100"),], 0);

    console.log(await poolTokenDeployed.decimals());
    console.log(await poolTokenDeployed.name());
    console.log(await poolTokenDeployed.totalSupply());
    console.log(await stableAssetDeployed.totalSupply());
  });
});
