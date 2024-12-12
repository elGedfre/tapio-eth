pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { console } from "forge-std/console.sol";

import { StableAssetFactory } from "../src/StableAssetFactory.sol";
import { MockToken } from "../src/mock/MockToken.sol";
import { StableAsset } from "../src/StableAsset.sol";
import { LPToken } from "../src/LPToken.sol";
import { WLPToken } from "../src/WLPToken.sol";

contract FactoryTest is Test {
    StableAssetFactory internal factory;
    address governance = address(0x01);
    address initialMinter = address(0x02);

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
            initialMinter: address(initialMinter),
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

        StableAsset stableAsset = StableAsset(decodedStableAsset);
        LPToken poolToken = LPToken(decodedPoolToken);
        WLPToken wrappedPoolToken = WLPToken(decodedWrappedPoolToken);

        vm.startPrank(initialMinter);
        tokenA.mint(initialMinter, 100e18);
        tokenB.mint(initialMinter, 100e18);

        tokenA.approve(address(stableAsset), 100e18);
        tokenB.approve(address(stableAsset), 100e18);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100e18;
        amounts[1] = 100e18;

        vm.warp(block.timestamp + 1000);

        stableAsset.mint(amounts, 0);

        assertEq(poolToken.balanceOf(initialMinter), 200e18);
    }
}
