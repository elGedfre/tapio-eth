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

    error ZeroAddress();
    error OutOfBounds();
    error DeltaTooBig();
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

        uint256 curA = rampAController.getA();
        if (curA <= 2) {
            uint256 maxMultiplier = 11 - curA; // 10 for initialA=1, 9 for initialA=2
            if (newA > curA * maxMultiplier) revert OutOfBounds();
        } else {
            if (aParams.maxDecreasePct == 0 && aParams.maxIncreasePct == 0) revert RelativeRangeNotSet();
            checkRange(newA, curA, aParams);
        }

        require(newA <= aParams.max, OutOfBounds());

        rampAController.rampA(newA, endTime);
    }

    /**
     * @inheritdoc IKeeper
     */
    function setSwapFee(uint256 newFee) external override {
        require(hasRole(GOVERNOR_ROLE, msg.sender) || hasRole(COUNCIL_ROLE, msg.sender), UnauthorizedAccount());
        IParameterRegistry.Bounds memory swapFeeParams = registry.swapFeeParams();

        uint256 cur = spa.swapFee();
        checkRange(newFee, cur, swapFeeParams);

        spa.setSwapFee(newFee);
    }

    /**
     * @inheritdoc IKeeper
     */
    function setMintFee(uint256 newFee) external override {
        require(hasRole(GOVERNOR_ROLE, msg.sender) || hasRole(COUNCIL_ROLE, msg.sender), UnauthorizedAccount());
        IParameterRegistry.Bounds memory mintFeeParams = registry.mintFeeParams();

        uint256 cur = spa.mintFee();
        checkRange(newFee, cur, mintFeeParams);

        spa.setMintFee(newFee);
    }

    /**
     * @inheritdoc IKeeper
     */
    function setRedeemFee(uint256 newFee) external override {
        require(hasRole(GOVERNOR_ROLE, msg.sender) || hasRole(COUNCIL_ROLE, msg.sender), UnauthorizedAccount());
        IParameterRegistry.Bounds memory redeemFeeParams = registry.redeemFeeParams();

        uint256 cur = spa.redeemFee();

        checkRange(newFee, cur, redeemFeeParams);
        spa.setRedeemFee(newFee);
    }

    /**
     * @inheritdoc IKeeper
     */
    function cancelRamp() external override {
        require(hasRole(GUARDIAN_ROLE, msg.sender) || hasRole(COUNCIL_ROLE, msg.sender), UnauthorizedAccount());
        rampAController.stopRamp();
    }

    /**
     * @inheritdoc IKeeper
     */
    function grantGovernorRole(address _governor) external override onlyRole(COUNCIL_ROLE) {
        _grantRole(GOVERNOR_ROLE, _governor);
    }

    /**
     * @inheritdoc IKeeper
     */
    function revokeGovernorRole(address _governor) external override {
        require(hasRole(GOVERNOR_ROLE, msg.sender) || hasRole(COUNCIL_ROLE, msg.sender), UnauthorizedAccount());
        _revokeRole(GOVERNOR_ROLE, _governor);
    }

    /**
     * @inheritdoc IKeeper
     */
    function grantCuratorRole(address _curator) external override {
        require(hasRole(GOVERNOR_ROLE, msg.sender) || hasRole(COUNCIL_ROLE, msg.sender), UnauthorizedAccount());
        _grantRole(CURATOR_ROLE, _curator);
    }

    /**
     * @inheritdoc IKeeper
     */
    function revokeCuratorRole(address _curator) external override {
        require(hasRole(GOVERNOR_ROLE, msg.sender) || hasRole(COUNCIL_ROLE, msg.sender), UnauthorizedAccount());
        _revokeRole(CURATOR_ROLE, _curator);
    }

    /**
     * @inheritdoc IKeeper
     */
    function grantGuardianRole(address _guardian) external override {
        require(hasRole(GOVERNOR_ROLE, msg.sender) || hasRole(COUNCIL_ROLE, msg.sender), UnauthorizedAccount());
        _grantRole(GUARDIAN_ROLE, _guardian);
    }

    /**
     * @inheritdoc IKeeper
     */
    function revokeGuardianRole(address _guardian) external override {
        require(hasRole(GOVERNOR_ROLE, msg.sender) || hasRole(COUNCIL_ROLE, msg.sender), UnauthorizedAccount());
        _revokeRole(GUARDIAN_ROLE, _guardian);
    }

    /**
     * @inheritdoc IKeeper
     */
    function setOffPegFeeMultiplier(uint256 newMultiplier) external override {
        require(hasRole(GOVERNOR_ROLE, msg.sender) || hasRole(COUNCIL_ROLE, msg.sender), UnauthorizedAccount());
        IParameterRegistry.Bounds memory offPegParams = registry.offPegParams();

        uint256 cur = spa.offPegFeeMultiplier();
        checkRange(newMultiplier, cur, offPegParams);

        spa.setOffPegFeeMultiplier(newMultiplier);
    }

    /**
     * @inheritdoc IKeeper
     */
    function setExchangeRateFeeFactor(uint256 newFeeFactor) external override {
        require(hasRole(GOVERNOR_ROLE, msg.sender) || hasRole(COUNCIL_ROLE, msg.sender), UnauthorizedAccount());
        IParameterRegistry.Bounds memory exchangeRateFeeParams = registry.exchangeRateFeeParams();

        uint256 cur = spa.exchangeRateFeeFactor();
        checkRange(newFeeFactor, cur, exchangeRateFeeParams);

        spa.setExchangeRateFeeFactor(newFeeFactor);
    }

    /**
     * @inheritdoc IKeeper
     */
    function setDecayPeriod(uint256 newDecayPeriod) external override {
        require(hasRole(GOVERNOR_ROLE, msg.sender) || hasRole(COUNCIL_ROLE, msg.sender), UnauthorizedAccount());
        IParameterRegistry.Bounds memory decayPeriodParams = registry.decayPeriodParams();

        uint256 cur = spa.decayPeriod();
        checkRange(newDecayPeriod, cur, decayPeriodParams);

        spa.setDecayPeriod(newDecayPeriod);
    }

    /**
     * @inheritdoc IKeeper
     */
    function setRateChangeSkipPeriod(uint256 newSkipPeriod) external override {
        require(hasRole(GOVERNOR_ROLE, msg.sender) || hasRole(COUNCIL_ROLE, msg.sender), UnauthorizedAccount());
        IParameterRegistry.Bounds memory rateChangeSkipPeriodParams = registry.rateChangeSkipPeriodParams();

        uint256 cur = spa.rateChangeSkipPeriod();
        checkRange(newSkipPeriod, cur, rateChangeSkipPeriodParams);

        spa.setRateChangeSkipPeriod(newSkipPeriod);
    }

    /**
     * @inheritdoc IKeeper
     */
    function updateFeeErrorMargin(uint256 newMargin) external override {
        require(hasRole(GOVERNOR_ROLE, msg.sender) || hasRole(COUNCIL_ROLE, msg.sender), UnauthorizedAccount());
        IParameterRegistry.Bounds memory feeErrorMarginParams = registry.feeErrorMarginParams();

        uint256 cur = spa.feeErrorMargin();
        checkRange(newMargin, cur, feeErrorMarginParams);

        spa.updateFeeErrorMargin(newMargin);
    }

    /**
     * @inheritdoc IKeeper
     */
    function updateYieldErrorMargin(uint256 newMargin) external override {
        require(hasRole(GOVERNOR_ROLE, msg.sender) || hasRole(COUNCIL_ROLE, msg.sender), UnauthorizedAccount());
        IParameterRegistry.Bounds memory yieldErrorMarginParams = registry.yieldErrorMarginParams();

        uint256 cur = spa.yieldErrorMargin();
        checkRange(newMargin, cur, yieldErrorMarginParams);

        spa.updateYieldErrorMargin(newMargin);
    }

    /**
     * @inheritdoc IKeeper
     */
    function distributeLoss() external override {
        require(hasRole(GOVERNOR_ROLE, msg.sender) || hasRole(COUNCIL_ROLE, msg.sender), UnauthorizedAccount());
        spa.distributeLoss();
    }

    /**
     * @inheritdoc IKeeper
     */
    function pause() external override onlyRole(GUARDIAN_ROLE) {
        spa.pause();
    }

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

    function checkRange(
        uint256 newValue,
        uint256 currentValue,
        IParameterRegistry.Bounds memory bounds
    )
        internal
        pure
    {
        if (newValue < currentValue) {
            // decreasing
            uint256 decreasePct = ((currentValue - newValue) * 1e6) / currentValue;
            require(decreasePct <= bounds.maxDecreasePct, DeltaTooBig());
        } else if (newValue > currentValue) {
            // increasing
            uint256 increasePct = ((newValue - currentValue) * 1e6) / currentValue;
            require(increasePct <= bounds.maxIncreasePct, DeltaTooBig());
        }

        require(newValue <= bounds.max, OutOfBounds());
    }
}
