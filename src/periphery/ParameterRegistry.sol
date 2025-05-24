// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../interfaces/IParameterRegistry.sol";
import "../SelfPeggingAsset.sol";

/**
 * @title ParameterRegistry
 * @notice Stores hard caps and per-transaction relative ranges that bound keeper operations.
 * @dev Only the Governor (admin role) can modify values.
 * Each SPA has its own ParameterRegistry
 */
contract ParameterRegistry is IParameterRegistry, OwnableUpgradeable {
    /// @notice SPA this registry is connected
    SelfPeggingAsset public spa;

    mapping(ParamKey => Bounds) public bounds;

    function initialize(address _governor, address _spa) public initializer {
        require(_spa != address(0), ZeroAddress());

        __Ownable_init(_governor);

        spa = SelfPeggingAsset(_spa);

        // set default values for A boundry
        bounds[ParamKey.A] = Bounds({
            max: 1_000_000, // 1M like in Curve
            maxDecreasePct: 900_000, // -90%
            maxIncreasePct: 9_000_000 // +900%
         });
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
