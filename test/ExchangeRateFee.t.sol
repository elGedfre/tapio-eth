// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test, console2 } from "forge-std/Test.sol";
import { SelfPeggingAsset, IExchangeRateProvider } from "../src/SelfPeggingAsset.sol";
import { MockToken } from "../src/mock/MockToken.sol";
import { LPToken } from "../src/LPToken.sol";
import { ConstantExchangeRateProvider } from "../src/misc/ConstantExchangeRateProvider.sol";
import { MockExchangeRateProvider } from "../src/mock/MockExchangeRateProvider.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ExchangeRateFeeTest is Test {
    address owner = address(0x01);
    address user = address(0x02);
    address attacker = address(0x03);

    LPToken lpToken;
    SelfPeggingAsset pool;

    MockToken WETH;
    MockToken frxETH;
    MockExchangeRateProvider mockFrxETHRateProvider;

    uint256 mintFee = 10_000_000;
    uint256 swapFee = 20_000_000;
    uint256 redeemFee = 50_000_000;

    function setUp() public {
        WETH = new MockToken("WETH", "WETH", 18);
        frxETH = new MockToken("frxETH", "frxETH", 18);

        ERC1967Proxy lpTokenProxy =
            new ERC1967Proxy(address(new LPToken()), abi.encodeCall(LPToken.initialize, ("LP Token", "LPT")));

        lpToken = LPToken(address(lpTokenProxy));
        lpToken.transferOwnership(owner);

        address[] memory tokens = new address[](2);
        tokens[0] = address(WETH);
        tokens[1] = address(frxETH);

        uint256[] memory precisions = new uint256[](2);
        precisions[0] = 1;
        precisions[1] = 1;

        uint256[] memory fees = new uint256[](3);
        fees[0] = mintFee;
        fees[1] = swapFee;
        fees[2] = redeemFee;

        ConstantExchangeRateProvider constantProvider = new ConstantExchangeRateProvider();
        mockFrxETHRateProvider = new MockExchangeRateProvider(1e18, 18);

        IExchangeRateProvider[] memory exchangeRateProviders = new IExchangeRateProvider[](2);
        exchangeRateProviders[0] = constantProvider;
        exchangeRateProviders[1] = mockFrxETHRateProvider;

        ERC1967Proxy poolProxy = new ERC1967Proxy(
            address(new SelfPeggingAsset()),
            abi.encodeCall(
                SelfPeggingAsset.initialize,
                (tokens, precisions, fees, 0, lpToken, 17_000, exchangeRateProviders, address(0), 1 * 10 ** 10)
            )
        );

        pool = SelfPeggingAsset(address(poolProxy));
        pool.updateFeeErrorMargin(type(uint256).max);
        pool.updateYieldErrorMargin(type(uint256).max);
        pool.transferOwnership(owner);

        vm.prank(owner);
        lpToken.addPool(address(pool));
    }

    function test_Arbitrage() external {
        uint256 depositAmount = 1_000_000e18;

        // User initial deposit
        WETH.mint(user, depositAmount);
        frxETH.mint(user, depositAmount);

        vm.startPrank(user);
        WETH.approve(address(pool), depositAmount);
        frxETH.approve(address(pool), depositAmount);

        uint256[] memory depositAmounts = new uint256[](2);
        depositAmounts[0] = depositAmount;
        depositAmounts[1] = depositAmount;
        pool.mint(depositAmounts, 0);
        vm.stopPrank();

        assertEq(WETH.balanceOf(address(pool)), depositAmount);
        assertEq(frxETH.balanceOf(address(pool)), depositAmount);

        console2.log("Initial Pool Balances:");
        console2.log("WETH:", WETH.balanceOf(address(pool)));
        console2.log("frxETH:", frxETH.balanceOf(address(pool)));

        // Attacker swaps frxETH -> WETH at rate = 1
        uint256 tradeAmount = 500_000e18;
        WETH.mint(attacker, 1);
        frxETH.mint(attacker, tradeAmount);

        assertEq(WETH.balanceOf(attacker), 1);
        assertEq(frxETH.balanceOf(attacker), tradeAmount);

        vm.startPrank(attacker);
        WETH.approve(address(pool), type(uint256).max);
        frxETH.approve(address(pool), type(uint256).max);

        pool.swap(1, 0, tradeAmount, 0);
        vm.stopPrank();

        assertLt(WETH.balanceOf(attacker), tradeAmount);
        assertEq(frxETH.balanceOf(attacker), 0);

        // Oracle rate update: frxETH = 0.994
        vm.prank(owner);
        mockFrxETHRateProvider.newRate(994e15);

        // minimal swap
        vm.startPrank(attacker);
        pool.swap(0, 1, 1, 0);
        vm.stopPrank();

        uint256 newTime = block.timestamp + 1 minutes;
        vm.warp(newTime);

        // Attacker swaps back WETH -> frxETH at new rate
        // main swap
        vm.startPrank(attacker);
        pool.swap(0, 1, WETH.balanceOf(attacker), 0);
        vm.stopPrank();

        assertLt(frxETH.balanceOf(attacker), tradeAmount);
    }
}
