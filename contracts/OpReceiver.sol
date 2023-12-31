// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import "./OpPredict.sol";

contract OpReceiver is CCIPReceiver {
    OpEggCrowns eggcrowns;

    event MessageReceived(
        bytes32 indexed messageId, // The unique ID of the message.
        uint64 indexed sourceChainSelector, // The chain selector of the source chain.
        address sender, // The address of the sender from the source chain.
        string text // The text that was received.
    );

    bytes32 private lastReceivedMessageId; // Store the last received messageId.
    string private lastReceivedText; // Store the last received text.

    /// @notice Constructor initializes the contract with the router address.
    /// @param router The address of the router contract.
    constructor(address router, address contractAddr) CCIPReceiver(router) {
        eggcrowns = OpEggCrowns(contractAddr);
    }

    /// handle a received message
    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal override {
        (bool success, ) = address(eggcrowns).call(any2EvmMessage.data);
        require(success);
    }

    function setcontractAddr(address contractAddr) public {
        eggcrowns = OpEggCrowns(contractAddr);
    }

    /// @notice Fetches the details of the last received message.
    /// @return messageId The ID of the last received message.
    /// @return text The last received text.
    function getLastReceivedMessageDetails()
        external
        view
        returns (bytes32 messageId, string memory text)
    {
        return (lastReceivedMessageId, lastReceivedText);
    }
}
