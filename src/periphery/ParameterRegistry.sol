// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../interfaces/IParameterRegistry.sol";
import "../SelfPeggingAsset.sol";

/**
 * @title ParameterRegistry
 * @notice Stores hard caps and per-transaction relative ranges that bound keeper operations.
 * @dev Immutable by design. Only the Governor (admin role) can modify values.
 * Each SPA has its own ParameterRegistry
 */
contract ParameterRegistry is IParameterRegistry, OwnableUpgradeable {
    IParameterRegistry.AbsoluteCaps public absoluteCaps;
    IParameterRegistry.RelativeRanges public relativeRanges;

    /// @notice SPA this registry is for
    SelfPeggingAsset public spa;

    event AbsoluteCapsUpdated(
        address indexed caller,
        address indexed spa,
        IParameterRegistry.AbsoluteCaps oldCaps,
        IParameterRegistry.AbsoluteCaps newCaps
    );
    event RelativeRangesUpdated(
        address indexed caller,
        address indexed spa,
        IParameterRegistry.RelativeRanges oldRanges,
        IParameterRegistry.RelativeRanges newRanges
    );

    error ZeroAddress();

    function initialize(address _governor, address _spa) public initializer {
        require(_spa != address(0), ZeroAddress());

        __Ownable_init(_governor);

        spa = SelfPeggingAsset(_spa);

        absoluteCaps.aMax = 1_000_000; // 1M like in Curve
        relativeRanges.aMaxDecreasePct = 900_000; // -90%
        relativeRanges.aMaxIncreasePct = 9_000_000; // +900%
    }

    /**
     * @inheritdoc IParameterRegistry
     */
    function setAbsoluteCaps(IParameterRegistry.AbsoluteCaps calldata _absCaps) external override onlyOwner {
        emit AbsoluteCapsUpdated(msg.sender, address(spa), absoluteCaps, _absCaps);
        absoluteCaps = _absCaps;
    }

    /**
     * @inheritdoc IParameterRegistry
     */
    function setRelativeRanges(IParameterRegistry.RelativeRanges calldata _relRanges) external override onlyOwner {
        emit RelativeRangesUpdated(msg.sender, address(spa), relativeRanges, _relRanges);
        relativeRanges = _relRanges;
    }

    /**
     * @inheritdoc IParameterRegistry
     */
    function absCaps() external view override returns (IParameterRegistry.AbsoluteCaps memory) {
        return absoluteCaps;
    }

    /**
     * @inheritdoc IParameterRegistry
     */
    function relRanges() external view override returns (IParameterRegistry.RelativeRanges memory) {
        return relativeRanges;
    }
}
