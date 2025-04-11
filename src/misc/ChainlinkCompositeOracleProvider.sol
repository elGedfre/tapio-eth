//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@chainlink/contracts/shared/interfaces/AggregatorV3Interface.sol";

contract ChainlinkCompositeOracleProvider {
    /**
     * @notice Grace period time after the sequencer is back up
     */
    uint256 private constant GRACE_PERIOD_TIME = 3600;

    /**
     * @notice Chainlink feed for the sequencer uptime
     */
    AggregatorV3Interface public immutable sequencerUptimeFeed;

    /**
     * @notice Chainlink feed for the first asset. Ex: weETH - ETH
     */
    AggregatorV3Interface public immutable feed1;

    /**
     * @notice Chainlink feed for the second asset. Ex: stETH - ETH
     */
    AggregatorV3Interface public immutable feed2;

    /**
     * @notice Maximum stale period for the first price feed
     */
    uint256 public immutable maxStalePeriod1;

    /**
     * @notice Maximum stale period for the second price feed
     */
    uint256 public immutable maxStalePeriod2;

    /**
     * @notice Decimals of the second asset. Ex: stETH decimals
     */
    uint256 public immutable assetDecimals;

    /**
     * @notice Inverted flag for the second feed
     */
    bool public immutable isInverted;

    /**
     * @notice Error emitted when feed is invalid
     */
    error InvalidFeed();

    /**
     * @notice Error emitted when stale period is invalid
     */
    error InvalidStalePeriod();

    /**
     * @notice Error emitted when price is stale
     */
    error StalePrice();

    /**
     * @notice Error emitted when sequencer is down
     */
    error SequencerDown();

    /**
     * @notice Error emitted when grace period is not over
     */
    error GracePeriodNotOver();

    /**
     * @notice Contract constructor
     * @param _sequencerUptimeFeed L2 Sequencer uptime feed
     */
    constructor(
        AggregatorV3Interface _sequencerUptimeFeed,
        AggregatorV3Interface _feed1,
        AggregatorV3Interface _feed2,
        uint256 _maxStalePeriod1,
        uint256 _maxStalePeriod2,
        uint256 _assetDecimals,
        bool _inverted
    ) {
        if (address(_feed1) == address(0) || address(_feed2) == address(0)) {
            revert InvalidFeed();
        }

        if (_maxStalePeriod1 == 0 || _maxStalePeriod2 == 0) {
            revert InvalidStalePeriod();
        }

        sequencerUptimeFeed = _sequencerUptimeFeed;
        feed1 = _feed1;
        feed2 = _feed2;
        maxStalePeriod1 = _maxStalePeriod1;
        maxStalePeriod2 = _maxStalePeriod2;
        assetDecimals = _assetDecimals;
        isInverted = _inverted;
    }

    /**
     * @notice Get the price of the asset
     * @return Price of the asset
     */
    function price() external view returns (uint256) {
        _validateSequencerStatus();

        // 1 weETH = ? ETH = price1
        (, int256 price1,, uint256 updatedAt1,) = feed1.latestRoundData();

        if (block.timestamp - updatedAt1 > maxStalePeriod1) {
            revert StalePrice();
        }

        (, int256 price2,, uint256 updatedAt2,) = feed2.latestRoundData();

        if (block.timestamp - updatedAt2 > maxStalePeriod2) {
            revert StalePrice();
        }

        if (isInverted) {
            return ((((10 ** assetDecimals) * (10 ** assetDecimals)) / uint256(price2)) * uint256(price1))
                / (10 ** feed1.decimals());
        }

        return uint256(price1 * price2) / 10 ** feed1.decimals();
    }

    /**
     * @notice Get the decimals of the price
     * @return Decimals of the price
     */
    function decimals() external view returns (uint256) {
        return assetDecimals;
    }

    /**
     * @notice Validate the sequencer status
     */
    function _validateSequencerStatus() internal view {
        if (address(sequencerUptimeFeed) == address(0)) {
            return;
        }

        (
            /*uint80 roundID*/
            ,
            int256 answer,
            uint256 startedAt,
            /*uint256 updatedAt*/
            ,
            /*uint80 answeredInRound*/
        ) = sequencerUptimeFeed.latestRoundData();

        // Answer == 0: Sequencer is up
        // Answer == 1: Sequencer is down
        bool isSequencerUp = answer == 0;
        if (!isSequencerUp) {
            revert SequencerDown();
        }

        // Make sure the grace period has passed after the
        // sequencer is back up.
        uint256 timeSinceUp = block.timestamp - startedAt;
        if (timeSinceUp <= GRACE_PERIOD_TIME) {
            revert GracePeriodNotOver();
        }
    }
}
