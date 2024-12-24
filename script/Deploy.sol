// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { console } from "forge-std/console.sol";
import { SelfPeggingAsset } from "../src/SelfPeggingAsset.sol";
import { LPToken } from "../src/LPToken.sol";
import { WLPToken } from "../src/WLPToken.sol";
import { SelfPeggingAssetFactory } from "../src/SelfPeggingAssetFactory.sol";
import { Config } from "script/Config.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/misc/ConstantExchangeRateProvider.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

contract Deploy is Config {
    function deployBeacons() internal {
        console.log("---------------");
        console.log("deploy-beacon-logs");
        console.log("---------------");

        address selfPeggingAssetImplentation = address(new SelfPeggingAsset());
        address lpTokenImplentation = address(new LPToken());
        address wlpTokenImplentation = address(new WLPToken());

        UpgradeableBeacon beacon = new UpgradeableBeacon(selfPeggingAssetImplentation);
        selfPeggingAssetBeacon = address(beacon);

        beacon = new UpgradeableBeacon(lpTokenImplentation);
        lpTokenBeacon = address(beacon);

        beacon = new UpgradeableBeacon(wlpTokenImplentation);
        wlpTokenBeacon = address(beacon);

        UpgradeableBeacon(selfPeggingAssetBeacon).transferOwnership(GOVERNOR);
        UpgradeableBeacon(lpTokenBeacon).transferOwnership(GOVERNOR);
        UpgradeableBeacon(wlpTokenBeacon).transferOwnership(GOVERNOR);
    }

    function deployFactory() internal {
        console.log("---------------");
        console.log("deploy-factory-logs");
        console.log("---------------");

        bytes memory data = abi.encodeCall(
            SelfPeggingAssetFactory.initialize,
            (
                GOVERNOR,
                0,
                0,
                0,
                100,
                selfPeggingAssetBeacon,
                lpTokenBeacon,
                wlpTokenBeacon,
                new ConstantExchangeRateProvider()
            )
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(new SelfPeggingAssetFactory()), data);

        factory = SelfPeggingAssetFactory(address(proxy));
        factory.transferOwnership(GOVERNOR);
    }
}
