// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "src/CostModelJumprate.sol";

/**
  * @notice *Purpose: Local deploy, testing, and production.*
  *
  * This script deploys a CostModelJumpRate contract.
  * Before executing, the configuration section in the script should be updated.
  *
  * To run this script:
  *
  * ```sh
  * # Start anvil, forking from the current state of the desired chain.
  * anvil --fork-url $OPTIMISM_RPC_URL
  *
  * # In a separate terminal, perform a dry run the script.
  * forge script script/DeployCostModelJumpRate.s.sol \
  *   --rpc-url "http://127.0.0.1:8545" \
  *   -vvvv
  *
  * # Or, to broadcast a transaction.
  * forge script script/DeployCostModelJumpRate.s.sol \
  *   --rpc-url "http://127.0.0.1:8545" \
  *   --private-key $OWNER_PRIVATE_KEY \
  *   --broadcast \
  *   -vvvv
  * ```
 */
contract DeployCostModelJumpRate is Script {

  // -------------------------------
  // -------- Configuration --------
  // -------------------------------

  uint256 kink = 0.8e18; // kink at 80%
  uint256 costFactorAtZeroUtilization = 0.0e18; // 0% fee at no utilization
  uint256 costFactorAtKinkUtilization = 0.2e18; // 20% fee at kink utilization
  uint256 costFactorAtFullUtilization = 0.5e18; // 50% fee at full utilization
  uint256 cancellationPenalty = 0.1e18;  // charge a 10% penalty to cancel

  // ---------------------------
  // -------- Execution --------
  // ---------------------------

  function run() public {
    console2.log("Deploying CostModelJumpRate...");
    console2.log("    kink", kink);
    console2.log("    costFactorAtZeroUtilization", costFactorAtZeroUtilization);
    console2.log("    costFactorAtKinkUtilization", costFactorAtKinkUtilization);
    console2.log("    costFactorAtFullUtilization", costFactorAtFullUtilization);
    console2.log("    cancellationPenalty", cancellationPenalty);

    vm.broadcast();
    CostModelJumpRate costModelJumpRate = new CostModelJumpRate(
      kink,
      costFactorAtZeroUtilization,
      costFactorAtKinkUtilization,
      costFactorAtFullUtilization,
      cancellationPenalty
    );
    console2.log("CostModelJumpRate deployed", address(costModelJumpRate));
  }
}
