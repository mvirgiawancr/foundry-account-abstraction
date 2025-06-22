// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAccount} from "lib/account-abstraction/contracts/interfaces/IAccount.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "lib/account-abstraction/contracts/core/Helpers.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";

/**
 * @title MinimalAccount
 * @author mvirgiawancr
 * @notice This contract implements a minimal account that can be used with the Account Abstraction framework.
 * It allows the owner to execute transactions and validate user operations.
 * The account is owned by the deployer and can only be interacted with through the EntryPoint contract.
 * The account uses ECDSA signatures for validation.
 */
contract MinimalAccount is IAccount, Ownable {
    error MinimalAccount__RequireFromEntryPoint(address sender);
    error MinimalAccount__RequireFromEntryPointOrOwner(address sender);
    error MinimalAccount__CallFailed(bytes returnData);

    IEntryPoint private immutable i_entryPoint;

    /**
     * @notice Modifier to ensure that the function is called from the EntryPoint contract.
     */
    modifier requireFromEntryPoint() {
        if (msg.sender != address(i_entryPoint)) {
            revert MinimalAccount__RequireFromEntryPoint(msg.sender);
        }
        _;
    }

    modifier requireFromEntryPointOrOwner() {
        if (msg.sender != address(i_entryPoint) && msg.sender != owner()) {
            revert MinimalAccount__RequireFromEntryPointOrOwner(msg.sender);
        }
        _;
    }

    /**
     * @notice Constructor to initialize the account with the EntryPoint address.
     * @param entryPoint The address of the EntryPoint contract.
     */
    constructor(address entryPoint) Ownable(msg.sender) {
        i_entryPoint = IEntryPoint(entryPoint);
    }

    receive() external payable {}

    /**
     * @notice Executes a transaction on behalf of the account.
     * @param destination The address to call.
     * @param value The amount of ether to send.
     * @param data The calldata to send with the call.
     */
    function execute(address destination, uint256 value, bytes calldata data) external requireFromEntryPointOrOwner {
        (bool success, bytes memory returnData) = destination.call{value: value}(data);
        if (!success) {
            revert MinimalAccount__CallFailed(returnData);
        }
    }

    /**
     * @notice Validates a user operation and pays the prefund if necessary.
     * @param userOp The packed user operation to validate.
     * @param userOpHash The hash of the user operation.
     * @param missingAccountFunds The amount of funds that are missing from the account.
     * @return validationData The validation data for the user operation.
     */
    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        requireFromEntryPoint
        returns (uint256 validationData)
    {
        validationData = _validateSignature(userOp, userOpHash);
        _payPrefund(missingAccountFunds);
    }

    /**
     * @notice Validates the signature of the user operation.
     * @param userOp The packed user operation to validate.
     * @param userOpHash The hash of the user operation.
     * @return validationData The validation data for the user operation.
     */
    function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash)
        internal
        view
        returns (uint256 validationData)
    {
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        address signer = ECDSA.recover(ethSignedMessageHash, userOp.signature);
        if (signer != owner()) {
            return SIG_VALIDATION_FAILED;
        }
        return SIG_VALIDATION_SUCCESS;
    }

    /**
     * @notice Pays the prefund for the user operation if there are missing funds.
     * @param missingAccountFunds The amount of funds that are missing from the account.
     */
    function _payPrefund(uint256 missingAccountFunds) internal {
        if (missingAccountFunds != 0) {
            (bool success,) = payable(msg.sender).call{value: missingAccountFunds, gas: type(uint256).max}("");
            (success);
        }
    }
}
