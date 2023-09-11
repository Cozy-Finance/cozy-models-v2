// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.18;

import {TestBase} from "test/utils/TestBase.sol";

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {ICostModel} from "src/interfaces/ICostModel.sol";
import {CostModelDynamicLevel} from "src/CostModelDynamicLevel.sol";
import {MockCostModelDynamicLevel} from "test/utils/MockCostModelDynamicLevel.sol";
import {MockCostModelJumpRate} from "test/utils/MockCostModelJumpRate.sol";

contract CostModelSetup is TestBase {
  using FixedPointMathLib for uint256;

  MockCostModelDynamicLevel costModel;
  address setAddress = address(0xABCDDCBA);

  function setUp() public virtual {
    costModel = new MockCostModelDynamicLevel({
          uLow_: 0.25e18,
          uHigh_: 0.75e18,
          costFactorAtZeroUtilization_: 0.005e18,
          costFactorAtFullUtilization_: 1e18,
          costFactorInOptimalZone_: 0.1e18,
          dailyOptimalZoneRate_: 0.1e18
        });

    vm.startPrank(setAddress);
    costModel.registerSet();
    vm.stopPrank();
  }
}

contract CostFactorRevertTest is CostModelSetup {
  function testFuzz_CostFactorRevertsIfNewUtilizationIsLowerThanOld(uint256 oldUtilization, uint256 newUtilization)
    public
  {
    vm.assume(newUtilization != oldUtilization);
    if (newUtilization > oldUtilization) (newUtilization, oldUtilization) = (oldUtilization, newUtilization);
    vm.expectRevert(CostModelDynamicLevel.InvalidUtilization.selector);
    costModel.costFactor(oldUtilization, newUtilization);
  }

  function testFuzz_CostFactorRevertsIfNewUtilizationIsGreaterThan100(uint256 oldUtilization, uint256 newUtilization)
    public
  {
    vm.assume(newUtilization > 1e18);
    vm.expectRevert(CostModelDynamicLevel.InvalidUtilization.selector);
    costModel.costFactor(oldUtilization, newUtilization);
  }
}

