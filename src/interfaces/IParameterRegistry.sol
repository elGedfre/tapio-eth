// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IParameterRegistry
 * @notice Interface for the immutable ParameterRegistry contract
 */
interface IParameterRegistry {
    /**
     * @notice Absolute limits that can never be exceeded.
     */
    struct AbsoluteCaps {
        // A coefficient bound
        uint256 aMax; // Max allowed value for amplification coefficient A
        // Fee bounds (all values in FEE_DENOMINATOR = 1e10 units)
        uint256 swapFeeMax; // Max allowed swap fee
        uint256 mintFeeMax; // Max allowed mint fee (future-proof)
        uint256 redeemFeeMax; // Max allowed redeem fee (future-proof)
        // Other parameter limits
        uint256 offPegMax; // Max allowed off-peg fee multiplier
    }

    /**
     * @notice Relative per-tx ranges, expressed in ppm (precision 1e6 = 100%)
     * - MaxDecreasePct: e.g., 900000 = -90%
     * - MaxIncreasePct: e.g., 9000000 = +900%
     */
    struct RelativeRanges {
        // A coefficient bounds
        uint32 aMaxDecreasePct; // max decrease of A vs current value
        uint32 aMaxIncreasePct; // max increase of A vs current value
        // Swap fee bounds
        uint32 swapFeeMaxDecreasePct;
        uint32 swapFeeMaxIncreasePct;
        // future-proof
        uint32 mintFeeMaxDecreasePct;
        uint32 mintFeeMaxIncreasePct;
        uint32 redeemFeeMaxDecreasePct;
        uint32 redeemFeeMaxIncreasePct;
        // Off-peg multiplier bounds
        uint32 offPegMaxDecreasePct;
        uint32 offPegMaxIncreasePct;
    }

    /**
     * @notice Get the current absolute caps
     * @return Current absolute caps
     */
    function absCaps() external view returns (AbsoluteCaps memory);

    /**
     * @notice Get the current relative ranges
     * @return Current relative ranges
     */
    function relRanges() external view returns (RelativeRanges memory);

    /**
     * @notice Set new absolute caps (Governor only)
     * @param absCaps New absolute caps
     */
    function setAbsoluteCaps(AbsoluteCaps calldata absCaps) external;

    /**
     * @notice Set new relative ranges (Governor only)
     * @param relRanges New relative ranges
     */
    function setRelativeRanges(RelativeRanges calldata relRanges) external;
}
