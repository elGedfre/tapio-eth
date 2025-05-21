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
    /// @notice SPA this registry is for
    SelfPeggingAsset public immutable spa;

    /// keccak256(abi.encode(uint256(keccak256("tapio.params.registry")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant STORAGE_SLOT = 0x882c628f41b9f95bc5e7f228cc14a4ad25b219701a90bc13bf2f12347cc27d00;

    constructor(
        address _governor,
        address _spa,
        Bounds memory _a,
        Bounds memory _swapFee,
        Bounds memory _mintFee,
        Bounds memory _redeemFee,
        Bounds memory _offPeg
    )
        Ownable(_governor)
    {
        require(_spa != address(0), ZeroAddress());

        spa = SelfPeggingAsset(_spa);

        ParameterRegistryStorage storage $ = _getStorage();
        $.aParams = _a;
        $.swapFeeParams = _swapFee;
        $.mintFeeParams = _mintFee;
        $.redeemFeeParams = _redeemFee;
        $.offPegParams = _offPeg;

        emit AParamsUpdated(_governor, _a, _a);
        emit SwapFeeParamsUpdated(_governor, _swapFee, _swapFee);
        emit MintFeeParamsUpdated(_governor, _mintFee, _mintFee);
        emit RedeemFeeParamsUpdated(_governor, _redeemFee, _redeemFee);
        emit OffPegParamsUpdated(_governor, _offPeg, _offPeg);
    }

    function aParams() external view returns (Bounds memory) {
        return _getStorage().aParams;
    }

    function swapFeeParams() external view returns (Bounds memory) {
        return _getStorage().swapFeeParams;
    }

    function mintFeeParams() external view returns (Bounds memory) {
        return _getStorage().mintFeeParams;
    }

    function redeemFeeParams() external view returns (Bounds memory) {
        return _getStorage().redeemFeeParams;
    }

    function offPegParams() external view returns (Bounds memory) {
        return _getStorage().offPegParams;
    }

    function setAParams(Bounds calldata params) external onlyOwner {
        ParameterRegistryStorage storage $ = _getStorage();
        emit AParamsUpdated(msg.sender, $.aParams, params);
        $.aParams = params;
    }

    function setSwapFeeParams(Bounds calldata params) external onlyOwner {
        ParameterRegistryStorage storage $ = _getStorage();
        emit SwapFeeParamsUpdated(msg.sender, $.swapFeeParams, params);
        $.swapFeeParams = params;
    }

    function setMintFeeParams(Bounds calldata params) external onlyOwner {
        ParameterRegistryStorage storage $ = _getStorage();
        emit MintFeeParamsUpdated(msg.sender, $.mintFeeParams, params);
        $.mintFeeParams = params;
    }

    function setRedeemFeeParams(Bounds calldata params) external onlyOwner {
        ParameterRegistryStorage storage $ = _getStorage();
        emit RedeemFeeParamsUpdated(msg.sender, $.redeemFeeParams, params);
        $.redeemFeeParams = params;
    }

    function setOffPegParams(Bounds calldata params) external onlyOwner {
        ParameterRegistryStorage storage $ = _getStorage();
        emit OffPegParamsUpdated(msg.sender, $.offPegParams, params);
        $.offPegParams = params;
    }

    function _getStorage() internal pure returns (ParameterRegistryStorage storage $) {
        assembly {
            $.slot := STORAGE_SLOT
        }
    }
}
