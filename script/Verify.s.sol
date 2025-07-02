// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Vm } from "forge-std/Vm.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { SelfPeggingAsset } from "../src/SelfPeggingAsset.sol";
import { SelfPeggingAssetFactory } from "../src/SelfPeggingAssetFactory.sol";
import { SPAToken } from "../src/SPAToken.sol";
import { IRampAController } from "../src/interfaces/IRampAController.sol";
import { Keeper } from "../src/periphery/Keeper.sol";

contract Verify is Script {
    using stdJson for string;

    string private constant RPC_URL = "https://rpc.soniclabs.com";

    address private spa;
    address private keeper;
    address private factory;
    address private spaToken;
    IRampAController private rampA;

    struct Expected {
        uint256 mintFee;
        uint256 swapFee;
        uint256 redeemFee;
        uint256 offPegFeeMultiplier;
        uint256 A;
        uint256 minRampTime;
        uint256 bufferPercent;
        uint256 exchangeRateFeeFactor;
        uint256 rateChangeSkipPeriod;
        uint256 feeErrorMargin;
        uint256 yieldErrorMargin;
        uint256 decayPeriod;
        string tokenSymbol;
    }

    Expected private exp;

    function run() external {
        _setUp();
        _verify();
        console.log("Deployment configuration match expected values");
    }

    function _setUp() internal {
        // addresses
        string memory aJson = vm.readFile("broadcast/sonic-testnet.json");
        // string memory aJson = vm.readFile("broadcast/sonic-mainnet.json");
        spa = aJson.readAddress(".wSOSPool");
        factory = aJson.readAddress(".Factory");
        spaToken = aJson.readAddress(".wSOSPoolSPAToken");

        // expected
        string memory eJson = vm.readFile("script/expected.json");
        exp.mintFee = eJson.readUint(".mintFee");
        exp.swapFee = eJson.readUint(".swapFee");
        exp.redeemFee = eJson.readUint(".redeemFee");
        exp.offPegFeeMultiplier = eJson.readUint(".offPegFeeMultiplier");
        exp.A = eJson.readUint(".A");
        exp.minRampTime = eJson.readUint(".minRampTime");
        exp.bufferPercent = eJson.readUint(".bufferPercent");
        exp.exchangeRateFeeFactor = eJson.readUint(".exchangeRateFeeFactor");
        exp.rateChangeSkipPeriod = eJson.readUint(".rateChangeSkipPeriod");
        exp.feeErrorMargin = eJson.readUint(".feeErrorMargin");
        exp.yieldErrorMargin = eJson.readUint(".yieldErrorMargin");
        exp.decayPeriod = eJson.readUint(".decayPeriod");
        exp.tokenSymbol = eJson.readString(".tokenSymbol");
    }

    function _verify() internal {
        // SPA pool
        SelfPeggingAsset pool = SelfPeggingAsset(spa);
        keeper = pool.owner();
        rampA = pool.rampAController();
        _eq(pool.mintFee(), exp.mintFee, "mintFee");
        _eq(pool.swapFee(), exp.swapFee, "swapFee");
        _eq(pool.redeemFee(), exp.redeemFee, "redeemFee");
        _eq(pool.offPegFeeMultiplier(), exp.offPegFeeMultiplier, "offPegFeeMultiplier");
        _eq(pool.exchangeRateFeeFactor(), exp.exchangeRateFeeFactor, "exchangeRateFeeFactor");
        _eq(pool.rateChangeSkipPeriod(), exp.rateChangeSkipPeriod, "rateChangeSkipPeriod");
        _eq(pool.feeErrorMargin(), exp.feeErrorMargin, "feeErrorMargin");
        _eq(pool.yieldErrorMargin(), exp.yieldErrorMargin, "yieldErrorMargin");
        _eq(pool.decayPeriod(), exp.decayPeriod, "decayPeriod");

        // SPAToken
        SPAToken lp = SPAToken(spaToken);
        _eq(lp.bufferPercent(), exp.bufferPercent, "bufferPercent");
        _eq(lp.symbol(), exp.tokenSymbol, "tokenSymbol");

        // RampAController
        _eq(rampA.getA(), exp.A, "A (amp coeff)");
        _eq(rampA.minRampTime(), exp.minRampTime, "minRampTime");

        // Keeper
        _eq(Keeper(keeper).treasury(), SelfPeggingAssetFactory(factory).governor(), "treasury");
    }

    function _eq(uint256 actual, uint256 expected, string memory name) private pure {
        require(actual == expected, _err(name, expected, actual));
    }

    function _eq(string memory a, string memory b, string memory name) private pure {
        require(keccak256(bytes(a)) == keccak256(bytes(b)), _err(name, b, a));
    }

    function _eq(address a, address b, string memory name) private pure {
        require(a == b, _err(name, b, a));
    }

    function _err(string memory name, uint256 expVal, uint256 actVal) private pure returns (string memory) {
        return string(abi.encodePacked(name, " mismatch - expected ", _toString(expVal), ", got ", _toString(actVal)));
    }

    function _err(string memory name, address a, address b) private pure returns (string memory) {
        return string(abi.encodePacked(name, " mismatch - expected ", b, ", got ", a));
    }

    function _err(string memory name, string memory a, string memory b) private pure returns (string memory) {
        return string(abi.encodePacked(name, " mismatch - expected ", b, ", got ", a));
    }

    function _toString(uint256 value) private pure returns (string memory str) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        str = string(buffer);
    }
}
