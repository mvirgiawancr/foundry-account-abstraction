// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {Test, console2} from "forge-std/Test.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {DeployMinimal} from "script/DeployMinimal.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {SendPackedUserOp, PackedUserOperation} from "script/SendPackedUserOp.s.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract MinimalAccountTest is Test {
    using MessageHashUtils for bytes32;

    HelperConfig private config;
    MinimalAccount private minimalAccount;
    ERC20Mock private usdc;
    uint256 private constant AMOUNT = 1e18;
    address randomUser = makeAddr("randomUser");
    SendPackedUserOp private sendPackedUserOp;

    function setUp() public {
        DeployMinimal deployer = new DeployMinimal();
        (config, minimalAccount) = deployer.run();
        usdc = new ERC20Mock();
        sendPackedUserOp = new SendPackedUserOp();
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

    function testRecoverUserOp() public {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address destination = address(usdc);
        uint256 value = 0;
        bytes memory data = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
        bytes memory executeCallData = abi.encodeWithSelector(MinimalAccount.execute.selector, destination, value, data);
        PackedUserOperation memory userOp =
            sendPackedUserOp.generateSignedUserOperation(executeCallData, config.getConfig(), address(minimalAccount));
        bytes32 userOperationHash = IEntryPoint(config.getConfig().entryPoint).getUserOpHash(userOp);

        address actualSigner = ECDSA.recover(userOperationHash.toEthSignedMessageHash(), userOp.signature);

        assertEq(actualSigner, minimalAccount.owner(), "Signer should be the owner of the account");
    }

    function testValidationOfUserOp() public {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address destination = address(usdc);
        uint256 value = 0;
        bytes memory data = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
        bytes memory executeCallData = abi.encodeWithSelector(MinimalAccount.execute.selector, destination, value, data);
        PackedUserOperation memory userOp =
            sendPackedUserOp.generateSignedUserOperation(executeCallData, config.getConfig(), address(minimalAccount));
        bytes32 userOperationHash = IEntryPoint(config.getConfig().entryPoint).getUserOpHash(userOp);
        uint256 missingAccountFunds = 1e18;

        vm.startPrank(config.getConfig().entryPoint);
        uint256 validationData = minimalAccount.validateUserOp(userOp, userOperationHash, missingAccountFunds);
        vm.stopPrank();
        assertEq(validationData, 0, "Validation data should be zero for a valid user operation");
    }

    function testEntryPointCanExecuteCommands() public {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address destination = address(usdc);
        uint256 value = 0;
        bytes memory data = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
        bytes memory executeCallData = abi.encodeWithSelector(MinimalAccount.execute.selector, destination, value, data);
        PackedUserOperation memory userOp =
            sendPackedUserOp.generateSignedUserOperation(executeCallData, config.getConfig(), address(minimalAccount));

        vm.deal(address(minimalAccount), 1e18);

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        vm.prank(randomUser);
        IEntryPoint(config.getConfig().entryPoint).handleOps(userOps, payable(randomUser));

        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }
}
