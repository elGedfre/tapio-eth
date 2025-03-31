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

        vm.startPrank(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);

        deployBeacons();
        deployFactory();
        deployZap();

        uint256 chainId = getChainId();
        string memory networkName = getNetworkName(chainId);
        string memory path = string.concat("./broadcast/", networkName, ".json");

        vm.writeJson(vm.serializeAddress("contracts", "Factory", address(factory)), path);

        vm.writeJson(vm.serializeAddress("contracts", "SelfPeggingAssetBeacon", selfPeggingAssetBeacon), path);

        vm.writeJson(vm.serializeAddress("contracts", "LPTokenBeacon", lpTokenBeacon), path);

        vm.writeJson(vm.serializeAddress("contracts", "WLPTokenBeacon", wlpTokenBeacon), path);

        vm.writeJson(vm.serializeAddress("contracts", "Zap", zap), path);

        if (chainId == 8453) {
            // base mainnet
            address wstETHFeed = 0x43a5C292A453A3bF3606fa856197f09D7B74251a;
            address weETHFeed = 0xFC1415403EbB0c693f9a7844b92aD2Ff24775C65;
            address cbETHFeed = 0x806b4Ac04501c29769051e42783cF04dCE41440b;

            address weth = 0x4200000000000000000000000000000000000006;
            address wstETH = 0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452;
            address weETH = 0x04C0599Ae5A44757c0af6F9eC3b93da8976c150A;
            address cbETH = 0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22;
            address usdc = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
            address usdt = 0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2;

            uint256 ethAmount = 0.0027e18;
            uint256 usdAmount = 5e6;

            address sequencer = 0xBCF85224fc0756B9Fa45aA7892530B47e10b6433;

            // create chainlink oracle
            address wstETHOracle = address(
                new ChainlinkOracleProvider(
                    AggregatorV3Interface(sequencer), AggregatorV3Interface(wstETHFeed), 24 hours
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

            (, pool,,) = createChainlinkPool(weth, weETH, weETHOracle);

            initialMint(weth, weETH, ethAmount, ethAmount, SelfPeggingAsset(pool));

            (, pool,,) = createChainlinkPool(weth, cbETH, cbETHOracle);

            initialMint(weth, cbETH, ethAmount, ethAmount, SelfPeggingAsset(pool));

            (, pool,,) = createStandardPool(usdc, usdt);

            initialMint(usdc, usdt, usdAmount, usdAmount, SelfPeggingAsset(pool));
        }

        vm.stopPrank();
    }
}
