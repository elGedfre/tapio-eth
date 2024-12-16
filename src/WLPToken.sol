// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
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
contract WLPToken is ERC20PermitUpgradeable {
    ILPToken public lpToken;

    function initialize(ILPToken _lpToken) public initializer {
        __ERC20Permit_init("Wrapped lpToken");
        __ERC20_init("Wrapped lpToken", "wlpToken");
        lpToken = _lpToken;
    }

    /**
     * @notice Exchanges lpToken to wlpToken
     * @param _lpTokenAmount amount of lpToken to wrap in exchange for wlpToken
     * @dev Requirements:
     *  - msg.sender must approve at least `_lpTokenAmount` lpToken to this
     *    contract.
     * @return Amount of wlpToken user receives after wrap
     */
    function wrap(uint256 _lpTokenAmount) external returns (uint256) {
        require(_lpTokenAmount > 0, "wlpToken: can't wrap zero lpToken");
        uint256 _wlpTokenAmount = lpToken.getSharesByPooledEth(_lpTokenAmount);
        _mint(msg.sender, _wlpTokenAmount);
        lpToken.transferFrom(msg.sender, address(this), _lpTokenAmount);
        return _wlpTokenAmount;
    }

    /**
     * @notice Exchanges wlpToken to lpToken
     * @param _wlpTokenAmount amount of wlpToken to uwrap in exchange for lpToken
     * @return Amount of lpToken user receives after unwrap
     */
    function unwrap(uint256 _wlpTokenAmount) external returns (uint256) {
        require(_wlpTokenAmount > 0, "wlpToken: zero amount unwrap not allowed");
        uint256 _lpTokenAmount = lpToken.getPooledEthByShares(_wlpTokenAmount);
        _burn(msg.sender, _wlpTokenAmount);
        lpToken.transfer(msg.sender, _lpTokenAmount);
        return _lpTokenAmount;
    }

    /**
     * @notice Get amount of wlpToken for a given amount of lpToken
     * @param _lpTokenAmount amount of lpToken
     * @return Amount of wlpToken for a given lpToken amount
     */
    function getWLPTokenByLPToken(uint256 _lpTokenAmount) external view returns (uint256) {
        return lpToken.getSharesByPooledEth(_lpTokenAmount);
    }

    /**
     * @notice Get amount of lpToken for a given amount of wlpToken
     * @param _wlpTokenAmount amount of wlpToken
     * @return Amount of lpToken for a given wlpToken amount
     */
    function getLPTokenByWLPToken(uint256 _wlpTokenAmount) external view returns (uint256) {
        return lpToken.getPooledEthByShares(_wlpTokenAmount);
    }

    /**
     * @notice Get amount of lpToken for a one wlpToken
     * @return Amount of lpToken for 1 wstETH
     */
    function lpTokenPerToken() external view returns (uint256) {
        return lpToken.getPooledEthByShares(1 ether);
    }

    /**
     * @notice Get amount of wlpToken for a one lpToken
     * @return Amount of wlpToken for a 1 lpToken
     */
    function tokensPerLPToken() external view returns (uint256) {
        return lpToken.getSharesByPooledEth(1 ether);
    }
}
