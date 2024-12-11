pragma solidity ^0.8.28;

// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { console } from "forge-std/console.sol";

import { StableAssetFactory } from "../src/StableAssetFactory.sol";
import { MockToken } from "../src/mock/MockToken.sol";

contract FooTest is Test {
    StableAssetFactory internal factory;
    address governance = address(0x01);
    address initialMiner = address(0x02);

    function setUp() public virtual {
        factory = new StableAssetFactory();
        factory.initialize(governance, 0, 0, 0, 100);
    }

    function test_CreatePoolConstantExchangeRate() external {
        MockToken tokenA = new MockToken("test 1", "T1", 18);
        MockToken tokenB = new MockToken("test 2", "T2", 18);

        StableAssetFactory.CreatePoolArgument memory arg = StableAssetFactory.CreatePoolArgument({
            tokenA: address(tokenA),
            tokenB: address(tokenB),
            initialMinter: address(initialMiner),
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
                console.logBytes(log.data);
                (decodedPoolToken, decodedStableAsset, decodedWrappedPoolToken) =
                    abi.decode(log.data, (address, address, address));
                console.log("Pool Token:", decodedPoolToken);
                console.log("Stable Asset:", decodedStableAsset);
                console.log("Wrapped Pool Token:", decodedWrappedPoolToken);
            }
        }
    }
}
