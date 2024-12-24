// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../interfaces/IExchangeRateProvider.sol";

/**
 * @notice Oracle exchange rate.
 */
contract OracleExchangeRate is IExchangeRateProvider {
    address public oracle;
    string public func;

    error InternalCallFailed();

    constructor(address _oracle, string memory _func) {
        oracle = _oracle;
        func = _func;
    }

    function exchangeRate() external view returns (uint256) {
        bytes memory data = abi.encodeWithSignature(string(abi.encodePacked(func, "()")));

        (bool success, bytes memory result) = oracle.staticcall(data);
        require(success, InternalCallFailed());

        uint256 decodedResult = abi.decode(result, (uint256));

        return decodedResult;
    }

    function exchangeRateDecimals() external pure returns (uint256) {
        return 18;
    }
}
