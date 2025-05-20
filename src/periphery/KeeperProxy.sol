// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../interfaces/IRampAController.sol";
import "../interfaces/IParameterRegistry.sol";
import "../interfaces/IKeeperProxy.sol";
import "../SelfPeggingAsset.sol";

/**
 * @title KeeperProxy
 * @notice Follows Tapio Governance model
 * @notice Fast-path executor that lets curators adjust parameters within bounds enforced by ParameterRegistry
 * @dev UUPS upgradeable. Governor is admin, curator and guardian are roles.
 */
contract KeeperProxy is AccessControlUpgradeable, UUPSUpgradeable, IKeeperProxy {
    bytes32 public constant CURATOR_ROLE = keccak256("CURATOR_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    // Protocol Owner holds DEFAULT_ADMIN_ROLE (admin key)

    IParameterRegistry private registry;
    IRampAController private rampAController;
    SelfPeggingAsset private spa;

    event ACoeffManaged(address indexed caller, uint256 newA);
    event SwapFeeManaged(address indexed caller, uint256 newFee);

    error ZeroAddress();
    error FeeOutOfBounds();
    error FeeDeltaTooBig();
    error RelativeRangeNotSet();

    /**
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _governor,
        address _curator,
        address _guardian,
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
    }

    /**
     * @inheritdoc IKeeperProxy
     */
    function rampA(uint256 newA, uint256 endTime) external override onlyRole(CURATOR_ROLE) {
        IParameterRegistry.AbsoluteCaps memory C = registry.absCaps();
        IParameterRegistry.RelativeRanges memory R = registry.relRanges();

        // only if governor has defined ranges
        if (R.aMaxDecreasePct == 0 && R.aMaxIncreasePct == 0) revert RelativeRangeNotSet();

        uint256 curA = rampAController.getA();

        // check if within allowed relative bounds
        if (newA < curA) {
            // decreasing
            uint256 decreasePct = ((curA - newA) * 1e6) / curA;
            require(decreasePct <= R.aMaxDecreasePct, FeeDeltaTooBig());
        } else if (newA > curA) {
            // increasing
            uint256 increasePct = ((newA - curA) * 1e6) / curA;
            require(increasePct <= R.aMaxIncreasePct, FeeDeltaTooBig());
        } else {
            // no change
            return;
        }

        require(newA <= C.aMax, FeeOutOfBounds());

        rampAController.rampA(newA, endTime);
        emit ACoeffManaged(msg.sender, newA);
    }

    /**
     * @inheritdoc IKeeperProxy
     */
    function setSwapFee(uint256 newFee) external override onlyRole(GOVERNOR_ROLE) {
        IParameterRegistry.AbsoluteCaps memory C = registry.absCaps();
        IParameterRegistry.RelativeRanges memory R = registry.relRanges();

        uint256 cur = spa.swapFee();
        if (newFee < cur) {
            // decreasing
            uint256 decreasePct = ((cur - newFee) * 1e6) / cur;
            require(decreasePct <= R.swapFeeMaxDecreasePct, FeeDeltaTooBig());
        } else if (newFee > cur) {
            // increasing
            uint256 increasePct = ((newFee - cur) * 1e6) / cur;
            require(increasePct <= R.swapFeeMaxIncreasePct, FeeDeltaTooBig());
        } else {
            // no change
            return;
        }

        require(newFee <= C.swapFeeMax, FeeOutOfBounds());

        spa.setSwapFee(newFee);
        emit SwapFeeManaged(msg.sender, newFee);
    }

    /**
     * @inheritdoc IKeeperProxy
     */
    function cancelRamp() external override onlyRole(GUARDIAN_ROLE) {
        rampAController.stopRamp();
    }

    // TODO: add pause logic

    /**
     * @inheritdoc IKeeperProxy
     */
    function getRegistry() external view override returns (IParameterRegistry) {
        return registry;
    }

    /**
     * @inheritdoc IKeeperProxy
     */
    function getRampAController() external view override returns (IRampAController) {
        return rampAController;
    }

    /**
     * @inheritdoc IKeeperProxy
     */
    function getSpa() external view override returns (SelfPeggingAsset) {
        return spa;
    }

    /**
     * @notice Allows Governor to grant the Curator role to a new account
     * @param account Address to receive Curator permissions
     */
    function grantCuratorRole(address account) external onlyRole(GOVERNOR_ROLE) {
        _grantRole(CURATOR_ROLE, account);
    }

    /**
     * @notice Allows Governor to revoke the Curator role from an account
     * @param account Address to lose Curator permissions
     */
    function revokeCuratorRole(address account) external onlyRole(GOVERNOR_ROLE) {
        _revokeRole(CURATOR_ROLE, account);
    }

    /**
     * @notice Allows Governor to grant the Guardian role to a new account
     * @param account Address to receive Guardian permissions
     */
    function grantGuardianRole(address account) external onlyRole(GOVERNOR_ROLE) {
        _grantRole(GUARDIAN_ROLE, account);
    }

    /**
     * @notice Allows Governor to revoke the Guardian role from an account
     * @param account Address to lose Guardian permissions
     */
    function revokeGuardianRole(address account) external onlyRole(GOVERNOR_ROLE) {
        _revokeRole(GUARDIAN_ROLE, account);
    }

    /**
     * @dev Internal helper to update swap fee within bounds
     * @param newFee The new swap fee to set
     */
    function _boundedSwapFeeUpdate(uint256 newFee) internal { }

    /**
     * @dev Overrides the OpenZeppelin UUPS implementation
     */
    function _authorizeUpgrade(address) internal view override onlyRole(DEFAULT_ADMIN_ROLE) { }
}
