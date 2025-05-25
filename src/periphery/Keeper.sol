// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "../interfaces/IRampAController.sol";
import "../interfaces/IParameterRegistry.sol";
import "../interfaces/IKeeper.sol";
import "../SelfPeggingAsset.sol";

/**
 * @title Keeper
 * @notice Follows Tapio Governance model
 * @notice Fast-path executor that lets curators adjust parameters within bounds enforced by ParameterRegistry
 * @dev UUPS upgradeable. Governor is admin, curator and guardian are roles.
 */
contract Keeper is AccessControlUpgradeable, IKeeper {
    bytes32 public constant COUNCIL_ROLE = keccak256("COUNCIL_ROLE");
    bytes32 public constant CURATOR_ROLE = keccak256("CURATOR_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant PROTOCOL_OWNER_ROLE = keccak256("PROTOCOL_OWNER_ROLE");

    IParameterRegistry private registry;
    IRampAController private rampAController;
    SelfPeggingAsset private spa;

    event ACoeffManaged(address indexed caller, uint256 newA);
    event SwapFeeManaged(address indexed caller, uint256 newFee);

    error ZeroAddress();
    error FeeOutOfBounds();
    error FeeDeltaTooBig();
    error RelativeRangeNotSet();
    error UnauthorizedAccount();

    /**
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _protocolOwner,
        address _governor,
        address _curator,
        address _guardian,
        address _council,
        IParameterRegistry _registry,
        IRampAController _rampAController,
        SelfPeggingAsset _spa
    )
        public
        initializer
    {
        require(_governor != address(0), ZeroAddress());
        require(_curator != address(0), ZeroAddress());
        require(_guardian != address(0), ZeroAddress());
        require(address(_registry) != address(0), ZeroAddress());
        require(address(_rampAController) != address(0), ZeroAddress());
        require(address(_spa) != address(0), ZeroAddress());

        __AccessControl_init();
        __UUPSUpgradeable_init();

        registry = _registry;
        rampAController = _rampAController;
        spa = _spa;

        // Role assignment
        _grantRole(GOVERNOR_ROLE, _governor);
        _grantRole(CURATOR_ROLE, _curator);
        _grantRole(GUARDIAN_ROLE, _guardian);
        _grantRole(COUNCIL_ROLE, _council);
        _grantRole(PROTOCOL_OWNER_ROLE, _protocolOwner);
    }

    /**
     * @inheritdoc IKeeper
     */
    function rampA(uint256 newA, uint256 endTime) external override {
        require(
            hasRole(GOVERNOR_ROLE, msg.sender) || hasRole(COUNCIL_ROLE, msg.sender) || hasRole(CURATOR_ROLE, msg.sender),
            UnauthorizedAccount()
        );
        IParameterRegistry.Bounds memory aParams = registry.aParams();

        // only if governor has defined ranges
        if (aParams.maxDecreasePct == 0 && aParams.maxIncreasePct == 0) revert RelativeRangeNotSet();

        uint256 curA = rampAController.getA();

        // check if within allowed relative bounds
        if (newA < curA) {
            // decreasing
            uint256 decreasePct = ((curA - newA) * 1e6) / curA;
            require(decreasePct <= aParams.maxDecreasePct, FeeDeltaTooBig());
        } else if (newA > curA) {
            // increasing
            uint256 increasePct = ((newA - curA) * 1e6) / curA;
            require(increasePct <= aParams.maxIncreasePct, FeeDeltaTooBig());
        } else {
            // no change
            return;
        }

        require(newA <= aParams.max, FeeOutOfBounds());

        rampAController.rampA(newA, endTime);
        emit ACoeffManaged(msg.sender, newA);
    }

    /**
     * @inheritdoc IKeeper
     */
    function setSwapFee(uint256 newFee) external override {
        require(
            hasRole(GOVERNOR_ROLE, msg.sender) || hasRole(COUNCIL_ROLE, msg.sender),
            UnauthorizedAccount()
        );
        IParameterRegistry.Bounds memory swapFeeParams = registry.swapFeeParams();

        uint256 cur = spa.swapFee();
        if (newFee < cur) {
            // decreasing
            uint256 decreasePct = ((cur - newFee) * 1e6) / cur;
            require(decreasePct <= swapFeeParams.maxDecreasePct, FeeDeltaTooBig());
        } else if (newFee > cur) {
            // increasing
            uint256 increasePct = ((newFee - cur) * 1e6) / cur;
            require(increasePct <= swapFeeParams.maxIncreasePct, FeeDeltaTooBig());
        } else {
            // no change
            return;
        }
        require(newFee <= swapFeeParams.max, FeeOutOfBounds());

        spa.setSwapFee(newFee);
        emit SwapFeeManaged(msg.sender, newFee);
    }

    /**
     * @inheritdoc IKeeper
     */
    function cancelRamp() external override onlyRole(GUARDIAN_ROLE) {
        require(
            hasRole(GUARDIAN_ROLE, msg.sender) || hasRole(COUNCIL_ROLE, msg.sender),
            UnauthorizedAccount()
        );
        rampAController.stopRamp();
    }

    /**
     * @inheritdoc IKeeper
     */
    function setGovernor(address _governor) external override onlyRole(GOVERNOR_ROLE) {
        require(
            hasRole(PROTOCOL_OWNER_ROLE, msg.sender) || hasRole(COUNCIL_ROLE, msg.sender),
            UnauthorizedAccount()
        );
        _grantRole(GOVERNOR_ROLE, _governor);
    }

    // TODO: add pause logic

    /**
     * @inheritdoc IKeeper
     */
    function getRegistry() external view override returns (IParameterRegistry) {
        return registry;
    }

    /**
     * @inheritdoc IKeeper
     */
    function getRampAController() external view override returns (IRampAController) {
        return rampAController;
    }

    /**
     * @inheritdoc IKeeper
     */
    function getSpa() external view override returns (SelfPeggingAsset) {
        return spa;
    }

    /**
     * @dev Internal helper to update swap fee within bounds
     * @param newFee The new swap fee to set
     */
    function _boundedSwapFeeUpdate(uint256 newFee) internal { }
}
