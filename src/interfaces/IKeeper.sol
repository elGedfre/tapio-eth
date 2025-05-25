// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../interfaces/IRampAController.sol";
import "../SelfPeggingAsset.sol";
import "./IParameterRegistry.sol";

/**
 * @title IKeeper
 * @notice Interface for the Keeper contract that enforces parameter bounds for curators
 */
interface IKeeper {
    /**
     * @notice Allows curators to gradually ramp the A coefficient within allowed bounds
     * @param newA The target A value
     * @param endTime Timestamp when ramping should complete
     */
    function rampA(uint256 newA, uint256 endTime) external;

    /**
     * @notice Set the swap fee within allowed bounds
     * @param newFee The new swap fee value
     */
    function setSwapFee(uint256 newFee) external;

    /**
     * @notice Set the mint fee within allowed bounds
     * @param newFee The new mint fee value
     */
    function setMintFee(uint256 newFee) external;

    /**
     * @notice Set the redeem fee within allowed bounds
     * @param newFee The new redeem fee value
     */
    function setRedeemFee(uint256 newFee) external;

    /**
     * @notice Set the off-peg fee multiplier within allowed bounds
     * @param newMultiplier The new off-peg fee multiplier value
     */
    function setOffPegFeeMultiplier(uint256 newMultiplier) external;

    /**
     * @notice Set the exchange rate fee within allowed bounds
     * @param newFeeFactor The new exchange rate fee value
     */
    function setExchangeRateFeeFactor(uint256 newFeeFactor) external;

    /**
     * @notice Set the decay period
     * @param newDecayPeriod The new decay period in seconds
     */
    function setDecayPeriod(uint256 newDecayPeriod) external;

    /**
     * @notice Set the rate change skip period
     * @param newSkipPeriod The new skip period in seconds
     */
    function setRateChangeSkipPeriod(uint256 newSkipPeriod) external;

    /**
     * @notice Set the fee error margin within allowed bounds
     * @param newMargin The new fee error margin value
     */
    function updateFeeErrorMargin(uint256 newMargin) external;

    /**
     * @notice Set the yield error margin within allowed bounds
     * @param newMargin The new yield error margin value
     */
    function updateYieldErrorMargin(uint256 newMargin) external;

    /**
     * @notice Distribute any losses incurred
     */
    function distributeLoss() external;

    /**
     * @notice Pause the SPA
     */
    function pause() external;

    /**
     * @notice Sets the governor address for the Keeper
     * @param _governor The address of the new governor
     */
    function setGovernor(address _governor) external;

    /**
     * @notice Allows guardians to cancel an ongoing A ramp in emergencies
     */
    function cancelRamp() external;

    /**
     * @notice Get the parameter registry used for bounds checking
     * @return The parameter registry address
     */
    function getRegistry() external view returns (IParameterRegistry);

    /**
     * @notice Get the RampAController being managed
     * @return The RampAController address
     */
    function getRampAController() external view returns (IRampAController);

    /**
     * @notice Get the SelfPeggingAsset being managed
     * @return The SelfPeggingAsset address
     */
    function getSpa() external view returns (SelfPeggingAsset);
}
