// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { stdJson } from "forge-std/StdJson.sol";
import { console } from "forge-std/console.sol";
import { Config } from "script/Config.sol";
import { SelfPeggingAsset } from "src/SelfPeggingAsset.sol";
import { LPToken } from "src/LPToken.sol";
import { WLPToken } from "src/WLPToken.sol";
import { RampAController } from "src/periphery/RampAController.sol";
import { SelfPeggingAssetFactory } from "src/SelfPeggingAssetFactory.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { Zap } from "src/periphery/Zap.sol";
import { ConstantExchangeRateProvider } from "src/misc/ConstantExchangeRateProvider.sol";

contract Deploy is Config {
    address public selfPeggingAssetBeacon;
    address public lpTokenBeacon;
    address public wlpTokenBeacon;
    address public rampAControllerBeacon;
    SelfPeggingAssetFactory public factory;
    address public zap;

    struct FactoryInitConfig {
        address governor;
        uint256 mintFee;
        uint256 swapFee;
        uint256 redeemFee;
        uint256 offPegFeeMultiplier;
        uint256 A;
        uint256 minRampTime;
        uint256 exchangeRateFeeFactor;
        uint256 bufferPercent;
    }

    function run() public payable {
        setUp(); // initialize DEPLOYER and keys from Config

        string memory chain = vm.envString("CHAIN");
        uint256 chainId = vm.envUint("CHAIN_ID");
        string memory path = getDeploymentPath(chain);

        vm.createSelectFork(vm.envString(rpcs[chainId]));

        string memory configPath =
            string(abi.encodePacked(vm.projectRoot(), "/script/configs/", chain, "/factory.json"));
        string memory configJson = vm.readFile(configPath);
        FactoryInitConfig memory initConfig = abi.decode(vm.parseJson(configJson, ".initialize"), (FactoryInitConfig));

        vm.startBroadcast(deployerPrivateKey);

        deployBeacons();
        deployFactory(initConfig);
        deployZap();

        // write core deployment data
        string memory json = "";
        json = vm.serializeAddress("", "Factory", address(factory));
        json = lpTokenBeacon != address(0) ? vm.serializeAddress("", "LPTokenBeacon", lpTokenBeacon) : json;
        json = selfPeggingAssetBeacon != address(0)
            ? vm.serializeAddress("", "SelfPeggingAssetBeacon", selfPeggingAssetBeacon)
            : json;
        json = wlpTokenBeacon != address(0) ? vm.serializeAddress("", "WLPTokenBeacon", wlpTokenBeacon) : json;
        json = zap != address(0) ? vm.serializeAddress("", "Zap", zap) : json;

        writeJsonFile(path, json);

        vm.stopBroadcast();
    }

    function deployBeacons() internal {
        console.log("---------------");
        console.log("deploy-beacon-logs");
        console.log("---------------");

        address selfPeggingAssetImpl = address(new SelfPeggingAsset());
        address lpTokenImpl = address(new LPToken());
        address wlpTokenImpl = address(new WLPToken());
        address rampAControllerImpl = address(new RampAController());

        selfPeggingAssetBeacon = address(new UpgradeableBeacon(selfPeggingAssetImpl, ADMIN));
        lpTokenBeacon = address(new UpgradeableBeacon(lpTokenImpl, ADMIN));
        wlpTokenBeacon = address(new UpgradeableBeacon(wlpTokenImpl, ADMIN));
        rampAControllerBeacon = address(new UpgradeableBeacon(rampAControllerImpl, ADMIN));
    }

    function deployFactory(FactoryInitConfig memory initConfig) internal {
        console.log("---------------");
        console.log("deploy-factory-logs");
        console.log("---------------");

        ConstantExchangeRateProvider constantExchangeRateProvider = new ConstantExchangeRateProvider();

        bytes memory data = abi.encodeCall(
            SelfPeggingAssetFactory.initialize,
            (
                initConfig.governor == address(0) ? ADMIN : initConfig.governor,
                initConfig.mintFee,
                initConfig.swapFee,
                initConfig.redeemFee,
                initConfig.offPegFeeMultiplier,
                initConfig.A,
                initConfig.minRampTime,
                selfPeggingAssetBeacon,
                lpTokenBeacon,
                wlpTokenBeacon,
                rampAControllerBeacon,
                constantExchangeRateProvider,
                initConfig.exchangeRateFeeFactor,
                initConfig.bufferPercent
            )
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(new SelfPeggingAssetFactory()), data);
        factory = SelfPeggingAssetFactory(address(proxy));
        factory.transferOwnership(ADMIN);
    }

    function deployZap() internal {
        console.log("---------------");
        console.log("deploy-zap-logs");
        console.log("---------------");

        zap = address(new Zap());
    }
}
