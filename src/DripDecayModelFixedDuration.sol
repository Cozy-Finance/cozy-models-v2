// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.18;

import "src/interfaces/IDripDecayModel.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

/**
 * @notice Constant rate drip/decay model.
 */
contract DripDecayModelFixedDuration is IDripDecayModel {
  using FixedPointMathLib for uint256;

  /// @notice Small decay rate as the per-second rate corresponding to a 1% annual decay.
  uint256 public immutable very_small_decay_rate;

  /// @notice Desired protection duration.
  uint256 public immutable duration;

  /// @notice Utilization threshold.
  /// @dev For fixed duration models, we decay at the minimum possible non-zero rate per second.
  /// Then, we calculate what the final amount of protection would be at the minimal decay rate
  /// using the exponential decay formula:
  ///  A = (1 - r)^t
  /// where
  ///  A is the decayed amount.
  ///  r is the per-second drip/decay rate, set to 1/WAD.
  ///  t is the desired duration in seconds
  /// The utilization threshold is simply the value of A at the desired duration.
  uint256 public immutable utilizationThreshold;

  /// @param _duration Fixed-length duration in seconds.
  constructor(uint256 _duration) {
    very_small_decay_rate = 318_476_000;
    duration = _duration;
    utilizationThreshold = (FixedPointMathLib.WAD - very_small_decay_rate).rpow(_duration, FixedPointMathLib.WAD);
  }

  /// @notice Returns the current rate based on the provided `_utilization`.
  function dripDecayRate(uint256 _utilization) external view returns (uint256) {
    if (_utilization == 0 || (_utilization >= utilizationThreshold)) {
      return very_small_decay_rate;
    } else {
      return FixedPointMathLib.WAD**2;
    }
  }
}