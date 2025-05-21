// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IParameterRegistry
 * @notice Interface for the immutable ParameterRegistry contract
 */
interface IParameterRegistry {
    /// @custom:storage-location erc7201:tapio.params.registry
    struct ParameterRegistryStorage {
        // A coefficient bounds
        Bounds aParams;
        // Swap fee bounds
        Bounds swapFeeParams;
        // Off-peg multiplier bounds
        Bounds offPegParams;
        // TBD
        Bounds mintFeeParams;
        Bounds redeemFeeParams;
    }

    /**
     * @notice Absolute limit and Relative per-tx ranges, expressed in ppm
     * @params max Absolute limit that can never be exceeded.
     * @params maxDecreasePct: e.g., 900000 = -90%
     * @params maxIncreasePct: e.g., 9000000 = +900%
     */
    struct Bounds {
        uint256 max;
        uint32 maxDecreasePct;
        uint32 maxIncreasePct;
    }

    error ZeroAddress();

    event AParamsUpdated(address indexed caller, Bounds oldParams, Bounds newParams);
    event SwapFeeParamsUpdated(address indexed caller, Bounds oldParams, Bounds newParams);
    event OffPegParamsUpdated(address indexed caller, Bounds oldParams, Bounds newParams);
    event MintFeeParamsUpdated(address indexed caller, Bounds oldParams, Bounds newParams);
    event RedeemFeeParamsUpdated(address indexed caller, Bounds oldParams, Bounds newParams);

    function aParams() external view returns (Bounds memory);
    function swapFeeParams() external view returns (Bounds memory);
    function mintFeeParams() external view returns (Bounds memory);
    function redeemFeeParams() external view returns (Bounds memory);
    function offPegParams() external view returns (Bounds memory);

    function setAParams(Bounds calldata params) external;
    function setSwapFeeParams(Bounds calldata params) external;
    function setMintFeeParams(Bounds calldata params) external;
    function setRedeemFeeParams(Bounds calldata params) external;
    function setOffPegParams(Bounds calldata params) external;
}
