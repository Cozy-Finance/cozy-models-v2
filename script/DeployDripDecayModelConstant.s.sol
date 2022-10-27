// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "script/ScriptUtils.sol";
import "src/DripDecayModelConstantFactory.sol";

/**
  * @notice Purpose: Local deploy, testing, and production.
  *
  * This script deploys a DripDecayModelConstant contract.
  * Before executing, the input json file `script/input/<chain-id>/deploy-decay-model-constant-<test or production>.json`
  * should be reviewed.
  *
  * To run this script:
  *
  * ```sh
  * # Start anvil, forking from the current state of the desired chain.
  * anvil --fork-url $OPTIMISM_RPC_URL
  *
  * # In a separate terminal, perform a dry run of the script.
  * forge script script/DeployDecayModelConstant.s.sol \
  *   --sig "run(string)" "deploy-decay-model-constant-<test or production>"
  *   --rpc-url "http://127.0.0.1:8545" \
  *   -vvvv
  *
  * # Or, to broadcast a transaction.
  * forge script script/DeployDecayModelConstant.s.sol \
  *   --sig "run(string)" "deploy-decay-model-constant-<test or production>"
  *   --rpc-url "http://127.0.0.1:8545" \
  *   --private-key $OWNER_PRIVATE_KEY \
  *   --broadcast \
  *   -vvvv
  * ```
 */
contract DeployDripDecayModelConstant is ScriptUtils {
  using stdJson for string;

  // -----------------------------------
  // -------- Configured Inputs --------
  // -----------------------------------

  // For calculating the per-second decay rate, we use the exponential decay formula A = P * (1 - r) ^ t
  // where A is final amount, P is principal (starting) amount, r is the per-second decay rate, and t is the number of elapsed seconds.
  // For example, for an annual decay rate of 25%:
  // A = P * (1 - r) ^ t
  // 0.75 = 1 * (1 - r) ^ 31557600
  // -r = 0.75^(1/31557600) - 1
  // -r = -9.116094732822280932149636651070655494101566187385032e-9
  // Multiplying r by -1e18 to calculate the scaled up per-second value required by decay model constructors ~= 9116094774
  uint256 dripDecayRatePerSecond;

  DripDecayModelConstantFactory factory;

  // ---------------------------
  // -------- Execution --------
  // ---------------------------

  function run(string memory _fileName) public {
    string memory _json = readInput(_fileName);

    factory = DripDecayModelConstantFactory(_json.readAddress(".factory"));
    dripDecayRatePerSecond = _json.readUint(".dripDecayRatePerSecond");

    console2.log("Deploying DripDecayModelConstant...");
    console2.log("    factory", address(factory));
    console2.log("    decayRatePerSecond", dripDecayRatePerSecond);

    address _availableModel = factory.getModel(dripDecayRatePerSecond);

    if (_availableModel == address(0)) {
      vm.broadcast();
      _availableModel = address(factory.deployModel(dripDecayRatePerSecond));
      console2.log("New DripDecayModelConstant deployed");
    } else {
      // A DripDecayModelConstant exactly like the one you wanted already exists!
      // Since models can be re-used, there's no need to deploy a new one.
      console2.log("Found existing DripDecayModelConstant with specified configs.");
    }

    console2.log(
      "Your DripDecayModelConstant is available at this address:",
      _availableModel
    );
  }
}