// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import { Test } from "forge-std/Test.sol";
import { stdJson } from "forge-std/StdJson.sol";
import "forge-std/console.sol";
import { console2 } from "forge-std/console2.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SelfPeggingAsset } from "../src/SelfPeggingAsset.sol";
import { WSPAToken } from "../src/WSPAToken.sol";
import { IZap } from "src/interfaces/IZap.sol";

contract TestTapioFunctionality is Script, Test {
    using stdJson for string;

    address spa;
    address spaToken;
    address wspa;
    address zap;

    address ws;
    address os;

    address alice;
    address bob;

    // Constants
    uint256 constant INITIAL_MINT_AMOUNT = 1000e18; // 1000 tokens
    uint256 constant SWAP_AMOUNT = 100e18; // 100 tokens to swap
    uint256 constant REDEEM_AMOUNT = 500e18; // 500 WSPA tokens to redeem

    function run() public {
        // addresses
        // string memory aJson = vm.readFile("broadcast/sonic-testnet.json");
        string memory aJson = vm.readFile("broadcast/sonic-mainnet.json");
        spa = aJson.readAddress(".wSwOSPool");
        wspa = aJson.readAddress(".wSwOSPoolWSPAToken");
        zap = aJson.readAddress(".Zap");
        ws = aJson.readAddress(".wS");
        os = aJson.readAddress(".wOS");
        console.log("=== Contracts Loaded ===");
        console.log("wS OS Pool: %s", address(spa));
        console.log("WSPA Token: %s", address(wspa));
        console.log("Zap Contract: %s", address(zap));

        // Set up fork
        // vm.createSelectFork("https://rpc.soniclabs.com");
        // vm.createSelectFork("https://rpc.blaze.soniclabs.com");
        // vm.createSelectFork("http://127.0.0.1:8545");
        console.log("=== Fork Setup ===");
        console2.log("Fork created at block: %s", block.number);
        console2.log("Timestamp: %s", block.timestamp);

        alice = makeAddr("Alice");
        bob = makeAddr("Bob");
        console.log("Accounts initialized:");
        console.log("- Alice: %s", alice);
        console.log("- Bob: %s", bob);

        deal(ws, alice, INITIAL_MINT_AMOUNT * 2);
        deal(os, alice, INITIAL_MINT_AMOUNT * 2);
        deal(ws, bob, INITIAL_MINT_AMOUNT);
        deal(os, bob, INITIAL_MINT_AMOUNT);
        console.log("=== Assets Prepared ===");
        uint256 aliceWsBalance = IERC20(ws).balanceOf(alice) / 1e18;
        uint256 aliceOSBalance = IERC20(os).balanceOf(alice) / 1e18;
        console2.log("Alice - wS: %s, OS: %s", aliceWsBalance, aliceOSBalance);
        console2.log("Bob - wS: %s, OS: %s", IERC20(ws).balanceOf(bob) / 1e18, IERC20(os).balanceOf(bob) / 1e18);

        // Alice mints WSPA tokens
        vm.startPrank(alice);
        uint256[] memory amountsInitial = new uint256[](2);
        amountsInitial[0] = 5e18;
        amountsInitial[1] = 5e18;
        uint256[] memory amountsAlice = new uint256[](2);
        amountsAlice[0] = INITIAL_MINT_AMOUNT;
        amountsAlice[1] = INITIAL_MINT_AMOUNT;
        IERC20(ws).approve(spa, 5e18);
        IERC20(os).approve(spa, 5e18);
        SelfPeggingAsset(spa).mint(amountsInitial, 0);
        IERC20(ws).approve(zap, INITIAL_MINT_AMOUNT);
        IERC20(os).approve(zap, INITIAL_MINT_AMOUNT);
        uint256 aliceWspaReceived = IZap(zap).zapIn(spa, wspa, alice, 0, amountsAlice);
        vm.stopPrank();
        console2.log("=== Alice's Actions ===");
        console2.log("Alice minted %s WSPA tokens", aliceWspaReceived / 1e18);

        vm.startPrank(bob);
        uint256[] memory amountsBob = new uint256[](2);
        amountsBob[0] = INITIAL_MINT_AMOUNT;
        amountsBob[1] = INITIAL_MINT_AMOUNT;
        IERC20(ws).approve(zap, INITIAL_MINT_AMOUNT);
        IERC20(os).approve(zap, INITIAL_MINT_AMOUNT);
        uint256 bobWspaReceived = IZap(zap).zapIn(spa, wspa, bob, 0, amountsBob);
        vm.stopPrank();
        console.log("=== Bob's Actions ===");
        console2.log("Bob minted %s WSPA tokens", bobWspaReceived / 1e18);

        vm.startPrank(alice);
        IERC20(ws).approve(spa, SWAP_AMOUNT);
        uint256 swappedAmount = SelfPeggingAsset(spa).swap(0, 1, SWAP_AMOUNT, 0); // wS (index 0) to OS (index 1)
        vm.stopPrank();
        console.log("=== Alice's Actions ===");
        console2.log("Alice swapped %s wS for %s OS", SWAP_AMOUNT / 1e18, swappedAmount / 1e18);

        vm.startPrank(bob);
        uint256[] memory minAmountsOut = new uint256[](2);
        minAmountsOut[0] = 0;
        minAmountsOut[1] = 0;
        WSPAToken(wspa).approve(zap, REDEEM_AMOUNT);
        uint256[] memory redeemedAmounts = IZap(zap).zapOut(spa, wspa, bob, REDEEM_AMOUNT, minAmountsOut, true);
        vm.stopPrank();
        console.log("=== Bob's Actions ===");
        console2.log(
            "Bob redeemed %s WSPA for %s wS and %s OS",
            REDEEM_AMOUNT / 1e18,
            redeemedAmounts[0] / 1e18,
            redeemedAmounts[1] / 1e18
        );

        console.log("=== Final Rates and Balances ===");
        console2.log(
            "Alice - wS: %s, OS: %s, WSPA: %s",
            IERC20(ws).balanceOf(alice) / 1e18,
            IERC20(os).balanceOf(alice) / 1e18,
            WSPAToken(wspa).balanceOf(alice) / 1e18
        );
        console2.log(
            "Bob - wS: %s, OS: %s, WSPA: %s",
            IERC20(ws).balanceOf(bob) / 1e18,
            IERC20(os).balanceOf(bob) / 1e18,
            WSPAToken(wspa).balanceOf(bob) / 1e18
        );
    }
}
