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
        deployBeacons();
        deployFactory();
        deployZap();

        uint256 amount = 26e18;

        MockToken weth = new MockToken("WETH", "WETH", 18);
        MockToken wstETH = new MockToken("wstETH", "wstETH", 18);
        MockToken weETH = new MockToken("weETH", "weETH", 18);

        MockToken(weth).mint(DEPLOYER, amount);
        MockToken(wstETH).mint(DEPLOYER, amount * 2);
        MockToken(weETH).mint(DEPLOYER, amount);

        MockExchangeRateProvider WETHTostETHOracle = new MockExchangeRateProvider(1e18, 18);
        MockExchangeRateProvider wstETHTostETHOracle = new MockExchangeRateProvider(1.1e18, 18);
        MockExchangeRateProvider weETHTostETHOracle = new MockExchangeRateProvider(1.2e18, 18);

        (address lpToken, address pool, address wlpToken,) = createMockExchangeRatePool(
            address(weth), address(wstETH), address(WETHTostETHOracle), address(wstETHTostETHOracle)
        );

        initialMint(address(weth), address(wstETH), amount, amount, SelfPeggingAsset(pool));

        (address lpToken2, address pool2, address wlpToken2,) = createMockExchangeRatePool(
            address(wstETH), address(weETH), address(wstETHTostETHOracle), address(weETHTostETHOracle)
        );
        initialMint(address(wstETH), address(weETH), amount, amount, SelfPeggingAsset(pool2));

        string memory networkName = getNetworkName(getChainId());
        string memory path = string.concat("./broadcast/", networkName, ".json");

        vm.writeJson(vm.serializeAddress("contracts", "Zap", zap), path);
        vm.writeJson(vm.serializeAddress("contracts", "Factory", address(factory)), path);
        vm.writeJson(vm.serializeAddress("contracts", "SelfPeggingAssetBeacon", selfPeggingAssetBeacon), path);
        vm.writeJson(vm.serializeAddress("contracts", "LPTokenBeacon", lpTokenBeacon), path);
        vm.writeJson(vm.serializeAddress("contracts", "WLPTokenBeacon", wlpTokenBeacon), path);
        vm.writeJson(vm.serializeAddress("contracts", "wstETH", address(wstETH)), path);
        vm.writeJson(vm.serializeAddress("contracts", "weETH", address(weETH)), path);
        vm.writeJson(vm.serializeAddress("contracts", "WETH", address(weth)), path);
        vm.writeJson(vm.serializeAddress("contracts", "WETHwstETHPool", pool), path);
        vm.writeJson(vm.serializeAddress("contracts", "wstETHweETHPool", pool2), path);
        vm.writeJson(vm.serializeAddress("contracts", "WETHwstETHPoolLPToken", lpToken), path);
        vm.writeJson(vm.serializeAddress("contracts", "wstETHweETHPoolLPToken", lpToken2), path);
        vm.writeJson(vm.serializeAddress("contracts", "WETHwstETHPoolWLPToken", wlpToken), path);
        vm.writeJson(vm.serializeAddress("contracts", "wstETHweETHPoolWLPToken", wlpToken2), path);

        vm.stopBroadcast();
    }
}
