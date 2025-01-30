// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { console } from "forge-std/console.sol";

import { SelfPeggingAssetFactory } from "../src/SelfPeggingAssetFactory.sol";
import { MockToken } from "../src/mock/MockToken.sol";
import { MockERC4626Token } from "../src/mock/MockERC4626Token.sol";
import { MockOracle } from "../src/mock/MockOracle.sol";
import { SelfPeggingAsset } from "../src/SelfPeggingAsset.sol";
import { LPToken } from "../src/LPToken.sol";
import { WLPToken } from "../src/WLPToken.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "../src/misc/ConstantExchangeRateProvider.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";

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
            tokenAFunctionSig: new bytes(0),
            tokenBType: SelfPeggingAssetFactory.TokenType.Standard,
            tokenBOracle: address(0),
            tokenBFunctionSig: new bytes(0)
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

        assertEq(poolToken.balanceOf(initialMinter), 200e18 - 1000 wei);
        assertNotEq(address(wrappedPoolToken), address(0));
    }

    function test_CreatePoolERC4626ExchangeRate() external {
        MockERC4626Token vaultTokenA = new MockERC4626Token();
        MockERC4626Token vaultTokenB = new MockERC4626Token();

        MockToken tokenA = new MockToken("test 1", "T1", 18);
        MockToken tokenB = new MockToken("test 2", "T2", 18);

        vaultTokenA.initialize(tokenA);
        vaultTokenB.initialize(tokenB);

        SelfPeggingAssetFactory.CreatePoolArgument memory arg = SelfPeggingAssetFactory.CreatePoolArgument({
            tokenA: address(vaultTokenA),
            tokenB: address(vaultTokenB),
            tokenAType: SelfPeggingAssetFactory.TokenType.ERC4626,
            tokenAOracle: address(0),
            tokenAFunctionSig: new bytes(0),
            tokenBType: SelfPeggingAssetFactory.TokenType.ERC4626,
            tokenBOracle: address(0),
            tokenBFunctionSig: new bytes(0)
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

        tokenA.approve(address(vaultTokenA), 100e18);
        tokenB.approve(address(vaultTokenB), 100e18);

        vaultTokenA.deposit(100e18, initialMinter);
        vaultTokenB.deposit(100e18, initialMinter);

        vaultTokenA.approve(address(selfPeggingAsset), 100e18);
        vaultTokenB.approve(address(selfPeggingAsset), 100e18);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100e18;
        amounts[1] = 100e18;

        vm.warp(block.timestamp + 1000);

        selfPeggingAsset.mint(amounts, 0);

        assertEq(poolToken.balanceOf(initialMinter), 200e18 - 1000 wei);
        assertNotEq(address(wrappedPoolToken), address(0));
    }

    function test_CreatePoolOracleExchangeRate() external {
        MockToken tokenA = new MockToken("test 1", "T1", 18);
        MockToken tokenB = new MockToken("test 2", "T2", 18);

        MockOracle oracle = new MockOracle();

        SelfPeggingAssetFactory.CreatePoolArgument memory arg = SelfPeggingAssetFactory.CreatePoolArgument({
            tokenA: address(tokenA),
            tokenB: address(tokenB),
            tokenAType: SelfPeggingAssetFactory.TokenType.Oracle,
            tokenAOracle: address(oracle),
            tokenAFunctionSig: abi.encodePacked(MockOracle.rate.selector),
            tokenBType: SelfPeggingAssetFactory.TokenType.Oracle,
            tokenBOracle: address(oracle),
            tokenBFunctionSig: abi.encodePacked(MockOracle.rate.selector)
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

        assertEq(poolToken.balanceOf(initialMinter), 200e18 - 1000 wei);
        assertNotEq(address(wrappedPoolToken), address(0));
    }
}
