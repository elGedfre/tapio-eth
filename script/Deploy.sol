// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { console } from "forge-std/console.sol";
import { StableAsset } from "../src/StableAsset.sol";
import { LPToken } from "../src/LPToken.sol";
import { WLPToken } from "../src/WLPToken.sol";
import { StableAssetFactory } from "../src/StableAssetFactory.sol";
import { Timelock } from "../src/governance/Timelock.sol";
import { Config } from "script/Config.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/misc/ConstantExchangeRateProvider.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

contract Deploy is Config {
    function deployBeaconsAndFactoryTimelock() internal {
        console.log("---------------");
        console.log("deploy-beacon-and-factory-timelock-logs");
        console.log("---------------");

        address stableAssetImplentation = address(new StableAsset());
        address lpTokenImplentation = address(new LPToken());
        address wlpTokenImplentation = address(new WLPToken());
        address timelockImplentation = address(new Timelock());

        UpgradeableBeacon beacon = new UpgradeableBeacon(stableAssetImplentation);
        stableAssetBeacon = address(beacon);

        beacon = new UpgradeableBeacon(lpTokenImplentation);
        lpTokenBeacon = address(beacon);

        beacon = new UpgradeableBeacon(wlpTokenImplentation);
        wlpTokenBeacon = address(beacon);

        beacon = new UpgradeableBeacon(timelockImplentation);
        timelockBeacon = address(beacon);

        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        proposers[0] = GOVERNOR;
        executors[0] = GOVERNOR;
        bytes memory timelockInit = abi.encodeCall(Timelock.initialize, (GOVERNOR, 0, proposers, executors));

        factoryTimelock = address(new BeaconProxy(timelockBeacon, timelockInit));

        UpgradeableBeacon(stableAssetBeacon).transferOwnership(factoryTimelock);
        UpgradeableBeacon(lpTokenBeacon).transferOwnership(factoryTimelock);
        UpgradeableBeacon(wlpTokenBeacon).transferOwnership(factoryTimelock);
        UpgradeableBeacon(timelockBeacon).transferOwnership(factoryTimelock);
    }

    function deployFactory() internal {
        console.log("---------------");
        console.log("deploy-factory-logs");
        console.log("---------------");

        bytes memory data = abi.encodeCall(
            StableAssetFactory.initialize,
            (
                GOVERNOR,
                0,
                0,
                0,
                100,
                stableAssetBeacon,
                lpTokenBeacon,
                wlpTokenBeacon,
                timelockBeacon,
                0,
                new ConstantExchangeRateProvider()
            )
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(new StableAssetFactory()), data);

        factory = StableAssetFactory(address(proxy));
        factory.transferOwnership(factoryTimelock);
    }
}