contract CostFactorPointInTimeTest is CostModelSetup {
  function test_CostFactorOverSpecificUtilizationIntervals() public {
    assertEq(costModel.costFactor(0.0e18, 0.25e18), 0.525e17);
    assertEq(costModel.costFactor(0.0e18, 0.3e18), 0.60416666666666667e17);
    assertEq(costModel.costFactor(0.1e18, 0.2e18), 0.62e17);
    assertEq(costModel.costFactor(0.1e18, 0.6e18), 0.9145e17);
    assertEq(costModel.costFactor(0.0e18, 1.0e18), 0.200625e18);
    assertEq(costModel.costFactor(0.4e18, 0.8e18), 0.11125e18);
    assertEq(costModel.costFactor(0.75e18, 1.0e18), 0.55e18);
    assertEq(costModel.costFactor(0.0e18, 0.8e18), 0.9078125e17);
    assertEq(costModel.costFactor(0.2e18, 0.8e18), 0.106708333333333334e18);
    assertEq(costModel.costFactor(0.9e18, 1.0e18), 0.82e18);
    assertEq(costModel.costFactor(0.9e18, 0.999e18), 0.8182e18);
  }

  function test_CostFactorWhenIntervalIsZero() public {
    assertEq(costModel.costFactor(0.0e18, 0.0e18), 0.5e16);
    assertEq(costModel.costFactor(0.8e18, 0.8e18), 0.28e18);
    assertEq(costModel.costFactor(1.0e18, 1.0e18), 1e18);
    assertEq(costModel.costFactor(0.05e18, 0.05e18), 0.24e17);
    assertEq(costModel.costFactor(0.1e18, 0.1e18), 0.43e17);
    assertEq(costModel.costFactor(0.2e18, 0.2e18), 0.81e17);
    assertEq(costModel.costFactor(0.4e18, 0.4e18), 0.1e18);
    assertEq(costModel.costFactor(0.9e18, 0.9e18), 0.64e18);
    assertEq(costModel.costFactor(0.95e18, 0.95e18), 0.82e18);
  }

  function testFuzz_CostFactorOverRandomIntervals(
    uint256 intervalLowPoint,
    uint256 intervalMidPoint,
    uint256 intervalHighPoint,
    uint256 totalProtection
  ) public {
    intervalHighPoint = bound(intervalHighPoint, 0.000003e18, 1e18); // 0.0003% is just a very low high-interval
    intervalMidPoint = bound(intervalMidPoint, 2e12, intervalHighPoint);
    intervalLowPoint = bound(intervalLowPoint, 0, intervalMidPoint);

    totalProtection = bound(totalProtection, 1e10, type(uint128).max);

    uint256 costFactorA = costModel.costFactor(intervalLowPoint, intervalMidPoint);
    uint256 costFactorB = costModel.costFactor(intervalMidPoint, intervalHighPoint);

    uint256 feeAmountTwoIntervals =
    //  |<----------------------- feeAmountA * 1e36 ----------------------->|
    //  |<------------ protectionAmountA * 1e18 ------------->|
    (
      (intervalMidPoint - intervalLowPoint) * totalProtection * costFactorA
      //  |<----------------------- feeAmountN * 1e36 ----------------------->|
      //  |<------------ protectionAmountB * 1e18 ------------->|
      + (intervalHighPoint - intervalMidPoint) * totalProtection * costFactorB
    ) / 1e36;

    // Now do the same thing but over a single interval.
    uint256 protectionAmountOneInterval = (intervalHighPoint - intervalLowPoint) * totalProtection / 1e18;
    uint256 costFactorOneInterval = costModel.costFactor(intervalLowPoint, intervalHighPoint);
    uint256 feeAmountOneInterval = protectionAmountOneInterval * costFactorOneInterval / 1e18;

    if (feeAmountOneInterval > 100) {
      // The fees will differ slightly because of integer division rounding.
      assertApproxEqRel(feeAmountOneInterval, feeAmountTwoIntervals, 0.01e18);
    } else {
      assertApproxEqAbs(feeAmountOneInterval, feeAmountTwoIntervals, 1);
    }
  }

  function testFuzz_CostFactorAlwaysBelowCostFactorAtFullUtilization(uint256 fromUtilization_, uint256 toUtilization_)
    public
  {
    fromUtilization_ = bound(fromUtilization_, 0, 1e18);
    toUtilization_ = bound(toUtilization_, fromUtilization_, 1e18);
    assertLe(costModel.costFactor(fromUtilization_, toUtilization_), costModel.costFactorAtFullUtilization() + 1);
  }

  function testFuzz_CostFactorAlwaysAboveCostFactorAtZeroUtilization(uint256 fromUtilization_, uint256 toUtilization_)
    public
  {
    fromUtilization_ = bound(fromUtilization_, 0, 1e18);
    toUtilization_ = bound(toUtilization_, fromUtilization_, 1e18);
    assertGe(costModel.costFactor(fromUtilization_, toUtilization_), costModel.costFactorAtZeroUtilization());
  }

  function testFuzz_ComputedStorageParamsCorrect(uint256 utilization_) public {
    (uint256 computedCostFactorInOptimalZone_, uint256 computedLastUpdateTime_) =
      costModel.getUpdatedStorageParams(block.timestamp, utilization_);
    // Computed cost factor will equal storage cost factor because timeDelta == 0.
    assertEq(computedCostFactorInOptimalZone_, costModel.costFactorInOptimalZone());
    assertEq(computedLastUpdateTime_, block.timestamp);
  }
}

