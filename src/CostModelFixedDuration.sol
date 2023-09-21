// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.18;

import {CostModelAreaCalculationsLib} from "./lib/CostModelAreaCalculationsLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {ICostModel} from "src/interfaces/ICostModel.sol";

contract CostModelFixedDuration is ICostModel {
  using FixedPointMathLib for uint256;

  uint256 internal constant ZERO_UTILIZATION = 0;
  uint256 internal constant FULL_UTILIZATION = FixedPointMathLib.WAD; // 1 wad

  /// @notice The cost factor, as a wad.
  uint256 public immutable costFactorFixedDuration;

  /// @notice The utilization threshold.
  uint256 public immutable utilizationThreshold;

  /// @notice Small decay rate as the per-second rate corresponding to a 1% annual decay.
  uint256 public immutable very_small_decay_rate;

  /// @dev Thrown when the utilization inputs passed to a method are out of bounds.
  error InvalidUtilization();

  /// @dev Thrown when a set of cost model parameters are not within valid bounds.
  error InvalidConfiguration();

  /// @param _costFactorFixedDuration The cost factor, as a wad.
  constructor(
    uint256 _costFactorFixedDuration,
    uint256 _duration
  ) {
    if (_costFactorFixedDuration > FixedPointMathLib.WAD) revert InvalidConfiguration();
    costFactorFixedDuration = _costFactorFixedDuration;
    very_small_decay_rate = 318_476_000;
    utilizationThreshold = (FixedPointMathLib.WAD - very_small_decay_rate).rpow(_duration, FixedPointMathLib.WAD);
  }

  /// @notice Returns the cost of purchasing protection as a percentage of the amount being purchased, as a wad.
  /// For example, if you are purchasing $200 of protection and this method returns 1e17, then the cost of
  /// the purchase is 200 * 1e17 / 1e18 = $20.
  /// @param _fromUtilization Initial utilization of the market.
  function costFactor(uint256 _fromUtilization, uint256 /* _toUtilization */) external view returns (uint256) {
    if (_fromUtilization < utilizationThreshold) {
        return costFactorFixedDuration;
    }
    revert InvalidUtilization();
  }

  /// @notice Gives the refund value in assets of returning protection, as a percentage of
  /// the supplier fee pool, as a wad. For example, if the supplier fee pool currently has $100
  /// and this method returns 1e17, then you will get $100 * 1e17 / 1e18 = $10 in assets back.
  /// @dev Refund factors, unlike cost factors, are defined for utilization above 100%, since markets
  /// can become over-utilized and protection can be sold in those cases.
  function refundFactor(uint256 /* _fromUtilization */, uint256 /* _toUtilization */) external view returns (uint256) {
    return 0;
  }

  /// @dev The jump rate model is static, so it has no need to update storage variables.
  function update(uint256 _fromUtilization, uint256 _toUtilization) external {}

  /// @dev The jump rate model is static, so there is no need to register the Set which can call `update`.
  function registerSet() external {}
}
