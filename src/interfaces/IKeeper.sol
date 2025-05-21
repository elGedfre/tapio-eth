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
     * @notice Allows curators to set the swap fee within allowed bounds
     * @param newFee The new swap fee value
     */
    function setSwapFee(uint256 newFee) external;

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
