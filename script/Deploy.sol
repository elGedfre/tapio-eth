// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { console } from "forge-std/console.sol";
import { StableAsset } from "../src/StableAsset.sol";
import { LPToken } from "../src/LPToken.sol";
import { WLPToken } from "../src/WLPToken.sol";
import { StableAssetFactory } from "../src/StableAssetFactory.sol";
import { Config } from "script/Config.sol";
import "../src/misc/ConstantExchangeRateProvider.sol";

contract Deploy is Config {
    function deployBeacons() internal {
        console.log("---------------");
        console.log("deploy-beacon-logs");
        console.log("---------------");

        address stableAssetImplentation = address(new StableAsset());
        address lpTokenImplentation = address(new LPToken());
        address wlpTokenImplentation = address(new WLPToken());

        UpgradeableBeacon beacon = new UpgradeableBeacon(stableAssetImplentation);
        beacon.transferOwnership(GOVERNANCE);
        stableAssetBeacon = address(beacon);

        beacon = new UpgradeableBeacon(lpTokenImplentation);
        beacon.transferOwnership(GOVERNANCE);
        lpTokenBeacon = address(beacon);

        beacon = new UpgradeableBeacon(wlpTokenImplentation);
        beacon.transferOwnership(GOVERNANCE);
        wlpTokenBeacon = address(beacon);
    }

    function deployFactory() internal {
        console.log("---------------");
        console.log("deploy-factory-logs");
        console.log("---------------");

        factory = new StableAssetFactory();

        factory.initialize(
            GOVERNANCE,
            0,
            0,
            0,
            100,
            stableAssetBeacon,
            lpTokenBeacon,
            wlpTokenBeacon,
            new ConstantExchangeRateProvider()
        );
    }
}
