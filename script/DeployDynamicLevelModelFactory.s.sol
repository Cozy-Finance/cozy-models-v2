// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.18;

import "forge-std/Script.sol";
import "src/CostModelDynamicLevelFactory.sol";

/**
 * @notice Purpose: Local deploy, testing, and production.
 *
 * This script deploys the Model Factory contracts.
 * Before executing, the configuration section in the script should be updated.
 *
 * To run this script:
 *
 * ```sh
 * # Start anvil, forking from the current state of the desired chain.
 * anvil --fork-url $OPTIMISM_RPC_URL
 *
 * # In a separate terminal, perform a dry run of the script.
 * forge script script/DeployDynamicLevelModelFactory.s.sol \
 *   --rpc-url "http://127.0.0.1:8545" \
 *   -vvvv
 *
 * # Or, to broadcast a transaction.
 * forge script script/DeployDynamicLevelModelFactory.s.sol \
 *   --rpc-url "http://127.0.0.1:8545" \
 *   --private-key $OWNER_PRIVATE_KEY \
 *   --broadcast \
 *   -vvvv
 * ```
 */
contract DeployModelFactories is Script {
  /// @notice Deploys all the Model Factory contracts
  function run() public {
    console2.log("Deploying Cozy V2 Model Factories...");

    console2.log("  Deploying CostModelDynamicLevelFactory...");
    vm.broadcast();
    address costModelDynamicLevelFactory = address(new CostModelDynamicLevelFactory());
    console2.log("  CostModelDynamicLevelFactory deployed,", costModelDynamicLevelFactory);

    console2.log("Finished deploying Cozy V2 Dynamic Level Model Factories");
  }
}
