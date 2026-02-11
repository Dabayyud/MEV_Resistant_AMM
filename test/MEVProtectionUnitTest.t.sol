// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "../lib/forge-std/src/Test.sol";
import {MEVProtection} from "../src/MEVProtection.sol";
import {deployMEVProtection} from "../script/DeployMEVProtection.s.sol";
import {console} from "../lib/forge-std/src/Console.sol";


contract MEVProtectionTest is Test {


    deployMEVProtection deployMEV;
    MEVProtection mevProtection;
    address wETH;
    address wBTC;
    address user1;
    bytes32 commitHash;
    bytes32 commitHash2;
    uint256 tokenIn = 1000000000000000000;
    uint256 mintokenOut = 500000000000000000;
    bytes32 nonce = (bytes32(uint256(67)));
    bytes32 nonce2 = (bytes32(uint256(69)));
    uint256 commitDeposit = 0.1 ether;

    function setUp() external {
        deployMEV = new deployMEVProtection();
        (mevProtection, , wETH, wBTC, commitHash, commitHash2) = deployMEV.run();

        user1 = makeAddr("user1");
        vm.deal(user1, 10 ether);
        console.log(user1);
    }

    function testCommitDepositIsSetCorrectly() public view {
        uint256 expectedDeposit = 0.1 ether;
        uint256 actualDeposit = mevProtection.getCommitDeposit();
        assertEq(expectedDeposit, actualDeposit);
    }

    function testCommitTradeGeneratesValidID() public {
        vm.prank(user1);
        bytes32 commitmentID = mevProtection.commitTrade{value: 0.1 ether}(wETH, wBTC, commitHash);
        MEVProtection.Commitment memory storageID = mevProtection.getCommitment(commitmentID);
        bytes32 committedHash = storageID.commitmentHash;
        vm.stopPrank();
        assertEq(commitHash, committedHash);
    }

    function testCommitRevealAndClaimDeposit() public {
        vm.startPrank(user1);
        bytes32 commitmentID = mevProtection.commitTrade{value: 0.1 ether}(wETH, wBTC, commitHash);
        uint256 preClaimUnrevealed = mevProtection.getCommitDepositValue();
        vm.roll(block.number + 5);
        mevProtection.revealTrade(commitmentID, tokenIn, mintokenOut, nonce);
        uint256 preClaim = mevProtection.getCommitDepositValue();
        MEVProtection.Commitment memory storageID = mevProtection.getCommitment(commitmentID);
        mevProtection.claimDeposit();
        uint256 postClaim = mevProtection.getCommitDepositValue();
        vm.stopPrank();
        assert(storageID.revealed == true);
        assert(preClaimUnrevealed == 0 ether);
        assert(preClaim == 0.1 ether);
        assert (postClaim == 0 ether);
    }

    function testReverts1() public {
        address user2 = makeAddr("user2");
        vm.startPrank(user1);
        bytes32 commitmentID = mevProtection.commitTrade{value: 0.1 ether}(wETH, wBTC, commitHash);
        vm.roll(block.number + 5);
        vm.stopPrank();
        vm.startPrank(user2);
        vm.expectRevert(abi.encodeWithSelector(MEVProtection.CommitmentUserNotFound.selector, commitmentID));
        mevProtection.revealTrade(commitmentID, tokenIn, mintokenOut, nonce);
    }

    function testReverts2() public {
        vm.startPrank(user1);
        bytes32 commitmentID = mevProtection.commitTrade{value: 0.1 ether}(wETH, wBTC, commitHash);
        vm.roll(block.number + 4);
        vm.expectRevert(abi.encodeWithSelector(MEVProtection.MinBlockThresholdNotPassed.selector, block.number));
        mevProtection.revealTrade(commitmentID, tokenIn, mintokenOut, nonce);
    }

    function testReverts3() public {
        vm.startPrank(user1);
        bytes32 commitmentID = mevProtection.commitTrade{value: 0.1 ether}(wETH, wBTC, commitHash);
        vm.roll(block.number + 51);
        vm.expectRevert(abi.encodeWithSelector(MEVProtection.CommitmentExpired.selector, (block.number)));
        mevProtection.revealTrade(commitmentID, tokenIn, mintokenOut, nonce);
    }
    
    function testReverts4() public {
        vm.startPrank(user1);
        bytes32 commitmentID = mevProtection.commitTrade{value: 0.1 ether}(wETH, wBTC, commitHash);
        vm.roll(block.number + 5);
        vm.expectRevert(abi.encodeWithSelector(MEVProtection.CommitHashAlreadyInUse.selector, commitHash));
        mevProtection.commitTrade{value: 0.1 ether}(wETH, wBTC, commitHash);

    }

    function testReverts5() public {
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(MEVProtection.InsufficientCommitDeposit.selector, commitDeposit));
        mevProtection.commitTrade{value: 0.09 ether}(wETH, wBTC, commitHash);
    }

    function testReverts6() public {
        vm.startPrank(user1);
        bytes32 commitmentID = mevProtection.commitTrade{value: 0.1 ether}(wETH, wBTC, commitHash);
        vm.roll(block.number + 5);
        mevProtection.revealTrade(commitmentID, tokenIn, mintokenOut, nonce);
        mevProtection.claimDeposit();
        vm.roll(block.number + 5);
        vm.expectRevert(abi.encodeWithSelector(MEVProtection.NoDepositToClaim.selector));
        mevProtection.claimDeposit();
    }

    function testReverts7() public {
        vm.startPrank(user1);
        bytes32 commitmentID = mevProtection.commitTrade{value: 0.1 ether}(wETH, wBTC, commitHash);
        vm.roll(block.number + 5);
        vm.expectRevert(abi.encodeWithSelector(MEVProtection.HashMismatch.selector, commitHash2, commitHash));
        mevProtection.revealTrade(commitmentID, tokenIn, mintokenOut, nonce2);

    }

    function testRevert8() public {
        vm.startPrank(user1);
        bytes32 commitmentID = mevProtection.commitTrade{value: 0.1 ether}(wETH, wBTC, commitHash);
        vm.expectRevert(abi.encodeWithSelector(MEVProtection.CommitHashAlreadyInUse.selector, commitHash));
        mevProtection.commitTrade{value: 0.1 ether}(wETH, wBTC, commitHash);
        vm.roll(block.number + 5);
        mevProtection.revealTrade(commitmentID, tokenIn, mintokenOut, nonce);
        mevProtection.commitTrade{value: 0.1 ether}(wETH, wBTC, commitHash);
    }
}

// 0x29E3b139f4393aDda86303fcdAa35F60Bb7092bF