contract CostFactorOverTimeTest is CostModelSetup {
  using FixedPointMathLib for uint256;

  function test_CostFactorOverSpecificUtilizationIntervalDynamic() public {
    // Cost comes down over time as no one purchases.
    assertEq(costModel.costFactor(0e18, 0.8e18), 0.9078125e17);
    skip(1);
    assertEq(costModel.costFactor(0e18, 0.8e18), 0.90781201533564815e17);
    skip(1000);
    assertEq(costModel.costFactor(0e18, 0.8e18), 0.90732735098379605e17);
    skip(1_000_000);
    assertEq(costModel.costFactor(0e18, 0.8e18), 0.42266299913169605e17);
    // Someone purchases and pushes utilization up to 80%.
    vm.startPrank(setAddress);
    costModel.update(0e18, 0.8e18);
    vm.stopPrank();
    // Cost goes up, as a result.
    assertEq(costModel.costFactor(0e18, 0.8e18), 0.119890220052098238e18);
    // Cost is smaller the longer no one purchases.
    skip(1000);
    assertEq(costModel.costFactor(0e18, 0.8e18), 0.119824908148132869e18);
    skip(100_000_000);
    assertEq(costModel.costFactor(0e18, 0.8e18), 0.1121875e17);
  }

  function test_CostFactorInOptimalZoneConvergesToLowerBound() public {
    skip(100_000_000_000_000);
    vm.startPrank(setAddress);
    costModel.update(0e18, 0e18);
    vm.stopPrank();
    assertEq(costModel.costFactorAtZeroUtilization(), costModel.costFactorInOptimalZone());
    assertEq(costModel.lastUpdateTime(), block.timestamp);
  }

  function testFuzz_ComputedStorageParamsMovesInRightDirection(uint256 utilization_) public {
    utilization_ = bound(utilization_, costModel.uLow(), costModel.uHigh());
    vm.startPrank(setAddress);
    costModel.update(0e18, utilization_ / 2);
    vm.stopPrank();

    (uint256 oldcostFactorInOptimalZone_,) = costModel.getUpdatedStorageParams(block.timestamp, utilization_);
    skip(1_000_000);
    (uint256 newCostFactorInOptimalZone_,) = costModel.getUpdatedStorageParams(block.timestamp, utilization_);
    if (utilization_ < costModel.uOpt()) assertLe(newCostFactorInOptimalZone_, oldcostFactorInOptimalZone_);
    else assertGe(newCostFactorInOptimalZone_, oldcostFactorInOptimalZone_);
  }

  function testFuzz_ComputedStorageParamsEqualsStorageParams(uint256 utilization_, uint128 timeSkip_) public {
    utilization_ = bound(utilization_, costModel.uLow(), costModel.uHigh());
    timeSkip_ = uint128(bound(timeSkip_, 0, 1000 days));

    skip(uint256(timeSkip_));
    vm.startPrank(setAddress);
    costModel.update(0e18, utilization_ / 2);
    vm.stopPrank();

    skip(uint256(timeSkip_) + 1_000_000);
    (uint256 computedCostFactorInOptimalZone_, uint256 computedlastUpdateTime_) =
      costModel.getUpdatedStorageParams(block.timestamp, utilization_);
    assertEq(computedlastUpdateTime_, block.timestamp);
    vm.startPrank(setAddress);
    costModel.update(0e18, utilization_);
    vm.stopPrank();
    assertEq(computedCostFactorInOptimalZone_, costModel.costFactorInOptimalZone());
  }
}

