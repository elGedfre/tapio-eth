// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../interfaces/IExchangeRateProvider.sol";

/**
 * @notice Oracle exchange rate.
 */
contract OracleExchangeRate is IExchangeRateProvider {
    /// @dev Oracle address
    address public oracle;

    /// @dev Function signature
    string public func;

    /// @dev Error thrown when the internal call failed
    error InternalCallFailed();

    /// @dev Initialize the contract
    constructor(address _oracle, string memory _func) {
        oracle = _oracle;
        func = _func;
    }

    /// @dev Get the exchange rate
    function exchangeRate() external view returns (uint256) {
        bytes memory data = abi.encodeWithSignature(string(abi.encodePacked(func, "()")));

        (bool success, bytes memory result) = oracle.staticcall(data);
        require(success, InternalCallFailed());

        uint256 decodedResult = abi.decode(result, (uint256));

        return decodedResult;
    }

    /// @dev Get the exchange rate decimals
    function exchangeRateDecimals() external pure returns (uint256) {
        return 18;
    }
}
