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
import "../src/mock/MockExchangeRateProvider.sol";

contract StableAssetTest is Test {
    address owner = address(0x01);
    uint256 A = 100;
    LPToken lpToken1;
    StableAsset ethPool1;
    uint256 feeDenominator = 10_000_000_000;
    uint256 mintFee = 10_000_000;
    uint256 swapFee = 20_000_000;
    uint256 redeemFee = 50_000_000;
    MockToken WETH;
    MockToken stETH;
    MockToken rETH;
    MockToken wstETH;
    StableAsset ethPool2;
    LPToken lpToken2;

    function setUp() public {
        WETH = new MockToken("WETH", "WETH", 18);
        stETH = new MockToken("stETH", "stETH", 18);

        lpToken1 = new LPToken();
        lpToken1.initialize("LP Token", "LPT");
        lpToken1.transferOwnership(owner);

        ConstantExchangeRateProvider exchangeRateProvider = new ConstantExchangeRateProvider();

        ethPool1 = new StableAsset();

        address[] memory tokens = new address[](2);
        tokens[0] = address(WETH);
        tokens[1] = address(stETH);

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

        ethPool1.initialize(tokens, precisions, fees, lpToken1, A, exchangeRateProviders);

        vm.prank(owner);
        lpToken1.addPool(address(ethPool1));

        MockExchangeRateProvider rETHExchangeRateProvider = new MockExchangeRateProvider(1.1e18, 18);
        MockExchangeRateProvider wstETHExchangeRateProvider = new MockExchangeRateProvider(1.2e18, 18);

        rETH = new MockToken("rETH", "rETH", 18);
        wstETH = new MockToken("wstETH", "wstETH", 18);

        tokens = new address[](2);
        tokens[0] = address(rETH);
        tokens[1] = address(wstETH);

        exchangeRateProviders = new IExchangeRateProvider[](2);
        exchangeRateProviders[0] = IExchangeRateProvider(rETHExchangeRateProvider);
        exchangeRateProviders[1] = IExchangeRateProvider(wstETHExchangeRateProvider);

        ethPool2 = new StableAsset();

        lpToken2 = new LPToken();
        lpToken2.initialize("LP Token", "LPT");
        lpToken2.transferOwnership(owner);

        ethPool2.initialize(tokens, precisions, fees, lpToken2, A, exchangeRateProviders);

        vm.prank(owner);
        lpToken2.addPool(address(ethPool2));
    }

    function test_CorrectMintAmount_UnequalTokenAmounts() external {
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 110e18;
        amounts[1] = 90e18;

        (uint256 lpTokensMinted, uint256 feesCharged) = ethPool1.getMintAmount(amounts);

        assertFee(lpTokensMinted + feesCharged, feesCharged, mintFee);

        (lpTokensMinted, feesCharged) = ethPool2.getMintAmount(amounts);

        assertFee(lpTokensMinted + feesCharged, feesCharged, mintFee);
    }

    function assertFee(uint256 totalAmount, uint256 feeAmount, uint256 fee) internal {
        uint256 expectedFee = totalAmount * fee / feeDenominator;
        assertEq(feeAmount, expectedFee);
    }
}
