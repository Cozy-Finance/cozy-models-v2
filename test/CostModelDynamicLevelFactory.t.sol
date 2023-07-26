// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.18;

import "src/CostModelDynamicLevel.sol";
import "src/CostModelDynamicLevelFactory.sol";
import "src/lib/Create2.sol";
import "forge-std/Test.sol";

contract CostModelDynamicLevelFactoryTest is Test, CostModelDynamicLevelFactory {
  CostModelDynamicLevelFactory factory;

  function setUp() public {
    factory = new CostModelDynamicLevelFactory();
  }

  function testFuzz_deployModelAndVerifyAddress(
    uint256 uLow_,
    uint256 uHigh_,
    uint256 costFactorAtZeroUtilization_,
    uint256 costFactorAtFullUtilization_,
    uint256 costFactorInOptimalZone_,
    uint256 optimalZoneRate_,
    uint256 saltSeed_
  ) public {
    uHigh_ = bound(uHigh_, 0, 1e18);
    uLow_ = bound(uLow_, 0, uHigh_);
    costFactorAtZeroUtilization_ = bound(costFactorAtZeroUtilization_, 0, 1e18 - 1);
    costFactorAtFullUtilization_ = bound(costFactorAtFullUtilization_, costFactorAtZeroUtilization_, 1e18 - 1);

    bytes32 salt_ = bytes32(saltSeed_);
    address expectedModelAddress_ = factory.computeModelAddress(
      uLow_,
      uHigh_,
      costFactorAtZeroUtilization_,
      costFactorAtFullUtilization_,
      costFactorInOptimalZone_,
      optimalZoneRate_,
      salt_
    );
    CostModelDynamicLevel model_ = factory.deployModel(
      uLow_,
      uHigh_,
      costFactorAtZeroUtilization_,
      costFactorAtFullUtilization_,
      costFactorInOptimalZone_,
      optimalZoneRate_,
      salt_
    );

    assertEq(expectedModelAddress_, address(model_));
  }
}
