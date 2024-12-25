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
import "../src/mock/MockExchangeRateProvider.sol";

contract SelfPeggingAssetTest is Test {
    address owner = address(0x01);
    address user = address(0x02);
    uint256 A = 100;
    LPToken lpToken;
    SelfPeggingAsset pool; // WETH and frxETH Pool
    uint256 feeDenominator = 10_000_000_000;
    uint256 mintFee = 10_000_000;
    uint256 swapFee = 20_000_000;
    uint256 redeemFee = 50_000_000;
    MockToken WETH;
    MockToken frxETH;

    function setUp() public {
        WETH = new MockToken("WETH", "WETH", 18);
        frxETH = new MockToken("frxETH", "frxETH", 18);

        lpToken = new LPToken();
        lpToken.initialize("LP Token", "LPT");
        lpToken.transferOwnership(owner);

        ConstantExchangeRateProvider exchangeRateProvider = new ConstantExchangeRateProvider();

        pool = new SelfPeggingAsset();

        address[] memory tokens = new address[](2);
        tokens[0] = address(WETH);
        tokens[1] = address(frxETH);

        uint256[] memory precisions = new uint256[](2);
        precisions[0] = 1;
        precisions[1] = 1;

        uint256[] memory fees = new uint256[](3);
        fees[0] = mintFee;
        fees[1] = swapFee;
        fees[2] = redeemFee;

        IExchangeRateProvider[] memory exchangeRateProviders = new IExchangeRateProvider[](2);
        exchangeRateProviders[0] = exchangeRateProvider;
        exchangeRateProviders[1] = exchangeRateProvider;

        pool.initialize(tokens, precisions, fees, lpToken, A, exchangeRateProviders);

        vm.prank(owner);
        lpToken.addPool(address(pool));
    }

    function test_CorrectMintAmount_EqualTokenAmounts() external {
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100e18;
        amounts[1] = 100e18;

        WETH.mint(user, 100e18);
        frxETH.mint(user, 100e18);

        vm.startPrank(user);
        WETH.approve(address(pool), 100e18);
        frxETH.approve(address(pool), 100e18);
        vm.stopPrank();

        (uint256 lpTokensMinted, uint256 feesCharged) = pool.getMintAmount(amounts);

        uint256 totalAmount = lpTokensMinted + feesCharged;
        assertEq(totalAmount, 200e18);

        assertFee(totalAmount, feesCharged, mintFee);

        assertEq(100e18, WETH.balanceOf(user));
        assertEq(100e18, frxETH.balanceOf(user));
        assertEq(0, lpToken.balanceOf(user));
        assertEq(0, pool.balances(0));
        assertEq(0, pool.balances(1));
        assertEq(0, pool.totalSupply());

        vm.prank(user);
        pool.mint(amounts, 0);

        assertEq(0, WETH.balanceOf(user));
        assertEq(0, frxETH.balanceOf(user));
        assertEq(totalAmount, lpToken.balanceOf(user));
        assertEq(lpTokensMinted, lpToken.sharesOf(user));
        assertEq(totalAmount, lpToken.totalSupply());
    }

    function test_CorrectMintAmount_UnequalTokenAmounts() external view {
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 110e18;
        amounts[1] = 90e18;

        (uint256 lpTokensMinted, uint256 feesCharged) = pool.getMintAmount(amounts);

        assertFee(lpTokensMinted + feesCharged, feesCharged, mintFee);
    }

    function test_Pegging_UnderlyingToken() external {
        MockExchangeRateProvider rETHExchangeRateProvider = new MockExchangeRateProvider(1.1e18, 18);
        MockExchangeRateProvider wstETHExchangeRateProvider = new MockExchangeRateProvider(1.2e18, 18);

        MockToken rETH = new MockToken("rETH", "rETH", 18);
        MockToken wstETH = new MockToken("wstETH", "wstETH", 18);

        address[] memory _tokens = new address[](2);
        _tokens[0] = address(rETH);
        _tokens[1] = address(wstETH);

        IExchangeRateProvider[] memory exchangeRateProviders = new IExchangeRateProvider[](2);
        exchangeRateProviders[0] = IExchangeRateProvider(rETHExchangeRateProvider);
        exchangeRateProviders[1] = IExchangeRateProvider(wstETHExchangeRateProvider);

        SelfPeggingAsset _pool = new SelfPeggingAsset();

        LPToken _lpToken = new LPToken();
        _lpToken.initialize("LP Token", "LPT");
        _lpToken.transferOwnership(owner);

        uint256[] memory _fees = new uint256[](3);
        _fees[0] = 0;
        _fees[1] = 0;
        _fees[2] = 0;

        uint256[] memory _precisions = new uint256[](2);
        _precisions[0] = 1;
        _precisions[1] = 1;

        _pool.initialize(_tokens, _precisions, _fees, _lpToken, A, exchangeRateProviders);

        vm.prank(owner);
        _lpToken.addPool(address(_pool));

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 110e18;
        amounts[1] = 90e18;

        (uint256 lpTokensMinted,) = _pool.getMintAmount(amounts);

        assertEq(true, isCloseTo(lpTokensMinted, 229e18, 0.01e18));
    }

    function assertFee(uint256 totalAmount, uint256 feeAmount, uint256 fee) internal view {
        uint256 expectedFee = totalAmount * fee / feeDenominator;
        assertEq(feeAmount, expectedFee);
    }

    function isCloseTo(uint256 a, uint256 b, uint256 tolerance) public pure returns (bool) {
        if (a > b) {
            return a - b <= tolerance;
        } else {
            return b - a <= tolerance;
        }
    }
}
