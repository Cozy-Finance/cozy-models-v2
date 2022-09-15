// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.15;

import "script/ScriptUtils.s.sol";
import "src/CostModelJumpRateFactory.sol";
import "src/DecayModelConstantFactory.sol";
import "src/DripModelConstantFactory.sol";

/**
  * @notice Purpose: Local deploy, testing, and production.
  *
  * This script deploys the Model Factory contracts.
  * Before executing, the configuration section in the script should be updated.
  * The private key of an EOA that will be used for transactions in this script must be set in .env.
  *
  * To run this script:
  *
  * ```sh
  * # Start anvil, forking from the current state of the desired chain.
  * anvil --fork-url $OPTIMISM_RPC_URL
  *
  * # In a separate terminal, perform a dry run of the script.
  * forge script script/DeployModelFactories.s.sol \
  *   --rpc-url "http://127.0.0.1:8545" \
  *   -vvvv
  *
  * # Or, to broadcast a transaction.
  * forge script script/DeployModelFactories.s.sol \
  *   --rpc-url "http://127.0.0.1:8545" \
  *   --broadcast \
  *   -vvvv
  * ```
 */
contract DeployModelFactories is ScriptUtils {

  /// @notice Deploys all the Model Factory contracts
  function run() public {
    super.loadDeployerKey();

    console2.log("Deploying Cozy V2 Model Factories...");

    console2.log("  Deploying CostModelJumpRateFactory...");
    vm.broadcast(privateKey);
    address costModelFactory = address(new CostModelJumpRateFactory());
    console2.log("  CostModelJumpRateFactory deployed,", costModelFactory);

    console2.log("  Deploying DecayModelConstantFactory...");
    vm.broadcast(privateKey);
    address decayModelFactory = address(new DecayModelConstantFactory());
    console2.log("  DecayModelConstantFactory deployed,", decayModelFactory);

    console2.log("  Deploying DripModelConstantFactory...");
    vm.broadcast(privateKey);
    address dripRateFactory = address(new DripModelConstantFactory());
    console2.log("  DripModelConstantFactory deployed,", dripRateFactory);

    console2.log("Finished deploying Cozy V2 Model Factories");
  }
}
