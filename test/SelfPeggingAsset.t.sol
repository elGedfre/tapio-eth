// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { console } from "forge-std/console.sol";

import { SelfPeggingAssetFactory } from "../src/SelfPeggingAssetFactory.sol";
import { MockToken } from "../src/mock/MockToken.sol";
import { SelfPeggingAsset } from "../src/SelfPeggingAsset.sol";
import { LPToken } from "../src/LPToken.sol";
import { WLPToken } from "../src/WLPToken.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "../src/misc/ConstantExchangeRateProvider.sol";
import "../src/mock/MockExchangeRateProvider.sol";

contract SelfPeggingAssetTest is Test {
    address owner = address(0x01);
    address user = address(0x02);
    address user2 = address(0x03);
    uint256 A = 100;
    LPToken lpToken;
    SelfPeggingAsset pool; // WETH and frxETH Pool
    uint256 feeDenominator = 10_000_000_000;
    uint256 mintFee = 10_000_000;
    uint256 swapFee = 20_000_000;
    uint256 redeemFee = 50_000_000;
    MockToken WETH;
    MockToken frxETH;
    uint256[] precisions;

    function setUp() public {
        WETH = new MockToken("WETH", "WETH", 18);
        frxETH = new MockToken("frxETH", "frxETH", 18);

        lpToken = new LPToken();
        lpToken.initialize("LP Token", "LPT");
        lpToken.transferOwnership(owner);

        ConstantExchangeRateProvider exchangeRateProvider = new ConstantExchangeRateProvider();

        pool = new SelfPeggingAsset();

        address[] memory tokens = new address[](2);
        tokens[0] = address(WETH);
        tokens[1] = address(frxETH);

        precisions = new uint256[](2);
        precisions[0] = 1;
        precisions[1] = 1;

        uint256[] memory fees = new uint256[](3);
        fees[0] = mintFee;
        fees[1] = swapFee;
        fees[2] = redeemFee;

        IExchangeRateProvider[] memory exchangeRateProviders = new IExchangeRateProvider[](2);
        exchangeRateProviders[0] = exchangeRateProvider;
        exchangeRateProviders[1] = exchangeRateProvider;

        pool.initialize(tokens, precisions, fees, lpToken, A, exchangeRateProviders);
        pool.transferOwnership(owner);

        vm.prank(owner);
        lpToken.addPool(address(pool));
    }

    function test_CorrectMintAmount_EqualTokenAmounts() external {
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100e18;
        amounts[1] = 100e18;

        WETH.mint(user, 100e18);
        frxETH.mint(user, 100e18);

        vm.startPrank(user);
        WETH.approve(address(pool), 100e18);
        frxETH.approve(address(pool), 100e18);
        vm.stopPrank();

        (uint256 lpTokensMinted, uint256 feesCharged) = pool.getMintAmount(amounts);

        uint256 totalAmount = lpTokensMinted + feesCharged;
        assertEq(totalAmount, 200e18);

        assertFee(totalAmount, feesCharged, mintFee);

        assertEq(100e18, WETH.balanceOf(user));
        assertEq(100e18, frxETH.balanceOf(user));
        assertEq(0, lpToken.balanceOf(user));
        assertEq(0, pool.balances(0));
        assertEq(0, pool.balances(1));
        assertEq(0, pool.totalSupply());

        vm.prank(user);
        pool.mint(amounts, 0);

        assertEq(0, WETH.balanceOf(user));
        assertEq(0, frxETH.balanceOf(user));
        assertEq(totalAmount, lpToken.balanceOf(user));
        assertEq(lpTokensMinted, lpToken.sharesOf(user));
        assertEq(totalAmount, lpToken.totalSupply());
    }

    function test_CorrectMintAmount_UnequalTokenAmounts() external view {
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 110e18;
        amounts[1] = 90e18;

        (uint256 lpTokensMinted, uint256 feesCharged) = pool.getMintAmount(amounts);

        assertFee(lpTokensMinted + feesCharged, feesCharged, mintFee);
    }

    function test_Pegging_UnderlyingToken() external {
        MockExchangeRateProvider rETHExchangeRateProvider = new MockExchangeRateProvider(1.1e18, 18);
        MockExchangeRateProvider wstETHExchangeRateProvider = new MockExchangeRateProvider(1.2e18, 18);

        MockToken rETH = new MockToken("rETH", "rETH", 18);
        MockToken wstETH = new MockToken("wstETH", "wstETH", 18);

        address[] memory _tokens = new address[](2);
        _tokens[0] = address(rETH);
        _tokens[1] = address(wstETH);

        IExchangeRateProvider[] memory exchangeRateProviders = new IExchangeRateProvider[](2);
        exchangeRateProviders[0] = IExchangeRateProvider(rETHExchangeRateProvider);
        exchangeRateProviders[1] = IExchangeRateProvider(wstETHExchangeRateProvider);

        SelfPeggingAsset _pool = new SelfPeggingAsset();

        LPToken _lpToken = new LPToken();
        _lpToken.initialize("LP Token", "LPT");
        _lpToken.transferOwnership(owner);

        uint256[] memory _fees = new uint256[](3);
        _fees[0] = 0;
        _fees[1] = 0;
        _fees[2] = 0;

        uint256[] memory _precisions = new uint256[](2);
        _precisions[0] = 1;
        _precisions[1] = 1;

        _pool.initialize(_tokens, _precisions, _fees, _lpToken, A, exchangeRateProviders);

        vm.prank(owner);
        _lpToken.addPool(address(_pool));

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 110e18;
        amounts[1] = 90e18;

        (uint256 lpTokensMinted,) = _pool.getMintAmount(amounts);

        assertIsCloseTo(lpTokensMinted, 229e18, 0.01e18);
    }

    function test_exchangeCorrectAmount() external {
        WETH.mint(user, 105e18);
        frxETH.mint(user, 85e18);

        vm.startPrank(user);
        WETH.approve(address(pool), 105e18);
        frxETH.approve(address(pool), 85e18);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 105e18;
        amounts[1] = 85e18;

        pool.mint(amounts, 0);
        vm.stopPrank();

        frxETH.mint(user2, 8e18);
        vm.startPrank(user2);
        frxETH.approve(address(pool), 8e18);
        vm.stopPrank();

        (uint256 exchangeAmount,) = pool.getSwapAmount(1, 0, 8e18);

        assertEq(WETH.balanceOf(user2), 0);
        assertEq(frxETH.balanceOf(user2), 8e18);

        assertEq(WETH.balanceOf(address(pool)), 105e18);
        assertEq(frxETH.balanceOf(address(pool)), 85e18);

        assertEq(pool.balances(0), 105e18);
        assertEq(pool.balances(1), 85e18);

        assertEq(pool.totalSupply(), 189.994704791049550806e18);

        assertEq(pool.totalSupply(), lpToken.totalSupply());

        vm.prank(user2);
        pool.swap(1, 0, 8e18, 0);

        assertEq(WETH.balanceOf(user2), exchangeAmount);
        assertEq(frxETH.balanceOf(user2), 0);

        assertEq(WETH.balanceOf(address(pool)), 105e18 - exchangeAmount);
        assertEq(frxETH.balanceOf(address(pool)), 85e18 + 8e18);
        assertEq(pool.totalSupply(), lpToken.totalSupply());
    }

    function test_redeemCorrectAmountWithProportionalRedemption() external {
        uint256[] memory mintAmounts = new uint256[](2);
        mintAmounts[0] = 105e18;
        mintAmounts[1] = 85e18;

        uint256 totalAmount = mintAmounts[0] + mintAmounts[1];

        WETH.mint(user, 105e18);
        frxETH.mint(user, 85e18);

        vm.startPrank(user);
        WETH.approve(address(pool), 105e18);
        frxETH.approve(address(pool), 85e18);

        pool.mint(mintAmounts, 0);
        vm.stopPrank();

        (uint256[] memory tokenAmounts,) = pool.getRedeemProportionAmount(25e18);
        uint256 token1Amount = tokenAmounts[0];
        uint256 token2Amount = tokenAmounts[1];

        uint256 totalShares = lpToken.totalShares();
        uint256 totalBalance = lpToken.totalSupply();

        vm.prank(user);
        lpToken.transfer(user2, 25e18);

        uint256 shares2 = lpToken.sharesOf(user2);
        uint256 balance2 = lpToken.balanceOf(user2);

        assertEq(WETH.balanceOf(user2), 0);
        assertEq(frxETH.balanceOf(user2), 0);

        assertEq(WETH.balanceOf(address(pool)), 105e18);
        assertEq(frxETH.balanceOf(address(pool)), 85e18);

        assertEq(pool.balances(0), 105e18);
        assertEq(pool.balances(1), 85e18);

        assertEq(pool.totalSupply(), 189.994704791049550806e18);
        assertEq(lpToken.totalSupply(), 189.994704791049550806e18);

        uint256 amountToRedeem = lpToken.balanceOf(user2);
        vm.startPrank(user2);
        lpToken.approve(address(pool), amountToRedeem);
        uint256[] memory _minRedeemAmounts = new uint256[](2);
        pool.redeemProportion(amountToRedeem, _minRedeemAmounts);
        vm.stopPrank();

        assertEq(WETH.balanceOf(user2), token1Amount);
        assertEq(frxETH.balanceOf(user2), token2Amount);

        assertEq(lpToken.sharesOf(user2), 1);
        assertEq(lpToken.balanceOf(user2), 1);

        assertEq(WETH.balanceOf(address(pool)), 105e18 - token1Amount);
        assertEq(frxETH.balanceOf(address(pool)), 85e18 - token2Amount);

        assertIsCloseTo(pool.balances(0), 105e18 - token1Amount * precisions[0], 0);
        assertIsCloseTo(pool.balances(1), 85e18 - token2Amount * precisions[1], 0);

        assertEq(pool.totalSupply(), lpToken.totalSupply());
    }

    function test_redeemCorrectAmountToSingleToken() external {
        uint256[] memory mintAmounts = new uint256[](2);
        mintAmounts[0] = 105e18;
        mintAmounts[1] = 85e18;

        uint256 totalAmount = mintAmounts[0] + mintAmounts[1];

        WETH.mint(user, 105e18);
        frxETH.mint(user, 85e18);

        vm.startPrank(user);
        WETH.approve(address(pool), 105e18);
        frxETH.approve(address(pool), 85e18);

        pool.mint(mintAmounts, 0);
        vm.stopPrank();

        (uint256 token1Amount, uint256 token2Amount) = pool.getRedeemSingleAmount(25e18, 0);

        vm.prank(user);
        lpToken.transfer(user2, 25e18);

        assertEq(WETH.balanceOf(user2), 0);
        assertEq(frxETH.balanceOf(user2), 0);

        assertEq(WETH.balanceOf(address(pool)), 105e18);
        assertEq(frxETH.balanceOf(address(pool)), 85e18);

        assertEq(pool.balances(0), 105e18);
        assertEq(pool.balances(1), 85e18);

        assertEq(pool.totalSupply(), lpToken.totalSupply());

        uint256 redeemAmount = lpToken.balanceOf(user2);
        vm.startPrank(user2);
        lpToken.approve(address(pool), redeemAmount);
        pool.redeemSingle(redeemAmount, 0, 0);
        vm.stopPrank();

        assertEq(WETH.balanceOf(user2), token1Amount);
        assertEq(frxETH.balanceOf(user2), 0);
        assertEq(lpToken.sharesOf(user2), 1);

        assertEq(WETH.balanceOf(address(pool)), 105e18 - token1Amount);
        assertEq(frxETH.balanceOf(address(pool)), 85e18);
        assertIsCloseTo(pool.balances(0), 105e18 - token1Amount * precisions[0], 0);
        assertEq(pool.balances(1), 85e18);
        assertEq(pool.totalSupply(), lpToken.totalSupply());
    }

    function test_redeemCorrectAmountToMultipleTokens() external {
        uint256[] memory mintAmounts = new uint256[](2);
        mintAmounts[0] = 105e18;
        mintAmounts[1] = 85e18;

        WETH.mint(user, 105e18);
        frxETH.mint(user, 85e18);

        vm.startPrank(user);
        WETH.approve(address(pool), 105e18);
        frxETH.approve(address(pool), 85e18);

        pool.mint(mintAmounts, 0);
        vm.stopPrank();

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 10e18;
        amounts[1] = 5e18;
        (uint256 redeemAmount,) = pool.getRedeemMultiAmount(amounts);

        vm.prank(user);
        lpToken.transfer(user2, 25e18);

        uint256 balance = lpToken.balanceOf(user2);

        assertEq(WETH.balanceOf(user2), 0);
        assertEq(frxETH.balanceOf(user2), 0);
        assertEq(lpToken.balanceOf(user2), balance);

        assertEq(WETH.balanceOf(address(pool)), 105e18);
        assertEq(frxETH.balanceOf(address(pool)), 85e18);

        assertEq(pool.balances(0), 105e18);
        assertEq(pool.balances(1), 85e18);

        assertEq(pool.totalSupply(), lpToken.totalSupply());

        vm.startPrank(user2);
        lpToken.approve(address(pool), redeemAmount);
        uint256[] memory redeemAmounts = new uint256[](2);
        redeemAmounts[0] = 10e18;
        redeemAmounts[1] = 5e18;
        pool.redeemMulti(redeemAmounts, redeemAmount);
        vm.stopPrank();

        assertEq(WETH.balanceOf(user2), 10e18);
        assertEq(frxETH.balanceOf(user2), 5e18);

        assertEq(WETH.balanceOf(address(pool)), 105e18 - 10e18);
        assertEq(frxETH.balanceOf(address(pool)), 85e18 - 5e18);

        assertEq(pool.balances(0), 105e18 - 10e18);
        assertEq(pool.balances(1), 85e18 - 5e18);
        assertEq(pool.totalSupply(), lpToken.totalSupply());
    }

    function test_redeemCorrectAmountToSingleTokenRebasing() external {
        uint256[] memory mintAmounts = new uint256[](2);
        mintAmounts[0] = 105e18;
        mintAmounts[1] = 85e18;

        uint256 totalAmount = mintAmounts[0] + mintAmounts[1];

        WETH.mint(user, 105e18);
        frxETH.mint(user, 85e18);

        vm.startPrank(user);
        WETH.approve(address(pool), 105e18);
        frxETH.approve(address(pool), 85e18);

        pool.mint(mintAmounts, 0);
        vm.stopPrank();

        WETH.mint(address(pool), 10e18);
        uint256 redeemAmount = 25e18;
        (uint256 token1Amount, uint256 feeAmount) = pool.getRedeemSingleAmount(redeemAmount, 0);

        assertInvariant(105e18 - (token1Amount * precisions[0]), 85e18, 100, totalAmount - redeemAmount - feeAmount);
    }

    function test_redeemCorrectAmountWithProportionalRedemptionRebasing() external {
        uint256[] memory mintAmounts = new uint256[](2);
        mintAmounts[0] = 105e18;
        mintAmounts[1] = 85e18;

        WETH.mint(user, 105e18);
        frxETH.mint(user, 85e18);

        vm.startPrank(user);
        WETH.approve(address(pool), 105e18);
        frxETH.approve(address(pool), 85e18);

        pool.mint(mintAmounts, 0);
        vm.stopPrank();

        WETH.mint(address(pool), 10e18);
        uint256 redeemAmount = 25e18;
        (uint256[] memory tokenAmounts, uint256 feeAmount) = pool.getRedeemProportionAmount(redeemAmount);

        uint256 token1Amount = tokenAmounts[0];
        uint256 token2Amount = tokenAmounts[1];

        assertEq(token1Amount, 14_303_943_881_560_144_839);
        assertEq(token2Amount, 10_572_480_260_283_585_316);
        assertEq(feeAmount, 125_000_000_000_000_000);
    }

    function test_correctExchangeAmountRebasing() external {
        WETH.mint(user, 105e18);
        frxETH.mint(user, 85e18);

        vm.startPrank(user);
        WETH.approve(address(pool), 105e18);
        frxETH.approve(address(pool), 85e18);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 105e18;
        amounts[1] = 85e18;

        pool.mint(amounts, 0);
        vm.stopPrank();

        WETH.mint(address(pool), 10e18);
        frxETH.mint(user2, 8e18);
        vm.startPrank(user2);
        frxETH.approve(address(pool), 8e18);
        vm.stopPrank();

        (uint256 exchangeAmount, uint256 feeAmount) = pool.getSwapAmount(1, 0, 8e18);

        assertEq(exchangeAmount, 7.992985053666343961e18);
        assertEq(feeAmount, 0.016018006119571831e18);
    }

    function test_updateA() external {
        WETH.mint(user, 105e18);
        frxETH.mint(user, 85e18);

        vm.startPrank(user);
        WETH.approve(address(pool), 105e18);
        frxETH.approve(address(pool), 85e18);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 105e18;
        amounts[1] = 85e18;

        pool.mint(amounts, 0);
        vm.stopPrank();

        frxETH.mint(user2, 8e18);

        assertEq(pool.A(), 100);

        uint256 bufferBefore = lpToken.bufferAmount();

        // increase A
        vm.prank(owner);
        pool.updateA(200);

        assertEq(pool.A(), 200);
        assert(lpToken.bufferAmount() > bufferBefore);

        // decrease A
        vm.prank(owner);
        WETH.mint(user, 205e18);
        frxETH.mint(user, 195e18);

        vm.startPrank(user);
        WETH.approve(address(pool), 205e18);
        frxETH.approve(address(pool), 195e18);

        amounts[0] = 205e18;
        amounts[1] = 195e18;

        pool.donateD(amounts, 0);
        vm.stopPrank();

        vm.prank(owner);
        pool.updateA(90);

        assertEq(pool.A(), 90);
    }

    function assertFee(uint256 totalAmount, uint256 feeAmount, uint256 fee) internal view {
        uint256 expectedFee = totalAmount * fee / feeDenominator;
        assertEq(feeAmount, expectedFee);
    }

    function assertAlmostTheSame(uint256 num1, uint256 num2) internal view {
        // Calculate the absolute difference
        uint256 diff = num1 > num2 ? num1 - num2 : num2 - num1;

        // Use the smaller number as the denominator
        uint256 denominator = num1 < num2 ? num1 : num2;
        require(denominator > 0, "Denominator must be greater than 0");

        // Calculate the relative difference scaled by 10000 (0.01% precision)
        uint256 scaledDiff = (diff * 10_000) / denominator;

        // Assert that the relative difference is smaller than 0.15% (scaled value <= 15)
        require(scaledDiff <= 15, "Values are not almost the same");
    }

    function assertInvariant(uint256 balance0, uint256 balance1, uint256 A, uint256 D) internal {
        // We only check n = 2 here
        uint256 left = (A * 4) * (balance0 + balance1) + D;
        uint256 denominator = balance0 * balance1 * 4;
        require(denominator > 0, "Denominator must be greater than 0");
        uint256 right = (A * 4) * D + (D ** 3) / denominator;

        assertAlmostTheSame(left, right);
    }

    function assertIsCloseTo(uint256 a, uint256 b, uint256 tolerance) public pure returns (bool) {
        if (a > b) {
            require(a - b <= tolerance == true, "Not close enough");
        } else {
            require(b - a <= tolerance == true == true, "Not close enough");
        }
    }
}
