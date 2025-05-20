// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IParameterRegistry.sol";
import "../SelfPeggingAsset.sol";

/**
 * @title ParameterRegistry
 * @notice Stores hard caps and per-transaction relative ranges that bound keeper operations.
 * @dev Immutable by design. Only the Governor (admin role) can modify values.
 * Each SPA has its own ParameterRegistry
 */
contract ParameterRegistry is IParameterRegistry, Ownable {
    IParameterRegistry.AbsoluteCaps public absoluteCaps;
    IParameterRegistry.RelativeRanges public relativeRanges;

    /// @notice SPA this registry is for
    SelfPeggingAsset public immutable spa;

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

    constructor(
        address _governor,
        address _spa,
        IParameterRegistry.AbsoluteCaps memory _initialAbsCaps,
        IParameterRegistry.RelativeRanges memory _initialRelRanges
    )
        Ownable(_governor)
    {
        require(_spa != address(0), ZeroAddress());

        spa = SelfPeggingAsset(_spa);
        absoluteCaps = _initialAbsCaps;
        relativeRanges = _initialRelRanges;

        emit AbsoluteCapsUpdated(_governor, _spa, absoluteCaps, _initialAbsCaps);
        emit RelativeRangesUpdated(_governor, _spa, relativeRanges, _initialRelRanges);
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
