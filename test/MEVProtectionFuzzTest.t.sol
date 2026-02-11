// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "../lib/forge-std/src/Test.sol";
import {MEVProtection} from "../src/MEVProtection.sol";
import {deployMEVProtection} from "../script/DeployMEVProtection.s.sol";
import {StdInvariant} from "lib/forge-std/src/StdInvariant.sol";


contract MEVProtectionFuzzTest is Test {


    deployMEVProtection deployMEV;
    MEVProtection mevProtection;
    address wETH;
    address wBTC;
    address fuzzUser;
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

        fuzzUser = makeAddr("fuzzUser");
        vm.deal(fuzzUser, 1000 ether);
        console.log(fuzzUser);

        bytes4[] memory selector = new bytes4[](2);
        selector[0] = mevProtection.commitTrade.selector;
        selector[1] = mevProtection.revealTrade.selector;

        targetContract(address(mevProtection));

    //     targetSelector(
    //         FuzzSelector({
    //             addr: address(mevProtection),
    //             selectors: selector
    //         })
    //     );
    // }
    }


    function _hashCommit(address user, uint256 amountIn, uint256 minAmountOut, address tokenInX, address tokenOut, bytes32 nonce) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(user, amountIn, minAmountOut, tokenInX, tokenOut, nonce));
    }

    function testFuzzCommit_Reveal_Claim(uint256 amountIn, uint256 minAmountOut, bytes32 nonce) public {

        address user = fuzzUser;
        address tokenInX = wETH;
        address tokenOut = wBTC;

        vm.assume(amountIn > 0 && amountIn < 100 ether);
        vm.assume(minAmountOut > 0);

        amountIn = bound(amountIn, 1, 100 ether);
        minAmountOut = bound(minAmountOut, 1, amountIn);

        bytes32 hash = _hashCommit(user, amountIn, minAmountOut, tokenInX, tokenOut, nonce);

        vm.startPrank(user);
        bytes32 id = mevProtection.commitTrade{value: commitDeposit}(tokenInX, tokenOut, hash);
        vm.roll(block.number + 5);
        mevProtection.revealTrade(id, amountIn, minAmountOut, nonce);

        uint256 preClaimBalance = mevProtection.getCommitDepositValue();
        mevProtection.claimDeposit();
        uint256 postClaimBalance = mevProtection.getCommitDepositValue();

        assertEq(preClaimBalance, 0.1 ether);
        assertEq(postClaimBalance, 0 ether);
    }


}

