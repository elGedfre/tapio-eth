// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import { StableAssetFactory } from "../src/StableAssetFactory.sol";

contract Config is Script {
    bool testnet = vm.envBool("TESTNET");

    uint256 deployerPrivateKey;
    uint256 initialMinterPrivateKey;
    
    address GOVERNANCE;
    address DEPLOYER;
    address INITIAL_MINTER;

    address usdc;
    address usdt;

    StableAssetFactory factory;
    address stableAssetBeacon;
    address lpTokenBeacon;
    address wlpTokenBeacon;

    struct JSONData {
        address USDC;
        address USDT;
        address Factory;
        address StableAssetBeacon;
        address LPTokenBeacon;
        address WLPTokenBeacon;
    }

    function loadConfig() internal {
        if (!testnet) {
            usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
            usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        }
    }
}