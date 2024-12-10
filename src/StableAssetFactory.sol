// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import "./StableAsset.sol";
import "./TapETH.sol";
import "./WTapETH.sol";
import "./misc/ConstantExchangeRateProvider.sol";
import "./misc/ERC4626ExchangeRate.sol";
import "./interfaces/IExchangeRateProvider.sol";

/**
 * @title StableAsset Application
 * @author Nuts Finance Developer
 * @notice The StableSwap Application provides an interface for users to interact with StableSwap pool contracts
 * @dev The StableSwap Application contract allows users to mint pool tokens, swap between different tokens, and redeem
 * pool tokens to underlying tokens.
 * This contract should never store assets.
 */
contract StableAssetFactory is Initializable, ReentrancyGuardUpgradeable {
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct CreatePoolArgument {
        address tokenA;
        address tokenB;
        uint256 precisionA;
        uint256 precisionB;
    }

    /**
     * @dev This is the account that has governance control over the protocol.
     */
    address public governance;

    /**
     * @dev Pending governance address,
     */
    address public pendingGovernance;

    /**
     * @dev Default mint fee for the pool.
     */
    uint256 public mintFee;

    /**
     * @dev Default swap fee for the pool.
     */
    uint256 public swapFee;

    /**
     * @dev Default redeem fee for the pool.
     */
    uint256 public redeemFee;

    /**
     * @dev Default A parameter for the pool.
     */
    uint256 public A;

    /**
     * @dev Beacon for the StableAsset implementation.
     */
    address public stableAssetBeacon;

    /**
     * @dev Beacon for the TapETH implementation.
     */
    address public tapETHBeacon;

    /**
     * @dev Beacon for the TapETH implementation.
     */
    address public wtapETHBeacon;

    /**
     * @dev Constant exchange rate provider.
     */
    ConstantExchangeRateProvider public constantExchangeRateProvider;

    /**
     * @dev This event is emitted when the governance is modified.
     * @param governance is the new value of the governance.
     */
    event GovernanceModified(address governance);

    /**
     * @dev This event is emitted when the governance is modified.
     * @param governance is the new value of the governance.
     */
    event GovernanceProposed(address governance);

    /**
     * @dev This event is emitted when a new pool is created.
     * @param poolToken is the pool token created.
     */
    event PoolCreated(address poolToken, address stableAsset);

    /**
     * @dev This event is emitted when the mint fee is updated.
     * @param mintFee is the new value of the mint fee.
     */
    event MintFeeModified(uint256 mintFee);

    /**
     * @dev This event is emitted when the swap fee is updated.
     * @param swapFee is the new value of the swap fee.
     */
    event SwapFeeModified(uint256 swapFee);

    /**
     * @dev This event is emitted when the redeem fee is updated.
     * @param redeemFee is the new value of the redeem fee.
     */
    event RedeemFeeModified(uint256 redeemFee);

    /**
     * @dev This event is emitted when the A parameter is updated.
     * @param A is the new value of the A parameter.
     */
    event AModified(uint256 A);

    /**
     * @dev Initializes the StableSwap Application contract.
     */
    function initialize(address _governance) public initializer {
        __ReentrancyGuard_init();
        governance = _governance;

        address stableAssetImplentation = address(new StableAsset());
        address tapETHImplentation = address(new TapETH());

        UpgradeableBeacon beacon = new UpgradeableBeacon(stableAssetImplentation);
        beacon.transferOwnership(_governance);
        stableAssetBeacon = address(beacon);

        beacon = new UpgradeableBeacon(tapETHImplentation);
        beacon.transferOwnership(_governance);
        tapETHBeacon = address(beacon);

        beacon = new UpgradeableBeacon(address(new WtapETH()));
        beacon.transferOwnership(_governance);
        wtapETHBeacon = address(beacon);

        constantExchangeRateProvider = new ConstantExchangeRateProvider();
    }

    /**
     * @dev Propose the govenance address.
     * @param _governance Address of the new governance.
     */
    function proposeGovernance(address _governance) public {
        require(msg.sender == governance, "not governance");
        pendingGovernance = _governance;
        emit GovernanceProposed(_governance);
    }

    /**
     * @dev Accept the govenance address.
     */
    function acceptGovernance() public {
        require(msg.sender == pendingGovernance, "not pending governance");
        governance = pendingGovernance;
        pendingGovernance = address(0);
        emit GovernanceModified(governance);
    }

    function createPoolConstantExchangeRate(CreatePoolArgument calldata argument) external {
        createPool(argument, constantExchangeRateProvider);
    }

    function createPoolERC4626(CreatePoolArgument calldata argument) external {
        ERC4626ExchangeRate exchangeRate = new ERC4626ExchangeRate(IERC4626(argument.tokenB));
        createPool(argument, exchangeRate);
    }

    modifier onlyGovernance() {
        require(msg.sender == governance, "not governance");
        _;
    }

    function setMintFee(uint256 _mintFee) external onlyGovernance {
        mintFee = _mintFee;
        emit MintFeeModified(_mintFee);
    }

    function setSwapFee(uint256 _swapFee) external onlyGovernance {
        swapFee = _swapFee;
        emit SwapFeeModified(_swapFee);
    }

    function setRedeemFee(uint256 _redeemFee) external onlyGovernance {
        redeemFee = _redeemFee;
        emit RedeemFeeModified(_redeemFee);
    }

    function setA(uint256 _A) external onlyGovernance {
        A = _A;
        emit AModified(_A);
    }

    function createPool(CreatePoolArgument memory argument, IExchangeRateProvider exchangeRateProvider) internal {
        string memory symbolA = ERC20Upgradeable(argument.tokenA).symbol();
        string memory symbolB = ERC20Upgradeable(argument.tokenB).symbol();
        string memory symbol = string.concat(string.concat(string.concat("SA-", symbolA), "-"), symbolB);
        string memory name = string.concat(string.concat(string.concat("Stable Asset ", symbolA), " "), symbolB);
        bytes memory tapETHInit = abi.encodeCall(TapETH.initialize, (address(this), name, symbol));
        BeaconProxy tapETHProxy =
            new BeaconProxy(tapETHBeacon, tapETHInit);

        address[] memory tokens = new address[](2);
        uint256[] memory precisions = new uint256[](2);
        uint256[] memory fees = new uint256[](3);
        tokens[0] = argument.tokenA;
        tokens[1] = argument.tokenB;
        precisions[0] = argument.precisionA;
        precisions[1] = argument.precisionB;
        fees[0] = mintFee;
        fees[1] = swapFee;
        fees[2] = redeemFee;
        uint256 exchangeRateTokenIndex = 1;

        bytes memory stableAssetInit = abi.encodeCall(
            StableAsset.initialize,
            (tokens, precisions, fees, TapETH(address(tapETHProxy)), A, exchangeRateProvider, exchangeRateTokenIndex)
        );
        BeaconProxy stableAssetProxy =
            new BeaconProxy(stableAssetBeacon, stableAssetInit);
        StableAsset stableAsset = StableAsset(address(stableAssetProxy));
        TapETH tapETH = TapETH(address(tapETHProxy));

        stableAsset.proposeGovernance(msg.sender);
        tapETH.addPool(address(stableAsset));
        tapETH.proposeGovernance(msg.sender);
        emit PoolCreated(address(tapETHProxy), address(stableAssetProxy));
    }
}
