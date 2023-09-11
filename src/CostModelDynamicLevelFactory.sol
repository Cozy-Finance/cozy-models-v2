// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.18;

import "src/CostModelDynamicLevel.sol";
import "src/abstract/BaseModelFactory.sol";
import "src/lib/Create2.sol";

/**
 * @notice The factory for deploying a CostModelDynamicLevel contract.
 */
contract CostModelDynamicLevelFactory is BaseModelFactory {
  /// @notice Event that indicates a CostModelDynamicLevel has been deployed.
  event DeployedCostModelDynamicLevel(
    address indexed costModel,
    uint256 uLow,
    uint256 uHigh,
    uint256 costFactorAtZeroUtilization,
    uint256 costFactorAtFullUtilization,
    uint256 costFactorInOptimalZone,
    uint256 dailyOptimalZoneRate
  );

  /// @notice Deploys a CostModelDynamicLevel contract and emits a
  /// DeployedCostModelDynamicLevel event that indicates what the params from the deployment are.
  /// @return model_ which has an address.
  function deployModel(
    uint256 uLow_,
    uint256 uHigh_,
    uint256 costFactorAtZeroUtilization_,
    uint256 costFactorAtFullUtilization_,
    uint256 costFactorInOptimalZone_,
    uint256 dailyOptimalZoneRate_,
    bytes32 baseSalt_
  ) external returns (CostModelDynamicLevel model_) {
    model_ = new CostModelDynamicLevel{salt: baseSalt_}({
          uLow_: uLow_,
          uHigh_: uHigh_,
          costFactorAtZeroUtilization_: costFactorAtZeroUtilization_,
          costFactorAtFullUtilization_: costFactorAtFullUtilization_,
          costFactorInOptimalZone_: costFactorInOptimalZone_,
          dailyOptimalZoneRate_: dailyOptimalZoneRate_
        }
    );
    emit DeployedCostModelDynamicLevel(
      address(model_),
      uLow_,
      uHigh_,
      costFactorAtZeroUtilization_,
      costFactorAtFullUtilization_,
      costFactorInOptimalZone_,
      dailyOptimalZoneRate_
      );
  }

  /// @notice Call this function to determine the address at which a model
  /// with the supplied configuration would be deployed.
  function computeModelAddress(
    uint256 uLow_,
    uint256 uHigh_,
    uint256 costFactorAtZeroUtilization_,
    uint256 costFactorAtFullUtilization_,
    uint256 costFactorInOptimalZone_,
    uint256 dailyOptimalZoneRate_,
    bytes32 baseSalt_
  ) external view returns (address address_) {
    bytes memory modelConstructorArgs_ =
      abi.encode(uLow_, uHigh_, costFactorAtZeroUtilization_, costFactorAtFullUtilization_, costFactorInOptimalZone_, dailyOptimalZoneRate_);

    address_ = Create2.computeCreate2Address(
      type(CostModelDynamicLevel).creationCode, modelConstructorArgs_, address(this), baseSalt_
    );
  }
}
