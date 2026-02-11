// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;


struct Commitment {
    bytes32 commitmentHash;
    address user;
    address tokenIn; 
    address tokenOut;
    uint256 timestamp;
    bool revealed;
}
