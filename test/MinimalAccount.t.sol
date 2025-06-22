// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {Test, console2} from "forge-std/Test.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {DeployMinimal} from "script/DeployMinimal.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract MinimalAccountTest is Test {
    HelperConfig private config;
    MinimalAccount private minimalAccount;
    ERC20Mock private usdc;
    uint256 private constant AMOUNT = 1e18;
    address randomUser = makeAddr("randomUser");

    function setUp() public {
        DeployMinimal deployer = new DeployMinimal();
        (config, minimalAccount) = deployer.run();
        usdc = new ERC20Mock();
    }

    function testOwnerCanExecute() public {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address destination = address(usdc);
        uint256 value = 0;
        bytes memory data = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
        // Act
        vm.startPrank(minimalAccount.owner());
        minimalAccount.execute(destination, value, data);
        vm.stopPrank();
        console2.log(address(usdc));
        // Assert
        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }

    function testExceptOwnerCannotExecute() public {
        // Arrange
        address destination = address(usdc);
        uint256 value = 0;
        bytes memory data = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        // Act & Assert
        vm.startPrank(randomUser);
        vm.expectRevert(
            abi.encodeWithSelector(MinimalAccount.MinimalAccount__RequireFromEntryPointOrOwner.selector, randomUser)
        );
        minimalAccount.execute(destination, value, data);
        vm.stopPrank();
    }
}