contract CostFactorStraightLineTest is TestBase {
  using FixedPointMathLib for uint256;

  MockCostModelDynamicLevel costModel;

  function setUp() public virtual {
    costModel = new MockCostModelDynamicLevel({
          uLow_: 0,
          uHigh_: 1e18,
          costFactorAtZeroUtilization_: 0.1e18,
          costFactorAtFullUtilization_: 1e18,
          costFactorInOptimalZone_: 0.25e18,
          dailyOptimalZoneRate_: 0.1e18
        }
    );
  }

  function test_CostFactorIsConstant() public {
    assertEq(costModel.costFactor(0, 0), 0.25e18);
    assertEq(costModel.costFactor(0.25e18, 0.25e18), 0.25e18);
    assertEq(costModel.costFactor(0.7e18, 0.7e18), 0.25e18);
    assertEq(costModel.costFactor(1e18, 1e18), 0.25e18);
    assertEq(costModel.costFactor(0.3e18, 0.4e18), 0.25e18);
    assertEq(costModel.costFactor(0.3e18, 0.9e18), 0.25e18);
    assertEq(costModel.costFactor(0e18, 1e18), 0.25e18);
  }

  function test_CostFactorIsConstantOverTime() public {
    skip(1);
    (uint256 costFactorInOptimalZone_,) = costModel.getUpdatedStorageParams(block.timestamp, 0);
    assertEq(costModel.costFactor(0, 0), costFactorInOptimalZone_);
    assertEq(costModel.costFactor(0, 0.2e18), costFactorInOptimalZone_);
    (costFactorInOptimalZone_,) = costModel.getUpdatedStorageParams(block.timestamp, 0.5e18);
    assertEq(costModel.costFactor(0.5e18, 0.75e18), costFactorInOptimalZone_);
    assertEq(costModel.costFactor(0.5e18, 1e18), costFactorInOptimalZone_);

    skip(1_000_000);
    (costFactorInOptimalZone_,) = costModel.getUpdatedStorageParams(block.timestamp, 0.1e18);
    assertEq(costModel.costFactor(0.1e18, 0.1e18), costFactorInOptimalZone_);
    assertEq(costModel.costFactor(0.1e18, 0.9e18), costFactorInOptimalZone_);
    assertEq(costModel.costFactor(0.1e18, 1e18), costFactorInOptimalZone_);

    skip(100_000_000);
    assertEq(costModel.costFactor(0.04e18, 0.1e18), 0.1e18);
    assertEq(costModel.costFactor(0.1e18, 0.9e18), 0.1e18);
    assertEq(costModel.costFactor(0.1e18, 1e18), 0.1e18);
  }
}

contract CostModelDeploy is CostModelSetup {
  function testFuzz_ConstructorRevertsWhenUtilizationArgumentsAreMisspecified(uint256 uLow_, uint256 uHigh_) public {
    vm.assume(uHigh_ > FixedPointMathLib.WAD || uLow_ > uHigh_);
    vm.expectRevert(CostModelDynamicLevel.InvalidConfiguration.selector);
    new CostModelDynamicLevel({
          uLow_: uLow_,
          uHigh_: uHigh_,
          costFactorAtZeroUtilization_: 0.005e18,
          costFactorAtFullUtilization_: 1e18,
          costFactorInOptimalZone_: 0.1e18,
          dailyOptimalZoneRate_: 0.1e18
        });
  }

  function testFuzz_ConstructorRevertsWhenBoundsAreMisspecified(
    uint256 costFactorAtZeroUtilization_,
    uint256 costFactorAtFullUtilization_
  ) public {
    vm.assume(
      costFactorAtFullUtilization_ > FixedPointMathLib.WAD
        || costFactorAtZeroUtilization_ > costFactorAtFullUtilization_
    );
    vm.expectRevert(CostModelDynamicLevel.InvalidConfiguration.selector);
    new CostModelDynamicLevel({
          uLow_: 0.25e18,
          uHigh_: 0.75e18,
          costFactorAtZeroUtilization_: costFactorAtZeroUtilization_,
          costFactorAtFullUtilization_: costFactorAtFullUtilization_,
          costFactorInOptimalZone_: 0.1e18,
          dailyOptimalZoneRate_: 0.1e18
        });
  }
}

contract RefundFactorRevertTest is CostModelSetup {
  function testFuzz_RefundFactorRevertsIfOldUtilizationIsLowerThanNew(uint256 oldUtilization, uint256 newUtilization)
    public
  {
    vm.assume(newUtilization != oldUtilization);
    if (newUtilization < oldUtilization) (newUtilization, oldUtilization) = (oldUtilization, newUtilization);
    vm.expectRevert(CostModelDynamicLevel.InvalidUtilization.selector);
    costModel.refundFactor(oldUtilization, newUtilization);
  }
}

