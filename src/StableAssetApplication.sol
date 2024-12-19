// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/Ipool.sol";
import "./StableAsset.sol";

error NotAllowedPool(address pool);
error EthAmount(uint256 requiredAmount, uint256 sentAmount);
error FailedEtherTransfer();

/**
 * @title StableAsset Application
 * @author Nuts Finance Developer
 * @notice The StableSwap Application provides an interface for users to interact with StableSwap pool contracts
 * @dev The StableSwap Application contract allows users to mint pool tokens, swap between different tokens, and redeem
 * pool tokens to underlying tokens.
 * This contract should never store assets.
 */
contract StableAssetApplication is UUPSUpgradeable, ReentrancyGuardUpgradeable, OwnableUpgradeable {
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /**
     * @dev Wrapped ETH address.
     */
    IWETH public wETH;

    /**
     * @dev Allowed pool address.
     */
    mapping(address => bool) public allowedPoolAddress;

    address[] public pools;

    /**
     * @dev This event is emitted when the pool is modified.
     * @param swap is the new value of the swap.
     * @param enabled pool enabled or disabled.
     */
    event PoolModified(address swap, bool enabled);

    /**
     * @dev Initializes the StableSwap Application contract.
     * @param _wETH Wrapped ETH address.
     */
    function initialize(IWETH _wETH) public initializer {
        require(address(_wETH) != address(0x0), "wETH not set");
        __ReentrancyGuard_init();
        wETH = _wETH;
        __Ownable_init();
    }

    /**
     * @dev Fallback function to receive ETH from WETH contract.
     */
    receive() external payable {
        assert(msg.sender == address(wETH)); // only accept ETH via fallback from the WETH contract
    }

    /**
     * @dev Mints new pool token and wrap ETH.
     * @param _swap Underlying stable swap address.
     * @param _amounts Unconverted token balances used to mint pool token.
     * @param _minMintAmount Minimum amount of pool token to mint.
     */
    function mint(
        StableAsset _swap,
        uint256[] calldata _amounts,
        uint256 _minMintAmount
    )
        external
        payable
        nonReentrant
    {
        address[] memory tokens = _swap.getTokens();
        address poolToken = address(_swap.poolToken());
        uint256 wETHIndex = findTokenIndex(tokens, address(wETH));
        if (_amounts[wETHIndex] != msg.value) {
            revert EthAmount(_amounts[wETHIndex], msg.value);
        }
        if (!allowedPoolAddress[address(_swap)]) {
            revert NotAllowedPool(address(_swap));
        }

        if (_amounts[wETHIndex] > 0) {
            wETH.deposit{ value: _amounts[wETHIndex] }();
        }
        for (uint256 i = 0; i < tokens.length; i++) {
            if (i != wETHIndex) {
                IERC20Upgradeable(tokens[i]).safeTransferFrom(msg.sender, address(this), _amounts[i]);
            }
            IERC20Upgradeable(tokens[i]).safeApprove(address(_swap), _amounts[i]);
        }
        uint256 mintAmount = _swap.mint(_amounts, _minMintAmount);
        IERC20Upgradeable(poolToken).safeTransfer(msg.sender, mintAmount);
    }

    /**
     * @dev Exchange between two underlying tokens with wrap/unwrap ETH.
     * @param _swap Underlying stable swap address.
     * @param _i Token index to swap in.
     * @param _j Token index to swap out.
     * @param _dx Unconverted amount of token _i to swap in.
     * @param _minDy Minimum token _j to swap out in converted balance.
     */
    function swap(
        StableAsset _swap,
        uint256 _i,
        uint256 _j,
        uint256 _dx,
        uint256 _minDy
    )
        external
        payable
        nonReentrant
    {
        address[] memory tokens = _swap.getTokens();
        uint256 wETHIndex = findTokenIndex(tokens, address(wETH));
        if (!allowedPoolAddress[address(_swap)]) {
            revert NotAllowedPool(address(_swap));
        }

        if (_i == wETHIndex) {
            if (_dx != msg.value) {
                revert EthAmount(_dx, msg.value);
            }

            wETH.deposit{ value: _dx }();
        } else {
            if (msg.value != 0) {
                revert EthAmount(0, msg.value);
            }
            IERC20Upgradeable(tokens[_i]).safeTransferFrom(msg.sender, address(this), _dx);
        }
        IERC20Upgradeable(tokens[_i]).safeApprove(address(_swap), _dx);
        uint256 swapAmount = _swap.swap(_i, _j, _dx, _minDy);

        if (_j == wETHIndex) {
            wETH.withdraw(swapAmount);
            (bool success,) = msg.sender.call{ value: swapAmount }("");
            if (!success) {
                revert FailedEtherTransfer();
            }
        } else {
            IERC20Upgradeable(tokens[_j]).safeTransfer(msg.sender, swapAmount);
        }
    }

    /**
     * @dev Redeems pool token to underlying tokens proportionally with unwrap ETH.
     * @param _swap Underlying stable swap address.
     * @param _amount Amount of pool token to redeem.
     * @param _minRedeemAmounts Minimum amount of underlying tokens to get.
     */
    function redeemProportion(
        StableAsset _swap,
        uint256 _amount,
        uint256[] calldata _minRedeemAmounts
    )
        external
        nonReentrant
    {
        address[] memory tokens = _swap.getTokens();
        address poolToken = address(_swap.poolToken());
        uint256 wETHIndex = findTokenIndex(tokens, address(wETH));
        if (!allowedPoolAddress[address(_swap)]) {
            revert NotAllowedPool(address(_swap));
        }
        IERC20Upgradeable(poolToken).safeApprove(address(_swap), _amount);
        IERC20Upgradeable(poolToken).safeTransferFrom(msg.sender, address(this), _amount);

        uint256[] memory amounts = _swap.redeemProportion(_amount, _minRedeemAmounts);

        for (uint256 i = 0; i < tokens.length; i++) {
            if (i == wETHIndex) {
                wETH.withdraw(amounts[i]);
                (bool success,) = msg.sender.call{ value: amounts[i] }("");
                if (!success) {
                    revert FailedEtherTransfer();
                }
            } else {
                IERC20Upgradeable(tokens[i]).safeTransfer(msg.sender, amounts[i]);
            }
        }
    }

    /**
     * @dev Redeem pool token to one specific underlying token.
     * @param _swap Underlying stable swap address.
     * @param _amount Amount of pool token to redeem.
     * @param _i Index of the token to redeem to.
     * @param _minRedeemAmount Minimum amount of the underlying token to redeem to.
     */
    function redeemSingle(
        StableAsset _swap,
        uint256 _amount,
        uint256 _i,
        uint256 _minRedeemAmount
    )
        external
        nonReentrant
    {
        address[] memory tokens = _swap.getTokens();
        address poolToken = address(_swap.poolToken());
        uint256 wETHIndex = findTokenIndex(tokens, address(wETH));
        if (!allowedPoolAddress[address(_swap)]) {
            revert NotAllowedPool(address(_swap));
        }
        IERC20Upgradeable(poolToken).safeApprove(address(_swap), _amount);
        IERC20Upgradeable(poolToken).safeTransferFrom(msg.sender, address(this), _amount);

        uint256 redeemAmount = _swap.redeemSingle(_amount, _i, _minRedeemAmount);

        if (_i == wETHIndex) {
            wETH.withdraw(redeemAmount);
            (bool success,) = msg.sender.call{ value: redeemAmount }("");
            if (!success) {
                revert FailedEtherTransfer();
            }
        } else {
            IERC20Upgradeable(tokens[_i]).safeTransfer(msg.sender, redeemAmount);
        }
    }

    /**
     * @dev Get amount of swap across pool.
     * @param _sourceSwap pool of the source token.
     * @param _destToken pool of the dest token.
     * @param _sourceToken source token.
     * @param _destToken dest token.
     * @param _amount Amount of source token to swap.
     * @return The Amount of dest token to get.
     * @return The amount of fee to charge.
     */
    function getSwapAmountCrossPool(
        StableAsset _sourceSwap,
        StableAsset _destSwap,
        address _sourceToken,
        address _destToken,
        uint256 _amount
    )
        public
        view
        returns (uint256, uint256)
    {
        address[] memory sourceTokens = _sourceSwap.getTokens();
        address[] memory destTokens = _destSwap.getTokens();
        if (!allowedPoolAddress[address(_sourceSwap)]) {
            revert NotAllowedPool(address(_sourceSwap));
        }
        if (!allowedPoolAddress[address(_destSwap)]) {
            revert NotAllowedPool(address(_destSwap));
        }
        uint256 sourceIndex = findTokenIndex(sourceTokens, _sourceToken);
        uint256 destIndex = findTokenIndex(destTokens, _destToken);
        uint256[] memory _mintAmounts = new uint256[](sourceTokens.length);
        _mintAmounts[sourceIndex] = _amount;
        (uint256 mintAmount, uint256 mintFee) = _sourceSwap.getMintAmount(_mintAmounts);
        (uint256 redeemAmount, uint256 redeemFee) = _destSwap.getRedeemSingleAmount(mintAmount, destIndex);
        return (redeemAmount, mintFee + redeemFee);
    }

    /**
     * @dev Swap tokens across pool.
     * @param _sourceSwap pool of the source token.
     * @param _destToken pool of the dest token.
     * @param _sourceToken source token.
     * @param _destToken dest token.
     * @param _amount Amount of source token to swap.
     * @param _minSwapAmount Minimum amount of the dest token to receive.
     */
    function swapCrossPool(
        StableAsset _sourceSwap,
        StableAsset _destSwap,
        address _sourceToken,
        address _destToken,
        uint256 _amount,
        uint256 _minSwapAmount
    )
        external
        nonReentrant
    {
        address[] memory sourceTokens = _sourceSwap.getTokens();
        address[] memory destTokens = _destSwap.getTokens();
        if (!allowedPoolAddress[address(_sourceSwap)]) {
            revert NotAllowedPool(address(_sourceSwap));
        }

        if (!allowedPoolAddress[address(_destSwap)]) {
            revert NotAllowedPool(address(_destSwap));
        }

        uint256 sourceIndex = findTokenIndex(sourceTokens, _sourceToken);
        uint256 destIndex = findTokenIndex(destTokens, _destToken);

        IERC20Upgradeable(_sourceToken).safeTransferFrom(msg.sender, address(this), _amount);
        IERC20Upgradeable(_sourceToken).safeApprove(address(_sourceSwap), _amount);

        uint256[] memory _mintAmounts = new uint256[](sourceTokens.length);
        _mintAmounts[sourceIndex] = _amount;
        uint256 mintAmount = _sourceSwap.mint(_mintAmounts, 0);
        IERC20Upgradeable(address(_destSwap.poolToken())).safeApprove(address(_destSwap), mintAmount);
        uint256 redeemAmount = _destSwap.redeemSingle(mintAmount, destIndex, _minSwapAmount);

        IERC20Upgradeable(_destToken).safeTransfer(msg.sender, redeemAmount);
    }

    /**
     * @dev Find token index in the array.
     * @param tokens Array of tokens.
     * @param token Token to find.
     * @return Index of the token.
     */
    function findTokenIndex(address[] memory tokens, address token) internal pure returns (uint256) {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == token) {
                return i;
            }
        }
        revert("token not found");
    }

    /**
     * @dev Enable/Disable the pool address.
     * @param _swap The swap address.
     * @param _enabled Enable or disable swap.
     */
    function updatePool(address _swap, bool _enabled) external onlyOwner {
        if (_enabled && !allowedPoolAddress[_swap]) {
            pools.push(_swap);
        } else {
            address[] memory updatedPools;
            uint256 index = 0;
            for (uint256 i = 0; i < pools.length; i++) {
                if (pools[i] != _swap) {
                    updatedPools[index] = pools[i];
                    index++;
                }
            }
            pools = updatedPools;
        }
        allowedPoolAddress[_swap] = _enabled;

        emit PoolModified(_swap, _enabled);
    }

    /**
     * @notice This function allows to rebase LPToken by increasing his total supply
     * from all stableSwap pools by the staking rewards and the swap fee.
     */
    function rebase() external returns (uint256 _amount) {
        for (uint256 i = 0; i < pools.length; i++) {
            address _pool = pools[i];
            if (allowedPoolAddress[_pool]) {
                _amount += Ipool(_pool).rebase();
            }
        }
    }

    /**
     * @dev Upgrade the contract.
     * @param newImplementation New implementation address.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner { }
}
