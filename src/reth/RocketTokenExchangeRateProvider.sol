// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../interfaces/IExchangeRateProvider.sol";
import "./RocketTokenRETHInterface.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

/**
 * @notice Rocket Token exchange rate.
 */
contract RocketTokenExchangeRateProvider is IExchangeRateProvider, Initializable, ReentrancyGuardUpgradeable {
    RocketTokenRETHInterface private rocketToken;

    error RocketTokenNotSet();

    function initialize(RocketTokenRETHInterface _rocketToken) public initializer {
        require(address(_rocketToken) != address(0x0), RocketTokenNotSet());
        rocketToken = _rocketToken;
    }

    function exchangeRate() external view returns (uint256) {
        return rocketToken.getExchangeRate();
    }

    function exchangeRateDecimals() external pure returns (uint256) {
        return 18;
    }
}
