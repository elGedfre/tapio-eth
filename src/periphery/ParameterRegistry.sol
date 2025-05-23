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
    /// @notice SPA this registry is for
    SelfPeggingAsset public immutable spa;

    mapping(ParamKey => Bounds) public bounds;

    constructor(address _governor, address _spa) Ownable(_governor) {
        require(_spa != address(0), ZeroAddress());

        spa = SelfPeggingAsset(_spa);
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
}
