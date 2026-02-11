// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "../lib/forge-std/src/Test.sol";
import {console} from "../lib/forge-std/src/console.sol";
import {MEVProtection} from "../src/MEVProtection.sol";
import {AMM} from "../src/AMM.sol";
import {HelperConfig} from "../script/HelperConfig.sol";
import {MOCKERC20LUQ} from "../src/MockMint.sol";
import {MOCKERC20TOG} from "../src/MockMint.sol";
import {LPERC20} from "../src/LPToken.sol";
import {StdInvariant} from "lib/forge-std/src/StdInvariant.sol";

contract AMMUnitTest is Test {

    AMM amm;
    MEVProtection mevProtection;
    MOCKERC20LUQ mockERC201;
    MOCKERC20TOG mockERC202;
    LPERC20 lperc20;
    address user1;
    
    uint256 constant FEE_DENOMINATOR = 1000;
    uint256 constant FEE_NUMERATOR = 997; // 0.3% fee

    function setUp() public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.activeNetworkConfig memory cfg = helperConfig.getActiveNetworkConfig();
        mevProtection = new MEVProtection(cfg.commitDeposit);
        amm = new AMM(address(mevProtection));
        mockERC201 = new MOCKERC20LUQ();
        mockERC202 = new MOCKERC20TOG();

        user1 = makeAddr("user1");
        vm.deal(user1, 100 ether);
    }

    function _getCommitHash(address user, uint256 amountIn, uint256 amountOut, address tokenIn, address tokenOut, bytes32 nonce) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(user, amountIn, amountOut, tokenIn, tokenOut, nonce));
    }

    function testFuzz_invariantsHold_ADD_REMOVE_LIQUIDITY(uint256 amountIn, bool swapDirection) public {
        amountIn = bound(amountIn, 1e6, 1e23);

        address tokenIn = swapDirection ? address(mockERC201) : address(mockERC202);
        address tokenOut = swapDirection ? address(mockERC202) : address(mockERC201);

        mockERC201.mint(user1, (amountIn*2));
        mockERC202.mint(user1, (amountIn*2));

        vm.startPrank(user1);

        mockERC201.approve(address(amm), amountIn);
        mockERC202.approve(address(amm), amountIn);

        amm.createPool(tokenIn, tokenOut);
        bytes32 poolID = amm.getPool(tokenIn, tokenOut);

        amm.addLiquidity(poolID, amountIn, amountIn);

        uint256 removeAmount = (amountIn * FEE_NUMERATOR) / FEE_DENOMINATOR;
        amm.removeLiquidity(poolID, removeAmount);
        
    }


}

