// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { console } from "forge-std/console.sol";
import { SelfPeggingAsset } from "../src/SelfPeggingAsset.sol";
import { SPAToken } from "../src/SPAToken.sol";
import { WSPAToken } from "../src/WSPAToken.sol";
import { SelfPeggingAssetFactory } from "../src/SelfPeggingAssetFactory.sol";
import { Config } from "script/Config.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/misc/ConstantExchangeRateProvider.sol";
import { Zap } from "../src/periphery/Zap.sol";
import { Keeper } from "../src/periphery/Keeper.sol";
import { RampAController } from "../src/periphery/RampAController.sol";

contract Deploy is Config {
    using stdJson for string;

    struct Config {
        uint256 mintFee;
        uint256 swapFee;
        uint256 redeemFee;
        uint256 offPegFeeMultiplier;
        uint256 A;
        uint256 minRampTime;
        uint256 bufferPercent;
        uint256 exchangeRateFeeFactor;
    }

    Config private cfg;

    function deployBeacons() internal {
        console.log("---------------");
        console.log("deploy-beacon-logs");
        console.log("---------------");

        address selfPeggingAssetImplementation = address(new SelfPeggingAsset());
        address spaTokenImplementation = address(new SPAToken());
        address wspaTokenImplementation = address(new WSPAToken());
        address rampAControllerImplementation = address(new RampAController());
        keeperImplementation = address(new Keeper());

        UpgradeableBeacon beacon = new UpgradeableBeacon(selfPeggingAssetImplementation, GOVERNOR);
        selfPeggingAssetBeacon = address(beacon);

        beacon = new UpgradeableBeacon(spaTokenImplementation, GOVERNOR);
        spaTokenBeacon = address(beacon);

        beacon = new UpgradeableBeacon(wspaTokenImplementation, GOVERNOR);
        wspaTokenBeacon = address(beacon);

        beacon = new UpgradeableBeacon(rampAControllerImplementation, GOVERNOR);
        rampAControllerBeacon = address(beacon);
    }

    function deployFactory(string memory networkName) internal {
        string memory path = string.concat("script/configs/", networkName, ".json");
        string memory cJson = vm.readFile(path);

        cfg.mintFee = cJson.readUint(".mintFee");
        cfg.swapFee = cJson.readUint(".swapFee");
        cfg.redeemFee = cJson.readUint(".redeemFee");
        cfg.offPegFeeMultiplier = cJson.readUint(".offPegFeeMultiplier");
        cfg.A = cJson.readUint(".A");
        cfg.minRampTime = cJson.readUint(".minRampTime");
        cfg.exchangeRateFeeFactor = cJson.readUint(".exchangeRateFeeFactor");
        cfg.bufferPercent = cJson.readUint(".bufferPercent");

        console.log("---------------");
        console.log("deploy-factory-logs");
        console.log("---------------");

        bytes memory data = abi.encodeCall(
            SelfPeggingAssetFactory.initialize,
            SelfPeggingAssetFactory.InitializeArgument(
                DEPLOYER,
                GOVERNOR,
                cfg.mintFee,
                cfg.swapFee,
                cfg.redeemFee,
                cfg.offPegFeeMultiplier,
                cfg.A,
                cfg.minRampTime,
                selfPeggingAssetBeacon,
                spaTokenBeacon,
                wspaTokenBeacon,
                rampAControllerBeacon,
                keeperImplementation,
                address(new ConstantExchangeRateProvider()),
                cfg.exchangeRateFeeFactor,
                cfg.bufferPercent
            )
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(new SelfPeggingAssetFactory()), data);

        factory = SelfPeggingAssetFactory(address(proxy));
        factory.transferOwnership(GOVERNOR);
    }

    function deployZap() internal {
        console.log("---------------");
        console.log("deploy-zap-logs");
        console.log("---------------");

        zap = address(new Zap());
    }
}
