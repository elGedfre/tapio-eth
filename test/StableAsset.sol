pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { console } from "forge-std/console.sol";

import { StableAssetFactory } from "../src/StableAssetFactory.sol";
import { MockToken } from "../src/mock/MockToken.sol";
import { StableAsset } from "../src/StableAsset.sol";
import { LPToken } from "../src/LPToken.sol";
import { WLPToken } from "../src/WLPToken.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "../src/misc/ConstantExchangeRateProvider.sol";

contract StableAssetTest is Test {
  address governance = address(0x01);
  uint256 A = 100;
  LPToken lpToken;
  StableAsset stableAsset;
  uint256 feeDenominator = 10000000000;
  uint256 mintFee = 10000000;
  uint256 swapFee = 20000000;
  uint256 redeemFee = 50000000;

  function setUp() public {
    MockToken tokenA = new MockToken("test 1", "T1", 18);
    MockToken tokenB = new MockToken("test 2", "T2", 18);

    lpToken = new LPToken();
    lpToken.initialize(
      governance,
      "LP Token",
      "LPT"
    );

    ConstantExchangeRateProvider exchangeRateProvider = new ConstantExchangeRateProvider();

    stableAsset = new StableAsset();

    address[] memory tokens = new address[](2);
    tokens[0] = address(tokenA);
    tokens[1] = address(tokenB);

    uint256[] memory precisions = new uint256[](2);
    precisions[0] = 1;
    precisions[1] = 1;

    uint256[] memory fees = new uint256[](3);
    fees[0] = mintFee;
    fees[1] = swapFee;
    fees[2] = redeemFee;

    IExchangeRateProvider[] memory exchangeRateProviders = new IExchangeRateProvider[](2);
    exchangeRateProviders[0] = exchangeRateProvider;
    exchangeRateProviders[1] = exchangeRateProvider;

    stableAsset.initialize(
      tokens,
      precisions,
      fees,
      lpToken,
      A,
      exchangeRateProviders
    );

    vm.prank(governance);
    lpToken.addPool(address(stableAsset));
  }

  function test_CorrectMintAmount_UnequalTokenAmounts() external {
    uint256[] memory amounts = new uint256[](2);
    amounts[0] = 110e18;
    amounts[1] = 90e18;

    (uint256 lpTokensMinted, uint256 feesCharged) = stableAsset.getMintAmount(
      amounts
    );

    console.log(lpTokensMinted);

    assertFee(lpTokensMinted+feesCharged, feesCharged, mintFee);
  }

  function assertFee(uint256 totalAmount, uint256 feeAmount, uint256 fee) internal {
    uint256 expectedFee = totalAmount * fee / feeDenominator;
    assertEq(feeAmount, expectedFee);
  }
}