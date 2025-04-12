// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { stdJson } from "forge-std/StdJson.sol";
import { console } from "forge-std/console.sol";

import { Deploy } from "script/Deploy.sol";
import { Pool } from "script/Pool.sol";
import { MockToken } from "../src/mock/MockToken.sol";
import { SelfPeggingAsset } from "../src/SelfPeggingAsset.sol";
import { ChainlinkOracleProvider } from "../src/misc/ChainlinkOracleProvider.sol";
import "@chainlink/contracts/shared/interfaces/AggregatorV3Interface.sol";
import { SelfPeggingAssetFactory } from "../src/SelfPeggingAssetFactory.sol";

contract AddPool is Deploy, Pool {
    struct JSONData {
        address Factory;
        address LPTokenBeacon;
        address SelfPeggingAssetBeacon;
        address WLPTokenBeacon;
        address Zap;
    }

    function init() internal {
        if (vm.envUint("HEX_PRIV_KEY") == 0) revert("No private key found");
        deployerPrivateKey = vm.envUint("HEX_PRIV_KEY");
        DEPLOYER = vm.addr(deployerPrivateKey);
    }

    function run() public payable {
        init();
        loadConfig();

        vm.startBroadcast(deployerPrivateKey);

        deployZap();

        uint256 chainId = getChainId();
        string memory networkName = getNetworkName(chainId);
        string memory path = string.concat("./broadcast/", networkName, ".json");

        vm.writeJson(vm.serializeAddress("contracts", "Zap", zap), path);

        string memory json = vm.readFile(path);
        bytes memory data = vm.parseJson(json);
        JSONData memory jsonData = abi.decode(data, (JSONData));

        factory = SelfPeggingAssetFactory(jsonData.Factory);
        selfPeggingAssetBeacon = jsonData.SelfPeggingAssetBeacon;
        lpTokenBeacon = jsonData.LPTokenBeacon;
        wlpTokenBeacon = jsonData.WLPTokenBeacon;

        if (chainId == 8453) {
            // base mainnet
            address wstETHTostETHFeed = 0xB88BAc61a4Ca37C43a3725912B1f472c9A5bc061;
            address weETHToETHFeed = 0xFC1415403EbB0c693f9a7844b92aD2Ff24775C65;
            address stETHToETHFeed = 0xf586d0728a47229e747d824a939000Cf21dEF5A0;

            address wstETH = 0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452;
            address weETH = 0x04C0599Ae5A44757c0af6F9eC3b93da8976c150A;

            uint256 ethAmount = 0.0027e18;

            address sequencer = 0xBCF85224fc0756B9Fa45aA7892530B47e10b6433;

            // create chainlink oracle
            address wstETHTostETHOracle = address(
                new ChainlinkOracleProvider(
                    AggregatorV3Interface(sequencer), AggregatorV3Interface(wstETHTostETHFeed), 24 hours
                )
            );

            

            address weETHOracle = address(
                new ChainlinkOracleProvider(
                    AggregatorV3Interface(sequencer), AggregatorV3Interface(weETHFeed), 24 hours
                )
            );

            address cbETHOracle = address(
                new ChainlinkOracleProvider(
                    AggregatorV3Interface(sequencer), AggregatorV3Interface(cbETHFeed), 24 hours
                )
            );

            (, address pool,,) = createChainlinkPool(weth, wstETH, wstETHOracle);

            initialMint(weth, wstETH, ethAmount, ethAmount, SelfPeggingAsset(pool));
        }

        vm.stopBroadcast();
    }
}
