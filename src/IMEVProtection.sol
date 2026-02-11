// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Commitment } from "./Commitment.sol";

interface IMEVProtection {
    function revealTrade(
        address user,
        bytes32 commitmentID,
        uint256 amountIn,
        uint256 minAmountOut,
        bytes32 nonce
    ) external returns (bool);

    function getCommitment(bytes32 id) external view returns (Commitment memory);

    function claimDeposit() external;
    
    function commitTrade(address user, address tokenIn, address tokenOut, bytes32 commitHash) external payable returns (bytes32 CommitmentID);

    
}