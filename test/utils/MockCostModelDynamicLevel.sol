// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.18;

import {CostModelDynamicLevel} from "src/CostModelDynamicLevel.sol";

contract MockCostModelDynamicLevel is CostModelDynamicLevel {
  constructor(
    uint256 uLow_,
    uint256 uHigh_,
    uint256 costFactorAtZeroUtilization_,
    uint256 costFactorAtFullUtilization_,
    uint256 costFactorInOptimalZone_,
    uint256 dailyOptimalZoneRate_
  )
    CostModelDynamicLevel(
      uLow_,
      uHigh_,
      costFactorAtZeroUtilization_,
      costFactorAtFullUtilization_,
      costFactorInOptimalZone_,
      dailyOptimalZoneRate_
    )
  {}

  function areaUnderCurve(uint256 intervalLowPoint_, uint256 intervalHighPoint_, uint256 costFactorInOptimalZone_)
    public
    view
    returns (uint256)
  {
    return _areaUnderCurve(intervalLowPoint_, intervalHighPoint_, costFactorInOptimalZone_);
  }

  function computeNewCostFactorInOptimalZone(uint256 utilization_, uint256 timeDelta_)
    public
    view
    returns (uint256)
  {
    return _computeNewCostFactorInOptimalZone(utilization_, timeDelta_);
  }
}