contract RefundFactorPointInTimeTest is CostModelSetup {
  // The refund factor should return the percentage that the interval
  // constitutes of the area under the utilized portion of the curve.
  function test_RefundFactorOverSpecificUtilizationIntervals() public {
    // See test_AreaUnderCurveWhenIntervalIsNonZero for the source of the area calculations.
    // Formula is: area-within-interval / total-utilized-area
    // Where:
    //   area-within-interval = B, i.e. the portion of utilization being canceled
    //   total-utilized-area = A+B
    //
    //     ^                        /
    //     |                      /
    //     |                    /
    //  R  |                  / |
    //  a  |                /   |
    //  t  |             _-`    |
    //  e  |          _-`       |
    //     |       _-`  |       |
    //     |    _-`     |   B   |
    //     | _-`    A   |       |
    //     `----------------------------->
    //           Utilization %
    assertEq(costModel.refundFactor(0.2e18, 0.0e18), 1e18); // all of the fees
    assertEq(costModel.refundFactor(0.5e18, 0.0e18), 1e18); // all of the fees
    assertEq(costModel.refundFactor(0.2e18, 0.1e18), 0.720930232558139534e18);
    assertApproxEqRel(costModel.refundFactor(0.9e18, 0.5e18), 0.678609062170706006e18, 1e10);
    assertEq(costModel.refundFactor(1.0e18, 0.0e18), 1e18); // all of the fees
    assertApproxEqAbs(costModel.refundFactor(1.0e18, 0.8e18), 0.638006230529595015e18, 1);
    assertApproxEqRel(costModel.refundFactor(0.9e18, 0.8e18), 0.387776606954689146e18, 1e10);
    assertApproxEqAbs(costModel.refundFactor(0.8e18, 0.4e18), 0.612736660929432013e18, 1);
    assertApproxEqAbs(costModel.refundFactor(0.8e18, 0.2e18), 0.881583476764199655e18, 1);
    assertEq(costModel.refundFactor(0.8e18, 0.0e18), 1e18);
    assertApproxEqAbs(costModel.refundFactor(1.0e18, 0.9e18), 0.408722741433021806e18, 1);

    // Above 100% utilization.
    assertEq(costModel.refundFactor(1.6e18, 1.5e18), 0.205712313400638536e18);
    assertEq(costModel.refundFactor(1.6e18, 1.2e18), 0.673742341875916817e18);
    assertEq(costModel.refundFactor(1.6e18, 1e18), 0.861506601087237898e18);
    assertEq(costModel.refundFactor(1.6e18, 0.8e18), 0.949866252480800759e18);
    assertEq(costModel.refundFactor(1.6e18, 0.0e18), 1e18); // all of the fees
  }

  function test_RefundFactorWhenIntervalIsZero(uint256 _utilization) public {
    _utilization = bound(_utilization, 0, 2.0e18);
    assertEq(costModel.refundFactor(_utilization, _utilization), 0);
  }
}

contract CostModelCompareParametersTest is TestBase {
  using FixedPointMathLib for uint256;

  function testFuzz_CheaperCostModelHasLowerCosts(
    uint256 costFactorInOptimalZoneCheap_,
    uint256 costFactorInOptimalZoneExpensive_
  ) public {
    costFactorInOptimalZoneCheap_ = bound(costFactorInOptimalZoneCheap_, 0e18, 1e18);
    costFactorInOptimalZoneExpensive_ = bound(costFactorInOptimalZoneExpensive_, costFactorInOptimalZoneCheap_, 1e18);
    MockCostModelDynamicLevel costModelCheap = new MockCostModelDynamicLevel({
            uLow_: 0.25e18,
            uHigh_: 0.75e18,
            costFactorAtZeroUtilization_: 0e18,
            costFactorAtFullUtilization_: 1e18,
            costFactorInOptimalZone_: costFactorInOptimalZoneCheap_,
            dailyOptimalZoneRate_: 0.1e18
        });
    MockCostModelDynamicLevel costModelExpensive = new MockCostModelDynamicLevel({
            uLow_: 0.25e18,
            uHigh_: 0.75e18,
            costFactorAtZeroUtilization_: 0e18,
            costFactorAtFullUtilization_: 1e18,
            costFactorInOptimalZone_: costFactorInOptimalZoneExpensive_,
            dailyOptimalZoneRate_: 0.1e18
        });
    assertGe(costModelExpensive.costFactor(0.5e18, 0.5e18), costModelCheap.costFactor(0.5e18, 0.5e18));
    assertGe(costModelExpensive.costFactor(0e18, 0.5e18), costModelCheap.costFactor(0e18, 0.5e18));
    assertGe(costModelExpensive.costFactor(0.5e18, 1e18), costModelCheap.costFactor(0.5e18, 1e18));
    assertGe(costModelExpensive.costFactor(0.2e18, 0.8e18), costModelCheap.costFactor(0.2e18, 0.8e18));
  }
}

