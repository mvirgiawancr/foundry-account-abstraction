// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract DeployMinimal is Script {
    HelperConfig private helperConfig;
    MinimalAccount private minimalAccount;

    function run() external returns (HelperConfig, MinimalAccount) {
        (helperConfig, minimalAccount) = deployMinimalAccount();
        return (helperConfig, minimalAccount);
    }

    function deployMinimalAccount() public returns (HelperConfig, MinimalAccount) {
        helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        vm.startBroadcast(config.account);
        minimalAccount = new MinimalAccount(config.entryPoint);
        vm.stopBroadcast();

        return (helperConfig, minimalAccount);
    }
}
