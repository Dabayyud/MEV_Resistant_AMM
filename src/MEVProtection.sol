// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// import {TWAP} from "./TWAP.sol";
import {Address} from "../lib/openzeppelin-contracts/contracts/utils/Address.sol";

contract MEVProtection {

    using Address for address;

    error CommitmentNotFound(bytes32);
    error CommitmentUserNotFound(bytes32);
    error MinBlockThresholdNotPassed(uint256);
    error TradeHasBeenRevealed();
    error HashMismatch(bytes32, bytes32);
    error CommitmentExpired(uint256);
    error CommitHashAlreadyInUse(bytes32);
    error InsufficientCommitDeposit(uint256);
    error DepositRefundFailed();
    error NoDepositToClaim();

    uint256 public immutable minimumBlocks = 5;
    uint256 public immutable maxBlocks = 50;
    uint256 public immutable commitDeposit;

    struct Commitment {
        bytes32 commitmentHash;
        address user;
        address tokenIn;
        address tokenOut;
        uint256 commitBlock;
        bool revealed;
    }

    mapping(bytes32 => Commitment) commitments;
    mapping(bytes32 => bool) usedCommitHash;
    mapping(address => uint256) public commitDeposits;

    // ----------EVENTS----------
    /**
     * @dev This event is logged when a trade is commited
     * @param commitmentId The unique identifier for the commitment
     * @param trader The addres of the trader
     * @param tokenIn The input token address
     * @param tokenOut The outpur token address
     * @param commitBlock The block of the transaction
     */
    event TradeCommitted(
        bytes32 indexed commitmentId, address indexed trader, address tokenIn, address tokenOut, uint256 commitBlock
    );

    /**
     * @dev This event is logged when a commited trade is completed
     * @param commitmentId ...
     * @param trader ...
     * @param amountIn The amount inputed
     * @param amountOut The amounr outputed
     */
    event TradeRevealed(
        bytes32 indexed commitmentId, address indexed trader, uint256 amountIn, uint256 amountOut
    );

    constructor (uint256 _commitDeposit) {
        commitDeposit = _commitDeposit;
    }

    // ----------FUNCTIONS----------
    /**
     * @dev This function creates a unique commitmentID that maps it to a struct
     * @param tokenIn ...
     * @param tokenOut ...
     * @param commitHash The users off-chain calculated commitment Hash
     */

    function commitTrade(address tokenIn, address tokenOut, bytes32 commitHash) external payable returns (bytes32 CommitmentID) {

        if (msg.value != commitDeposit) {
            revert InsufficientCommitDeposit(commitDeposit);
        }

        if (usedCommitHash[commitHash]) {
            revert CommitHashAlreadyInUse(commitHash);
        }

        usedCommitHash[commitHash] = true;

        bytes32 commitmentID = keccak256(abi.encodePacked(msg.sender, commitHash, block.number));

        commitments[commitmentID] = Commitment({
            commitmentHash: commitHash,
            user: msg.sender,
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            commitBlock: block.number,
            revealed: false
        });

        emit TradeCommitted(commitmentID, msg.sender, tokenIn, tokenOut, block.number);
        return commitmentID;
    }
    /**
     * @dev This function checks if the commitment exists then calculates the expected hash
     * @param commitmentID ...
     * @param amountIn ...
     * @param minAmountOut ...
     * @param nonce The users choice of a nonce for extra-security
     */

    function revealTrade(bytes32 commitmentID, uint256 amountIn, uint256 minAmountOut, bytes32 nonce) external {
       Commitment storage commitment = commitments[commitmentID];

       if (commitment.user == address(0)) {
        revert CommitmentNotFound(commitmentID);
       }

       if (commitment.user != msg.sender) {
        revert CommitmentUserNotFound(commitmentID);
       }

       if (block.number < (commitment.commitBlock + minimumBlocks)) {
        revert MinBlockThresholdNotPassed(block.number);
       }

       if (commitment.revealed) {
        revert TradeHasBeenRevealed();
       }

       if (block.number > commitment.commitBlock + maxBlocks) {
        revert CommitmentExpired(block.number);
       }

       bytes32 expectedHash = keccak256(abi.encodePacked(msg.sender, amountIn, minAmountOut, commitment.tokenIn, commitment.tokenOut, nonce));
       bytes32 commitHash = commitment.commitmentHash;

       if (expectedHash != commitHash) {
        revert HashMismatch(expectedHash, commitHash);
       }

       commitment.revealed = true;
       usedCommitHash[commitHash] = false;
       commitDeposits[msg.sender] += commitDeposit;
       
       emit TradeRevealed(commitmentID, msg.sender, amountIn, minAmountOut);
    }

    function claimDeposit() external {

        if (commitDeposits[msg.sender] == 0) {
            revert NoDepositToClaim();
        }

        uint256 deposit  = commitDeposits[msg.sender];
        commitDeposits[msg.sender] = 0;
        Address.sendValue(payable(msg.sender), deposit);
        
    }

    // ---------- GETTERS/TEST ----------

    function getCommitDeposit() external view returns (uint256) {
        return commitDeposit;
    }

    function getCommitment(bytes32 id) external view returns (Commitment memory) {
        return commitments[id];
    }

    function getCommitDepositValue() external view returns (uint256) {
        return commitDeposits[msg.sender];
    }

    function getSumOfAllDeposits() external view returns (uint256) {
        return (address(this).balance);
    }

}

// will integrate into dex later, this is my verison on mev resistance that works locally.