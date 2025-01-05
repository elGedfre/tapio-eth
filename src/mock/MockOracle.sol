// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract MockOracle {
    function rate() external pure returns (uint256) {
        return 1e18;
    }
}
