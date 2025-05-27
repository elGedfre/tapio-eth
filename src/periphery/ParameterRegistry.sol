// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IParameterRegistry.sol";
import "../SelfPeggingAsset.sol";

/**
 * @title ParameterRegistry
 * @notice Stores hard caps and per-transaction relative ranges that bound keeper operations.
 * @dev Only the Governor (admin role) can modify values.
 * Each SPA has its own ParameterRegistry
 */
contract ParameterRegistry is IParameterRegistry, Ownable {
    uint256 private constant MAX_A = 10 ** 6; // 1M
    uint32 private constant MAX_DECREASE_PCT_A = 900_000; // -90%
    uint32 private constant MAX_INCREASE_PCT_A = 9_000_000; // +900%

    /// @notice SPA this registry is connected
    SelfPeggingAsset public spa;

    mapping(ParamKey => Bounds) public bounds;

    constructor(address _governor, address _spa) Ownable(_governor) {
        require(_spa != address(0), ZeroAddress());

        spa = SelfPeggingAsset(_spa);

        // set default values for A boundry
        bounds[ParamKey.A] =
            Bounds({ max: MAX_A, maxDecreasePct: MAX_DECREASE_PCT_A, maxIncreasePct: MAX_INCREASE_PCT_A });
    }

    /**
     * @inheritdoc IParameterRegistry
     */
    function setBounds(ParamKey key, Bounds calldata newBounds) external onlyOwner {
        emit BoundsUpdated(msg.sender, key, bounds[key], newBounds);
        bounds[key] = newBounds;
    }

    /**
     * @inheritdoc IParameterRegistry
     */
    function aParams() external view returns (Bounds memory) {
        return bounds[ParamKey.A];
    }

    /**
     * @inheritdoc IParameterRegistry
     */
    function swapFeeParams() external view returns (Bounds memory) {
        return bounds[ParamKey.SwapFee];
    }

    /**
     * @inheritdoc IParameterRegistry
     */
    function mintFeeParams() external view returns (Bounds memory) {
        return bounds[ParamKey.MintFee];
    }

    /**
     * @inheritdoc IParameterRegistry
     */
    function redeemFeeParams() external view returns (Bounds memory) {
        return bounds[ParamKey.RedeemFee];
    }

    /**
     * @inheritdoc IParameterRegistry
     */
    function offPegParams() external view returns (Bounds memory) {
        return bounds[ParamKey.OffPeg];
    }

    /**
     * @inheritdoc IParameterRegistry
     */
    function exchangeRateFeeParams() external view returns (Bounds memory) {
        return bounds[ParamKey.ExchangeRateFee];
    }

    /**
     * @inheritdoc IParameterRegistry
     */
    function decayPeriodParams() external view returns (Bounds memory) {
        return bounds[ParamKey.DecayPeriod];
    }

    /**
     * @inheritdoc IParameterRegistry
     */
    function rateChangeSkipPeriodParams() external view returns (Bounds memory) {
        return bounds[ParamKey.RateChangeSkipPeriod];
    }

    /**
     * @inheritdoc IParameterRegistry
     */
    function feeErrorMarginParams() external view returns (Bounds memory) {
        return bounds[ParamKey.FeeErrorMargin];
    }

    /**
     * @inheritdoc IParameterRegistry
     */
    function yieldErrorMarginParams() external view returns (Bounds memory) {
        return bounds[ParamKey.YieldErrorMargin];
    }

    /**
     * @inheritdoc IParameterRegistry
     */
    function minRampTimeParams() external view returns (Bounds memory) {
        return bounds[ParamKey.MinRampTime];
    }
}
