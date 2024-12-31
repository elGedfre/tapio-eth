// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/ILPToken.sol";

/**
 * @title LPToken token wrapper with static balances.
 * @dev It's an ERC20 token that represents the account's share of the total
 * supply of lpToken tokens. WLPToken token's balance only changes on transfers,
 * unlike lpToken that is also changed when staking rewards and swap fee are generated.
 * It's a "power user" token for DeFi protocols which don't
 * support rebasable tokens.
 * The contract is also a trustless wrapper that accepts lpToken tokens and mints
 * wlpToken in return. Then the user unwraps, the contract burns user's wlpToken
 * and sends user locked lpToken in return.
 * The contract provides the staking shortcut: user can send ETH with regular
 * transfer and get wlpToken in return. The contract will send ETH to Tapio
 * staking it and wrapping the received lpToken.
 *
 */
contract WLPToken is ERC4626Upgradeable {
    ILPToken public lpToken;

    error ZeroAmount();
    error InsufficientAllowance();

    function initialize(ILPToken _lpToken) public initializer {
        __ERC20_init("Wrapped LP Token", "wlpToken");
        __ERC4626_init(IERC20(address(_lpToken)));
        lpToken = _lpToken;
    }

    /**
     * @dev Returns the total assets managed by the vault.
     * Overrides the virtual totalAssets method of ERC4626.
     * @return The total amount of lpToken held by the vault.
     */
    function totalAssets() public view override returns (uint256) {
        return lpToken.balanceOf(address(this));
    }

    /**
     * @dev Converts an amount of lpToken to the equivalent amount of shares.
     * @param assets Amount of lpToken.
     * @return The equivalent shares.
     */
    function convertToShares(uint256 assets) public view override returns (uint256) {
        return lpToken.getSharesByPeggedToken(assets);
    }

    /**
     * @dev Converts an amount of shares to the equivalent amount of lpToken.
     * @param shares Amount of shares.
     * @return The equivalent lpToken.
     */
    function convertToAssets(uint256 shares) public view override returns (uint256) {
        return lpToken.getPeggedTokenByShares(shares);
    }

    /**
     * @dev Deposits lpToken into the vault in exchange for shares.
     * @param assets Amount of lpToken to deposit.
     * @param receiver Address to receive the minted shares.
     * @return shares Amount of shares minted.
     */
    function deposit(uint256 assets, address receiver) public override returns (uint256 shares) {
        require(assets > 0, ZeroAmount());
        shares = convertToShares(assets);
        lpToken.transferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);
    }

    /**
     * @dev Withdraws lpToken from the vault in exchange for burning shares.
     * @param assets Amount of lpToken to withdraw.
     * @param receiver Address to receive the lpToken.
     * @param owner Address whose shares will be burned.
     * @return shares Burned shares corresponding to the assets withdrawn.
     */
    function withdraw(uint256 assets, address receiver, address owner) public override returns (uint256 shares) {
        require(assets > 0, ZeroAmount());
        shares = convertToShares(assets);
        if (msg.sender != owner) {
            uint256 allowed = allowance(owner, msg.sender);
            require(allowed >= shares, "ERC4626: insufficient allowance");
            _approve(owner, msg.sender, allowed - shares);
        }
        _burn(owner, shares);
        lpToken.transfer(receiver, assets);
    }

    /**
     * @dev Redeems shares for lpToken.
     * @param shares Amount of shares to redeem.
     * @param receiver Address to receive the lpToken.
     * @param owner Address whose shares will be burned.
     * @return assets Amount of lpToken withdrawn.
     */
    function redeem(uint256 shares, address receiver, address owner) public override returns (uint256 assets) {
        require(shares > 0, ZeroAmount());
        assets = convertToAssets(shares);
        if (msg.sender != owner) {
            uint256 allowed = allowance(owner, msg.sender);
            require(allowed >= shares, InsufficientAllowance());
            _approve(owner, msg.sender, allowed - shares);
        }
        _burn(owner, shares);
        lpToken.transfer(receiver, assets);
    }

    /**
     * @dev Returns the maximum amount of assets that can be withdrawn by `owner`.
     * @param owner Address of the account.
     * @return The maximum amount of lpToken that can be withdrawn.
     */
    function maxWithdraw(address owner) public view override returns (uint256) {
        // Convert the owner's balance of shares to assets
        return convertToAssets(balanceOf(owner));
    }

    /**
     * @dev Simulates the amount of shares that would be minted for a given amount of assets.
     * @param assets Amount of lpToken to deposit.
     * @return The number of shares that would be minted.
     */
    function previewDeposit(uint256 assets) public view override returns (uint256) {
        // Convert assets to shares
        return convertToShares(assets);
    }

    /**
     * @dev Simulates the amount of assets that would be needed to mint a given amount of shares.
     * @param shares Amount of shares to mint.
     * @return The number of assets required.
     */
    function previewMint(uint256 shares) public view override returns (uint256) {
        // Convert shares to assets
        return convertToAssets(shares);
    }

    /**
     * @dev Simulates the amount of assets that would be withdrawn for a given amount of shares.
     * @param shares Amount of shares to redeem.
     * @return The number of assets that would be withdrawn.
     */
    function previewRedeem(uint256 shares) public view override returns (uint256) {
        // Convert shares to assets
        return convertToAssets(shares);
    }
}
