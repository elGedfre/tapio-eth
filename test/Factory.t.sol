// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { console } from "forge-std/console.sol";

import { SelfPeggingAssetFactory } from "../src/SelfPeggingAssetFactory.sol";
import { MockToken } from "../src/mock/MockToken.sol";
import { SelfPeggingAsset } from "../src/SelfPeggingAsset.sol";
import { LPToken } from "../src/LPToken.sol";
import { WLPToken } from "../src/WLPToken.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "../src/misc/ConstantExchangeRateProvider.sol";

contract FactoryTest is Test {
    SelfPeggingAssetFactory internal factory;
    address governor = address(0x01);
    address initialMinter = address(0x02);

    function setUp() public virtual {
        factory = new SelfPeggingAssetFactory();

        address selfPeggingAssetImplentation = address(new SelfPeggingAsset());
        address lpTokenImplentation = address(new LPToken());
        address wlpTokenImplentation = address(new WLPToken());

        UpgradeableBeacon beacon = new UpgradeableBeacon(selfPeggingAssetImplentation, governor);
        address selfPeggingAssetBeacon = address(beacon);

        beacon = new UpgradeableBeacon(lpTokenImplentation, governor);
        address lpTokenBeacon = address(beacon);

        beacon = new UpgradeableBeacon(wlpTokenImplentation, governor);
        address wlpTokenBeacon = address(beacon);

        factory.initialize(
            governor,
            0,
            0,
            0,
            100,
            selfPeggingAssetBeacon,
            lpTokenBeacon,
            wlpTokenBeacon,
            new ConstantExchangeRateProvider()
        );
    }

    function test_CreatePoolConstantExchangeRate() external {
        MockToken tokenA = new MockToken("test 1", "T1", 18);
        MockToken tokenB = new MockToken("test 2", "T2", 18);

        SelfPeggingAssetFactory.CreatePoolArgument memory arg = SelfPeggingAssetFactory.CreatePoolArgument({
            tokenA: address(tokenA),
            tokenB: address(tokenB),
            tokenAType: SelfPeggingAssetFactory.TokenType.Standard,
            tokenAOracle: address(0),
            tokenAFunctionSig: "",
            tokenBType: SelfPeggingAssetFactory.TokenType.Standard,
            tokenBOracle: address(0),
            tokenBFunctionSig: ""
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

        SelfPeggingAsset selfPeggingAsset = SelfPeggingAsset(decodedSelfPeggingAsset);
        LPToken poolToken = LPToken(decodedPoolToken);
        WLPToken wrappedPoolToken = WLPToken(decodedWrappedPoolToken);

        vm.startPrank(initialMinter);
        tokenA.mint(initialMinter, 100e18);
        tokenB.mint(initialMinter, 100e18);

        tokenA.approve(address(selfPeggingAsset), 100e18);
        tokenB.approve(address(selfPeggingAsset), 100e18);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100e18;
        amounts[1] = 100e18;

        vm.warp(block.timestamp + 1000);

        selfPeggingAsset.mint(amounts, 0);

        assertEq(poolToken.balanceOf(initialMinter), 200e18);
        assertNotEq(address(wrappedPoolToken), address(0));
    }
}
