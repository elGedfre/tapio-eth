// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Vm } from "forge-std/Vm.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { console } from "forge-std/console.sol";
import { Config } from "script/Config.sol";
import { StableAssetFactory } from "../src/StableAssetFactory.sol";
import { StableAsset } from "../src/StableAsset.sol";
import { MockToken } from "../src/mock/MockToken.sol";

contract Pool is Config {
    function createStandardPool() internal returns (address, address, address) {
        console.log("---------------");
        console.log("create-pool-logs");
        console.log("---------------");

        StableAssetFactory.CreatePoolArgument memory arg = StableAssetFactory.CreatePoolArgument({
            tokenA: usdc,
            tokenB: usdt,
            initialMinter: INITIAL_MINTER,
            tokenBType: StableAssetFactory.TokenBType.Standard,
            tokenBOracle: address(0),
            tokenBFunctionSig: ""
        });

        vm.recordLogs();
        factory.createPool(arg);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 eventSig = keccak256("PoolCreated(address,address,address)");

        address decodedPoolToken;
        address decodedStableAsset;
        address decodedWrappedPoolToken;

        for (uint256 i = 0; i < entries.length; i++) {
            Vm.Log memory log = entries[i];

            if (log.topics[0] == eventSig) {
                (decodedPoolToken, decodedStableAsset, decodedWrappedPoolToken) =
                    abi.decode(log.data, (address, address, address));
            }
        }

        return (decodedPoolToken, decodedStableAsset, decodedWrappedPoolToken);
    }

    function initialMintAndUnpause(uint256 usdcAmount, uint256 usdtAmount, address decodedStableAsset) internal {
        console.log("---------------");
        console.log("initial-mint-logs");
        console.log("---------------");

        MockToken(usdc).approve(address(factory), usdcAmount);
        MockToken(usdt).approve(address(factory), usdtAmount);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = usdcAmount;
        amounts[1] = usdtAmount;

        StableAsset stableAsset = StableAsset(decodedStableAsset);
        stableAsset.mint(amounts, 0);
    }
}
