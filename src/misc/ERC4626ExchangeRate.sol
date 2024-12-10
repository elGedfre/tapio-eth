// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "../interfaces/IExchangeRateProvider.sol";

/**
 * @notice ERC4626 exchange rate.
 */
contract ERC4626ExchangeRate is IExchangeRateProvider {
    IERC4626 token;

    constructor(IERC4626 _token) {
        token = _token;
    }

    function exchangeRate() external view returns (uint256) {
        return token.convertToAssets(1e18);
    }

    function exchangeRateDecimals() external pure returns (uint256) {
        return 18;
    }
}