contract CostModelCompareToJumpRateModel is TestBase {
  using FixedPointMathLib for uint256;

  MockCostModelDynamicLevel dynamicCostModel;
  MockCostModelJumpRate jumpRateCostModel;
  address setAddress = address(0xABCDDCBA);

  function setUp() public virtual {
    // Dynamic cost model with zero optimal zone rate and zero zone width is same as jump rate.
    dynamicCostModel = new MockCostModelDynamicLevel({
          uLow_: 0.85e18,
          uHigh_: 0.85e18,
          costFactorAtZeroUtilization_: 0.1e18,
          costFactorAtFullUtilization_: 0.8e18,
          costFactorInOptimalZone_: 0.25e18,
          dailyOptimalZoneRate_: 0
        }
    );

    jumpRateCostModel = new MockCostModelJumpRate({
          _kink: 0.85e18,
          _rateAtZeroUtilization: 0.1e18,
          _rateAtKinkUtilization: 0.25e18,
          _rateAtFullUtilization: 0.8e18
        }
    );

    vm.startPrank(setAddress);
    dynamicCostModel.registerSet();
    jumpRateCostModel.registerSet();
    vm.stopPrank();
  }

  function testFuzz_CostFactorsEqual(uint256 _fromUtilization, uint256 _toUtilization, uint256 _timeSkip) public {
    _fromUtilization = bound(_fromUtilization, 0, 1e18);
    _toUtilization = bound(_toUtilization, _fromUtilization, 1e18);
    _timeSkip = bound(_timeSkip, 0, 36_500 days);

    assertApproxEqAbs(
      dynamicCostModel.costFactor(_fromUtilization, _toUtilization),
      jumpRateCostModel.costFactor(_fromUtilization, _toUtilization),
      1
    );
    assertApproxEqAbs(
      dynamicCostModel.refundFactor(_toUtilization, _fromUtilization),
      jumpRateCostModel.refundFactor(_toUtilization, _fromUtilization),
      1
    );

    vm.startPrank(setAddress);
    dynamicCostModel.update(_fromUtilization, _toUtilization);
    jumpRateCostModel.update(_fromUtilization, _toUtilization);
    vm.stopPrank();

    skip(_timeSkip);
    assertApproxEqAbs(
      dynamicCostModel.costFactor(_fromUtilization, _toUtilization),
      jumpRateCostModel.costFactor(_fromUtilization, _toUtilization),
      1
    );
    assertApproxEqAbs(
      dynamicCostModel.refundFactor(_toUtilization, _fromUtilization),
      jumpRateCostModel.refundFactor(_toUtilization, _fromUtilization),
      1
    );
  }
}

