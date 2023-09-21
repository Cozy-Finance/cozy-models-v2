// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.18;

import {TestBase} from "test/utils/TestBase.sol";
import {console2} from "forge-std/console2.sol";

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {IDripDecayModel} from "src/interfaces/IDripDecayModel.sol";
import {DripDecayModelFixedDuration} from "src/DripDecayModelFixedDuration.sol";

contract DripDecayModelFixedDurationTest is TestBase {
  using FixedPointMathLib for uint256;

  function test_protectionDecayRate() public {
    assert_protectionDecayRate(1 days);
    assert_protectionDecayRate(7 days);
    assert_protectionDecayRate(30 days);
    assert_protectionDecayRate(90 days);
    assert_protectionDecayRate(180 days);
    assert_protectionDecayRate(365.25 days);
  }

  function assert_protectionDecayRate(uint256 duration) public {
    DripDecayModelFixedDuration model = new DripDecayModelFixedDuration(duration);
    uint256 utilizationThreshold = model.utilizationThreshold();
    uint256 very_small_decay_rate = model.very_small_decay_rate();

    console2.log("duration", duration);
    console2.log("utilizationThreshold", utilizationThreshold);

    assert(model.dripDecayRate(utilizationThreshold - 1) == FixedPointMathLib.WAD**2);
    assert(model.dripDecayRate(utilizationThreshold) == FixedPointMathLib.WAD**2);
    assert(model.dripDecayRate(utilizationThreshold + 1) == very_small_decay_rate);
  }
}
