// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "../lib/forge-std/src/Test.sol";
import {MEVProtection} from "../src/MEVProtection.sol";
import {deployMEVProtection} from "../script/DeployMEVProtection.s.sol";
import {StdInvariant} from "lib/forge-std/src/StdInvariant.sol";


contract MEVProtectionTest is StdInvariant, Test {


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

    // function setUp() external {
    //     deployMEV = new deployMEVProtection(); 
    //     (mevProtection, , wETH, wBTC, commitHash, commitHash2) = deployMEV.run();

    //     user1 = makeAddr('user1');
    //     vm.deal(user1, 100 ether);

    //     bytes4[] memory selectors = new bytes4[](1);
    //     selectors[0] = mevProtection.getSumOfAllDeposits.selector; // read-only safe
    //     targetSelector(FuzzSelector({
    //         addr: address(mevProtection),
    //         selectors: selectors
    //         }));
    // }

    function setUp() external {

    mevProtection = new MEVProtection(commitDeposit);

    user1 = makeAddr("user1");
    vm.deal(user1, 100 ether);

    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = mevProtection.getSumOfAllDeposits.selector;

    targetSelector(FuzzSelector({
        addr: address(mevProtection),
        selectors: selectors
        }));

    }

    function invariantDepositNonNegative() public {
        _commitSeed(3);
        uint256 totalDeposit = mevProtection.getSumOfAllDeposits();
        assert(totalDeposit >= 0);
    }

    function _commitSeed(uint256 n) internal {
        for (uint i = 0; i < n; i++) {
            bytes32 hash = keccak256(
            abi.encodePacked(user1, tokenIn, mintokenOut, wETH, wBTC, bytes32(i))
        );

        vm.startPrank(user1);
        bytes32 commitID = mevProtection.commitTrade{value: commitDeposit}(wETH, wBTC, hash);
        vm.roll(block.number + 5);
        mevProtection.revealTrade(commitID, tokenIn, mintokenOut, bytes32(i));
        vm.stopPrank();
        }

    }
}