contract CostModelCornerOptimalZoneRateCases is TestBase {
  using FixedPointMathLib for uint256;

  MockCostModelDynamicLevel zeroOptimalZoneRateModel;

  address setAddress = address(0xABCDDCBA);

  function setUp() public virtual {
    zeroOptimalZoneRateModel = new MockCostModelDynamicLevel({
          uLow_: 0.65e18,
          uHigh_: 0.85e18,
          costFactorAtZeroUtilization_: 0.1e18,
          costFactorAtFullUtilization_: 0.8e18,
          costFactorInOptimalZone_: 0.25e18,
          dailyOptimalZoneRate_: 0e18
        }
    );

    vm.startPrank(setAddress);
    zeroOptimalZoneRateModel.registerSet();
    vm.stopPrank();
  }

  function testFuzz_zeroOptimalZoneRateModel(uint256 _fromUtilization, uint256 _toUtilization, uint256 _timeSkip)
    public
  {
    assertEq(zeroOptimalZoneRateModel.optimalZoneRate(), 0);

    _fromUtilization = bound(_fromUtilization, 0, 1e18);
    _toUtilization = bound(_toUtilization, _fromUtilization, 1e18);
    _timeSkip = bound(_timeSkip, 0, 36_500_000_000 days);

    uint256 _originalCostFactorInOptimalZone = zeroOptimalZoneRateModel.costFactorInOptimalZone();
    uint256 _originalCostFactor = zeroOptimalZoneRateModel.costFactor(_fromUtilization, _toUtilization);

    vm.startPrank(setAddress);
    zeroOptimalZoneRateModel.update(_fromUtilization, _toUtilization);
    vm.stopPrank();
    skip(_timeSkip);
    vm.startPrank(setAddress);
    zeroOptimalZoneRateModel.update(_fromUtilization, _toUtilization);
    vm.stopPrank();

    uint256 _newCostFactorInOptimalZone = zeroOptimalZoneRateModel.costFactorInOptimalZone();
    uint256 _newCostFactor = zeroOptimalZoneRateModel.costFactor(_fromUtilization, _toUtilization);

    assertEq(_originalCostFactorInOptimalZone, _newCostFactorInOptimalZone);
    assertEq(_originalCostFactor, _newCostFactor);
  }
}

contract CostModelCostFactorInOptimalZoneCalculation is TestBase {
  using FixedPointMathLib for uint256;

  address setAddress = address(0xABCDDCBA);

  function testFuzz_standardModel(uint256 _zeroTimeDeltaUtilization, uint256 _zeroUtilDiffTimeDelta) public {
    MockCostModelDynamicLevel costModel = new MockCostModelDynamicLevel({
          uLow_: 0.65e18,
          uHigh_: 0.85e18,
          costFactorAtZeroUtilization_: 0.1e18,
          costFactorAtFullUtilization_: 0.8e18,
          costFactorInOptimalZone_: 0.25e18,
          dailyOptimalZoneRate_: 0.05e18
        }
    );
    vm.startPrank(setAddress);
    costModel.registerSet();
    vm.stopPrank();

    // If timeDelta or util diff is zero, cost factor does not change.
    uint256 zeroTimeDeltaResult = costModel.computeNewCostFactorInOptimalZone(_zeroTimeDeltaUtilization, 0);
    assertEq(zeroTimeDeltaResult, 0.25e18);
    uint256 zeroUtilDiffResult = costModel.computeNewCostFactorInOptimalZone(0.75e18, _zeroUtilDiffTimeDelta);
    assertEq(zeroUtilDiffResult, 0.25e18);

    uint256 fullUtilizationResult1 = costModel.computeNewCostFactorInOptimalZone(1e18, 1 days);
    assertEq(fullUtilizationResult1, 0.2531250000000016e18);

    uint256 fullUtilizationResult2 = costModel.computeNewCostFactorInOptimalZone(1e18, 10_000 days);
    assertEq(fullUtilizationResult2, 0.8e18);

    uint256 highUtilizationResult1 = costModel.computeNewCostFactorInOptimalZone(0.8e18, 1 days);
    assertEq(highUtilizationResult1, 0.25062500000000032e18);

    uint256 highUtilizationResult2 = costModel.computeNewCostFactorInOptimalZone(0.8e18, 10_000 days);
    assertEq(highUtilizationResult2, 0.8e18);

    uint256 lowUtilizationResult1 = costModel.computeNewCostFactorInOptimalZone(0.1e18, 1 days);
    assertEq(lowUtilizationResult1, 0.24187499999999584e18);

    uint256 lowUtilizationResult2 = costModel.computeNewCostFactorInOptimalZone(0.1e18, 10_000 days);
    assertEq(lowUtilizationResult2, 0.1e18);
  }

  function testFuzz_highRateModel(uint256 _zeroTimeDeltaUtilization, uint256 _zeroUtilDiffTimeDelta) public {
    MockCostModelDynamicLevel costModel = new MockCostModelDynamicLevel({
          uLow_: 0.65e18,
          uHigh_: 0.85e18,
          costFactorAtZeroUtilization_: 0.1e18,
          costFactorAtFullUtilization_: 0.8e18,
          costFactorInOptimalZone_: 0.25e18,
          dailyOptimalZoneRate_: 20e18
        }
    );
    vm.startPrank(setAddress);
    costModel.registerSet();
    vm.stopPrank();

    // If timeDelta or util diff is zero, cost factor does not change.
    uint256 zeroTimeDeltaResult = costModel.computeNewCostFactorInOptimalZone(_zeroTimeDeltaUtilization, 0);
    assertEq(zeroTimeDeltaResult, 0.25e18);
    uint256 zeroUtilDiffResult = costModel.computeNewCostFactorInOptimalZone(0.75e18, _zeroUtilDiffTimeDelta);
    assertEq(zeroUtilDiffResult, 0.25e18);

    uint256 fullUtilizationResult1 = costModel.computeNewCostFactorInOptimalZone(1e18, 1 days);
    assertEq(fullUtilizationResult1, 0.8e18);

    uint256 fullUtilizationResult2 = costModel.computeNewCostFactorInOptimalZone(1e18, 10_000 days);
    assertEq(fullUtilizationResult2, 0.8e18);

    uint256 highUtilizationResult1 = costModel.computeNewCostFactorInOptimalZone(0.8e18, 1 days);
    assertEq(highUtilizationResult1, 0.50000000000000056e18);

    uint256 highUtilizationResult2 = costModel.computeNewCostFactorInOptimalZone(0.8e18, 10_000 days);
    assertEq(highUtilizationResult2, 0.8e18);

    uint256 lowUtilizationResult1 = costModel.computeNewCostFactorInOptimalZone(0.1e18, 1 days);
    assertEq(lowUtilizationResult1, 0.1e18);

    uint256 lowUtilizationResult2 = costModel.computeNewCostFactorInOptimalZone(0.1e18, 10_000 days);
    assertEq(lowUtilizationResult2, 0.1e18);
  }
}

