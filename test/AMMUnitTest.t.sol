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

contract AMMUnitTest is Test {
    AMM amm;
    MEVProtection mevProtection;
    MOCKERC20LUQ mockERC201;
    MOCKERC20TOG mockERC202;
    LPERC20 lperc20;

    address user1;

    function setUp() public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.activeNetworkConfig memory cfg = helperConfig.getActiveNetworkConfig();
        mevProtection = new MEVProtection(cfg.commitDeposit);
        amm = new AMM(address(mevProtection));
        mockERC201 = new MOCKERC20LUQ();
        mockERC202 = new MOCKERC20TOG();

        user1 = makeAddr("user1");
        vm.deal(user1, 100 ether);
        mockERC201.mint(user1, 10000e18);
        mockERC202.mint(user1, 10000e18);
    }

    modifier createPool() {
        vm.prank(user1);
        amm.createPool(address(mockERC201), address(mockERC202));
        _;
    }

    modifier allowTransfer() {
        vm.startPrank(user1);
        mockERC201.approve(address(amm), 5000e18);
        mockERC202.approve(address(amm), 5000e18);
        vm.stopPrank();
        _;
    }

    modifier addLiquidity() {
        vm.startPrank(user1);
        mockERC201.approve(address(amm), 5000e18);
        mockERC202.approve(address(amm), 5000e18);
        amm.createPool(address(mockERC201), address(mockERC202));
        bytes32 poolID = amm.getPool(address(mockERC201), address(mockERC202));
        amm.addLiquidity(poolID, 2500e18, 1500e18);
        vm.stopPrank();
        _;
    }


    function testIfCommitDepositofMEVIsSetCorrectly() public {
        uint256 commitDeposit = mevProtection.getCommitDeposit();
        assertEq(commitDeposit, 0.1 ether);
    }

    function testUserTokenBalances() public {
        uint256 balance1 = mockERC201.balanceOf(user1);
        uint256 balance2 = mockERC202.balanceOf(user1);
        assertEq(balance1, 10000e18);
        assertEq(balance2, 10000e18);
    }

    function testCreatePool() public createPool {
        bytes32 poolID = amm.getPool(address(mockERC201), address(mockERC202));
        bytes32 iCPoolID = _calculatePoolID(address(mockERC202), address(mockERC201));
        // By extension, if below returns true than poolID must match. Double checking the canocalization.
        bool exists = amm.checkPoolExists(poolID);
        assertEq(poolID, iCPoolID);
        assertEq(exists, true);
    }

    function testAddLiquidity() public createPool allowTransfer {
        vm.startPrank(user1);
        bytes32 poolID = amm.getPool(address(mockERC201), address(mockERC202));
        amm.addLiquidity(poolID, 20e18, 10e18);
        vm.stopPrank();
        (uint256 balance1, uint256 balance2) = amm.getReserves(poolID);
        assert(balance1 == 20e18);
        assert(balance2 == 10e18);
    }

    function testRemoveLiquidity() public addLiquidity {
        vm.startPrank(user1);
        bytes32 poolID = amm.getPool(address(mockERC201), address(mockERC202));
        LPERC20 lp = LPERC20(amm.getLPTokenAddress(poolID));
        uint256 preClaimBalance = _getBalanceOfLPToken(user1, poolID);
        console.log(preClaimBalance);
        amm.removeLiquidity(poolID, 500);
        uint256 postClaimBalance = _getBalanceOfLPToken(user1, poolID);
        console.log(postClaimBalance);
        assert(postClaimBalance < preClaimBalance);
    }

    function testSwap() public addLiquidity {
        vm.startPrank(user1);
        uint256 preSwapAmount = _getBalanceOfToken2(user1);
        amm.swap(user1, address(mockERC201), address(mockERC202), 2e18, 1e18);
        uint256 postSwapAmount = _getBalanceOfToken2(user1);
        console.log(preSwapAmount, postSwapAmount);
        assert(postSwapAmount > preSwapAmount); // swapping token1

    }

    function testSafeSwap() public addLiquidity {
        uint256 nonceUint = 1;
        bytes32 nonceBytes = bytes32(nonceUint);
        bytes32 commitHash = _getCommitHash(user1, 2e18, 1e18, address(mockERC201), address(mockERC202), nonceBytes);
        vm.startPrank(user1);
        bytes32 commitmentID = mevProtection.commitTrade{value: 0.1 ether}(user1, address(mockERC201), address(mockERC202), commitHash);
        vm.roll(6);
        uint256 preClaimBalance = _getBalanceOfToken2(user1);
        amm.swapProtected(user1, address(mockERC201), address(mockERC202), 2e18, 1e18, nonceBytes, commitmentID);
        uint256 postClaimBalance = _getBalanceOfToken2(user1);
        assert(postClaimBalance > preClaimBalance);

    }

    function _calculatePoolID(address a, address b) internal pure returns (bytes32) {
        address _L;
        address _H;
        if (a < b) {
            _L = a;
            _H = b;
        }
        _L = b;
        _H = a;
        return (keccak256(abi.encodePacked(_L,_H)));
    }

    function _getBalanceOfToken1(address user) internal view returns (uint256) {
        return (mockERC201.balanceOf(user));
    }

    function _getBalanceOfToken2(address user) internal view returns (uint256) {
        return (mockERC202.balanceOf(user));
    }

    function _getBalanceOfLPToken(address user, bytes32 poolID) internal view returns (uint256) {
       LPERC20 lp = LPERC20(amm.getLPTokenAddress(poolID));
       return lp.balanceOf(user);
    }

    function _getCommitHash(address user, uint256 amountIn, uint256 amountOut, address tokenIn, address tokenOut, bytes32 nonce) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(user, amountIn, amountOut, tokenIn, tokenOut, nonce));
    }



    // WHERE I LEFT OFF -- NEED TO FIND A WAY TO CATCH THE LOGS IN OUR TEST SUITE SO THAT WHE DONT HAVE TO CALL GETTERS
    // SPECIFICALLY, THE ADDRESS OF THE LPTOKEN SO WE CAN ASSERT AND COMPARE THE USER BALANCES (create mapping in amm) == DONE 


}
