// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { stdJson } from "forge-std/StdJson.sol";
import { console } from "forge-std/console.sol";

import { Deploy } from "script/Deploy.sol";
import { Pool } from "script/Pool.sol";
import { MockToken } from "../src/mock/MockToken.sol";
import { SelfPeggingAsset } from "../src/SelfPeggingAsset.sol";
import { MockExchangeRateProvider } from "../src/mock/MockExchangeRateProvider.sol";

contract Testnet is Deploy, Pool {
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
        uint256 chainId = getChainId();
        string memory networkName = getNetworkName(chainId);
        string memory path = string.concat("./broadcast/", networkName, ".json");

        deployBeacons();
        deployFactory(networkName);
        deployZap();

        if (chainId == 57_054) {
            MockExchangeRateProvider wSToS = new MockExchangeRateProvider(1e18, 18);
            MockExchangeRateProvider stSToS = new MockExchangeRateProvider(1.01558e18, 18);
            MockExchangeRateProvider OSToS = new MockExchangeRateProvider(1.004739e18, 18);

            MockToken wS = new MockToken("wS", "wS", 18);
            MockToken stS = new MockToken("stS", "stS", 18);
            MockToken OS = new MockToken("OS", "OS", 18);

            uint256 amount = 100e18;

            MockToken(wS).mint(DEPLOYER, amount * 2);
            MockToken(stS).mint(DEPLOYER, amount);
            MockToken(OS).mint(DEPLOYER, amount);

            (address spaToken, address pool, address wspaToken,,) =
                createMockExchangeRatePool(address(wS), address(stS), address(wSToS), address(stSToS));

            initialMint(address(wS), address(stS), amount, amount, SelfPeggingAsset(pool));

            (address spaToken2, address pool2, address wspaToken2,,) =
                createMockExchangeRatePool(address(wS), address(OS), address(wSToS), address(OSToS));
            initialMint(address(wS), address(OS), amount, amount, SelfPeggingAsset(pool2));

            vm.writeJson(vm.serializeAddress("contracts", "Zap", zap), path);
            vm.writeJson(vm.serializeAddress("contracts", "Factory", address(factory)), path);
            vm.writeJson(vm.serializeAddress("contracts", "SelfPeggingAssetBeacon", selfPeggingAssetBeacon), path);
            vm.writeJson(vm.serializeAddress("contracts", "SPATokenBeacon", spaTokenBeacon), path);
            vm.writeJson(vm.serializeAddress("contracts", "WSPATokenBeacon", wspaTokenBeacon), path);
            vm.writeJson(vm.serializeAddress("contracts", "wS", address(wS)), path);
            vm.writeJson(vm.serializeAddress("contracts", "stS", address(stS)), path);
            vm.writeJson(vm.serializeAddress("contracts", "OS", address(OS)), path);
            vm.writeJson(vm.serializeAddress("contracts", "wSstSPool", address(pool)), path);
            vm.writeJson(vm.serializeAddress("contracts", "wSstSPoolSPAToken", spaToken), path);
            vm.writeJson(vm.serializeAddress("contracts", "wSstSPoolWSPAToken", wspaToken), path);
            vm.writeJson(vm.serializeAddress("contracts", "wSOSPool", address(pool2)), path);
            vm.writeJson(vm.serializeAddress("contracts", "wSOSPoolSPAToken", spaToken2), path);
            vm.writeJson(vm.serializeAddress("contracts", "wSOSPoolWSPAToken", wspaToken2), path);
        }

        vm.stopBroadcast();
    }
}
