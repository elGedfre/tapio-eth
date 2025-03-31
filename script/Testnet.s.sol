// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { stdJson } from "forge-std/StdJson.sol";
import { console } from "forge-std/console.sol";

import { Deploy } from "script/Deploy.sol";
import { Mocks } from "script/Mocks.sol";
import { Pool } from "script/Pool.sol";
import { MockToken } from "../src/mock/MockToken.sol";
import { SelfPeggingAsset } from "../src/SelfPeggingAsset.sol";

contract Testnet is Deploy, Mocks, Pool {
    function init() internal {
        if (vm.envUint("HEX_PRIV_KEY") == 0) revert("No private key found");
        deployerPrivateKey = vm.envUint("HEX_PRIV_KEY");
        GOVERNOR = vm.addr(deployerPrivateKey);
        DEPLOYER = vm.addr(deployerPrivateKey);
    }

    function run() public payable {
        init();
        loadConfig();

        vm.startBroadcast(deployerPrivateKey);

        deployAssets();
        deployBeacons();
        deployFactory();
        deployZap();

        (, address selfPeggingAsset,) = createStandardPool(
            usdc,
            usdt
        );

        uint256 amount = 10_000e6;

        MockToken(usdc).mint(DEPLOYER, amount);
        MockToken(usdt).mint(DEPLOYER, amount);

        initialMint(
            usdc,
            usdt,
            amount, 
            amount, 
            SelfPeggingAsset(selfPeggingAsset)
        );

        string memory networkName = getNetworkName(getChainId());
        string memory path = string.concat("./broadcast/", networkName, ".json");

        vm.writeJson(vm.serializeAddress("contracts", "Factory", address(factory)), path);

        vm.writeJson(vm.serializeAddress("contracts", "SelfPeggingAssetBeacon", selfPeggingAssetBeacon), path);

        vm.writeJson(vm.serializeAddress("contracts", "LPTokenBeacon", lpTokenBeacon), path);

        vm.writeJson(vm.serializeAddress("contracts", "WLPTokenBeacon", wlpTokenBeacon), path);

        vm.writeJson(vm.serializeAddress("contracts", "Zap", zap), path);

        vm.stopBroadcast();
    }
}