contract CostModelSetAuthorization is TestBase {
  MockCostModelDynamicLevel costModel;
  address setAddress = address(0xABCDDCBA);

  function setUp() public virtual {
    costModel = new MockCostModelDynamicLevel({
          uLow_: 0.25e18,
          uHigh_: 0.75e18,
          costFactorAtZeroUtilization_: 0.005e18,
          costFactorAtFullUtilization_: 1e18,
          costFactorInOptimalZone_: 0.1e18,
          dailyOptimalZoneRate_: 0.1e18
        });
  }

  function test_UpdateRevertsWithNonSetAddressSender() public {
    vm.startPrank(setAddress);
    costModel.registerSet();
    vm.stopPrank();

    address nonSetAddress_ = _randomAddress();
    vm.assume(nonSetAddress_ != setAddress);

    vm.startPrank(nonSetAddress_);
    vm.expectRevert(CostModelDynamicLevel.Unauthorized.selector);
    costModel.update(0.5e18, 0.6e18);
    vm.stopPrank();
  }

  function test_RevertsWhenSetIsAlreadyRegistered() public {
    vm.startPrank(setAddress);
    costModel.registerSet();
    vm.stopPrank();

    address nonSetAddress_ = _randomAddress();
    vm.assume(nonSetAddress_ != setAddress);

    vm.startPrank(nonSetAddress_);
    vm.expectRevert(CostModelDynamicLevel.SetAlreadyRegistered.selector);
    costModel.registerSet();
    vm.stopPrank();
  }

  function test_NoRevertWhenSetRegistryMatchesSetAddress() public {
    address setAddress_ = _randomAddress();
    vm.startPrank(setAddress_);
    costModel.registerSet();
    costModel.registerSet();
    vm.stopPrank();
  }

  function test_SetAddressMatchesRegistry() public {
    address setAddress_ = _randomAddress();
    vm.startPrank(setAddress_);
    costModel.registerSet();
    vm.stopPrank();
    assertEq(setAddress_, costModel.setAddress());
  }
}
