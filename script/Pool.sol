// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Vm } from "forge-std/Vm.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { console } from "forge-std/console.sol";
import { Config } from "script/Config.sol";
import { SelfPeggingAssetFactory } from "../src/SelfPeggingAssetFactory.sol";
import { SelfPeggingAsset } from "../src/SelfPeggingAsset.sol";
import { MockToken } from "../src/mock/MockToken.sol";
import { MockExchangeRateProvider } from "../src/mock/MockExchangeRateProvider.sol";

contract Pool is Config {
    function createStandardPool() internal returns (address, address, address) {
        console.log("---------------");
        console.log("create-pool-logs");
        console.log("---------------");

        SelfPeggingAssetFactory.CreatePoolArgument memory arg = SelfPeggingAssetFactory.CreatePoolArgument({
            tokenA: usdc,
            tokenB: usdt,
            tokenAType: SelfPeggingAssetFactory.TokenType.Standard,
            tokenAOracle: address(0),
            tokenARateFunctionSig: "",
            tokenADecimalsFunctionSig: "",
            tokenBType: SelfPeggingAssetFactory.TokenType.Standard,
            tokenBOracle: address(0),
            tokenBRateFunctionSig: "",
            tokenBDecimalsFunctionSig: ""
        });

        vm.recordLogs();
        factory.createPool(arg);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 eventSig = keccak256("PoolCreated(address,address,address)");

        address decodedPoolToken;
        address decodedSelfPeggingAsset;
        address decodedWrappedPoolToken;

        for (uint256 i = 0; i < entries.length; i++) {
            Vm.Log memory log = entries[i];

            if (log.topics[0] == eventSig) {
                (decodedPoolToken, decodedSelfPeggingAsset, decodedWrappedPoolToken) =
                    abi.decode(log.data, (address, address, address));
            }
        }

        return (decodedPoolToken, decodedSelfPeggingAsset, decodedWrappedPoolToken);
    }

    function createStandardAndExchangeRateTokenPool(uint256 exchangeRate)
        internal
        returns (address, address, address)
    {
        console.log("---------------");
        console.log("create-pool-logs");
        console.log("---------------");

        MockExchangeRateProvider exchangeRateProvider = new MockExchangeRateProvider(exchangeRate, 18);
        address exchangeRateProviderAddress = address(exchangeRateProvider);

        SelfPeggingAssetFactory.CreatePoolArgument memory arg = SelfPeggingAssetFactory.CreatePoolArgument({
            tokenA: weth,
            tokenB: wstETH,
            tokenAType: SelfPeggingAssetFactory.TokenType.Standard,
            tokenAOracle: address(0),
            tokenARateFunctionSig: "",
            tokenADecimalsFunctionSig: "",
            tokenBType: SelfPeggingAssetFactory.TokenType.Oracle,
            tokenBOracle: exchangeRateProviderAddress,
            tokenBRateFunctionSig: abi.encodePacked(MockExchangeRateProvider.exchangeRate.selector),
            tokenBDecimalsFunctionSig: abi.encodePacked(MockExchangeRateProvider.exchangeRateDecimals.selector)
        });

        vm.recordLogs();
        factory.createPool(arg);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 eventSig = keccak256("PoolCreated(address,address,address)");

        address decodedPoolToken;
        address decodedSelfPeggingAsset;
        address decodedWrappedPoolToken;

        for (uint256 i = 0; i < entries.length; i++) {
            Vm.Log memory log = entries[i];

            if (log.topics[0] == eventSig) {
                (decodedPoolToken, decodedSelfPeggingAsset, decodedWrappedPoolToken) =
                    abi.decode(log.data, (address, address, address));
            }
        }

        return (decodedPoolToken, decodedSelfPeggingAsset, decodedWrappedPoolToken);
    }

    function initialMint(uint256 wethAmount, uint256 wstETHAMount, SelfPeggingAsset selfPeggingAsset) internal {
        console.log("---------------");
        console.log("initial-mint-logs");
        console.log("---------------");

        MockToken(weth).approve(address(selfPeggingAsset), wethAmount);
        MockToken(wstETH).approve(address(selfPeggingAsset), wstETHAMount);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = wethAmount;
        amounts[1] = wstETHAMount;

        selfPeggingAsset.mint(amounts, 0);
    }
}
