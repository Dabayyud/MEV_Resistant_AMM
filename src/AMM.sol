/**
 * This AMM must be minimilist and simple in design
 * All of the logic must be contained within the pricefeeds and the MEV protection code
 * 
 * AMM only:
 * - Holds reserves
 * - enforces invariant
 * - transfers tokens
 * 
 * 1) canonicalization - reserve access must be deterministic tokenA/tokenB == tokenB/tokenA
 * 1.2) Track reserves 
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {SignedMath} from "lib/openzeppelin-contracts/contracts/utils/math/SignedMath.sol";
import {Strings} from "../lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {LPERC20} from "./LPToken.sol";
import {IMEVProtection} from "./IMEVProtection.sol";
import { Commitment } from "./Commitment.sol";
import {IMEVProtection} from "./IMEVProtection.sol";

contract AMM is ReentrancyGuard {

    IMEVProtection public mevProtection;

    using SafeERC20 for IERC20;
    using Math for uint256;

    uint256 tokenCount = 0;
    uint256 constant SLIPPAGEBPS = 100;
    uint256 constant MIN_LIQUIDITY = 1000;
    uint256 constant FEE_DENOMINATOR = 1000;
    uint256 constant FEE_NUMERATOR = 997; // 0.3% fee
    address constant BURN_ADDRESS = address(0xDead);

    error PoolAlreadyExists();
    error PoolDoesNotExist();
    error InputAmountDoesNotCorrelateToPoolRatio();
    error TokenPairNotFoundOrPoolNotCreated();
    error SlippageTooHigh(uint256);
    error TokensMustBeDifferent();
    error InvariantViolated(uint256, uint256);
    error PoolHasNoLiquidity();
    error InvalidToken();
    error NotEnoughLiquidity();
    error MinBlockThresholdNotPassed(uint256);

    event PoolCreated(bytes32 indexed poolID);
    event IdealAmount(uint256,uint256);
    event Receipt(bytes32 indexed receipt);
    event LPTokenAddress(address indexed LPAddress);

    struct Pool {
        address token0;
        address token1;
        uint256 reserve0;
        uint256 reserve1;
        LPERC20 lpToken;
    }

    mapping(bytes32 => Pool) public pools;
    mapping(address => mapping(address =>bytes32)) addressToPool;
    mapping(bytes32 => bool) poolExists;
    mapping(bytes32 => address) poolToLPToken; 

    constructor(address _mevProtection) {
        mevProtection = IMEVProtection(_mevProtection);
    }

    function getPoolId(address tokenA, address tokenB) internal pure returns (bytes32) {
        (address _lToken, address _HToken) = _sort(tokenA, tokenB);
        return keccak256(abi.encodePacked(_lToken, _HToken));
    }

    function createPool(address tokenA, address tokenB) external {
        if (tokenA == tokenB) {
            revert TokensMustBeDifferent();
        }
        if (IERC20(tokenA).totalSupply() == 0 || IERC20(tokenB).totalSupply() == 0) {
            revert InvalidToken();
        }
        
        bytes32 poolID = getPoolId(tokenA, tokenB);

        if (poolExists[poolID]) {
            revert PoolAlreadyExists();
        }

        emit PoolCreated(poolID);

        tokenCount += 1;
        string memory token = Strings.toString(tokenCount);
        poolExists[poolID] = true;
        (address tokenL, address tokenH)= _sort(tokenA, tokenB);
        addressToPool[tokenL][tokenH] = poolID;

        LPERC20 lp = new LPERC20("AMM LP", token);
        pools[poolID] = Pool ({
            token0: tokenL,
            token1: tokenH,
            reserve0: 0,
            reserve1: 0,
            lpToken: lp
        });
        poolToLPToken[poolID] = address(lp);
        emit LPTokenAddress(address(lp));
    }

    function addLiquidity(bytes32 poolID, uint256 amountA, uint256 amountB)  nonReentrant external returns (bytes32 receipt) {
        if (amountA == 0 || amountB == 0) revert();
        
        Pool storage pool = pools[poolID];
        if (!poolExists[poolID]) {
            revert PoolDoesNotExist();
        }

        SafeERC20.safeTransferFrom(IERC20(pool.token0), msg.sender, address(this), amountA);
        SafeERC20.safeTransferFrom(IERC20(pool.token1), msg.sender, address(this), amountB);

        uint256 balanceInA = (IERC20(pool.token0).balanceOf(address(this)));
        uint256 balanceInB = (IERC20(pool.token1).balanceOf(address(this)));
        uint256 actualAmountA = balanceInA - (pool.reserve0);
        uint256 actualAmountB = balanceInB - (pool.reserve1);

        if (pool.reserve0 == 0 && pool.reserve1 == 0) {
            uint256 initialLiquidity = Math.sqrt(actualAmountA * actualAmountB);
            pool.reserve0 += actualAmountA;
            pool.reserve1 += actualAmountB;

            if (initialLiquidity <= MIN_LIQUIDITY) {
                revert NotEnoughLiquidity();
            }

            pool.lpToken.mint(BURN_ADDRESS, MIN_LIQUIDITY);
            pool.lpToken.mint(msg.sender, initialLiquidity - MIN_LIQUIDITY);

            emit Receipt(keccak256(abi.encodePacked(actualAmountA, actualAmountB, poolID)));
            return keccak256(abi.encodePacked(actualAmountA, actualAmountB, poolID));
        }

        uint256 liquidityA = actualAmountA * pool.lpToken.totalSupply()/ pool.reserve0;
        uint256 liquidityB = actualAmountB * pool.lpToken.totalSupply()/ pool.reserve1;
        uint256 liquidity = Math.min(liquidityA, liquidityB);

        pool.reserve0 += actualAmountA;
        pool.reserve1 += actualAmountB;

        pool.lpToken.mint(msg.sender, liquidity);
        
        return keccak256(abi.encodePacked(actualAmountA, actualAmountB, poolID));

        // using the sqrt, it does not matter it the user deposits 1 eth for 10 usdc or the other way round
        // because they will still be minted the same amount of lp tokens regarless of the input.
        // Therefore, the wouldn't want to take the risk of thier value being drawn out by arbritrage bots.
        // When new users provide liquidity, they take the min amount of the ratio
        // this forces liquidity providers to deposit tokens in the exact same ratio
        // as regardless of the amount of input, they will be give the min.
    }

    function removeLiquidity(bytes32 poolID, uint256 liquidity) nonReentrant external returns (bool) {
        if (liquidity == 0 ) {
            revert();
        }
        Pool storage pool = pools[poolID];

        if (!poolExists[poolID]) {
            revert PoolDoesNotExist();
        }

        if (pool.reserve0 == 0 || pool.reserve1 == 0 ) {
            revert PoolHasNoLiquidity();
        }

        uint256 amountA = liquidity * pool.reserve0 / pool.lpToken.totalSupply();
        uint256 amountB = liquidity * pool.reserve1 / pool.lpToken.totalSupply();

        pool.reserve0 -= amountA;
        pool.reserve1 -= amountB;

        pool.lpToken.burn(msg.sender, liquidity);
        SafeERC20.safeTransfer(IERC20(pool.token0), msg.sender, amountA);
        SafeERC20.safeTransfer(IERC20(pool.token1), msg.sender, amountB);
        return true;
    }

    function swap(address user, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOutAMin) public nonReentrant {
        _executeSwap(user, tokenIn, tokenOut, amountIn, amountOutAMin);
    }

    function _executeSwap(address user, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOutAMin) internal {
        if (amountIn == 0) {
            revert();
        }
        (address tokenL, address tokenH) = _sort(tokenIn, tokenOut);

        if (addressToPool[tokenL][tokenH] == bytes32(0)) {
            revert TokenPairNotFoundOrPoolNotCreated();
        }
        bytes32 poolID = addressToPool[tokenL][tokenH];
        Pool storage pool = pools[poolID];

        uint256 reserveIn;
        uint256 reserveOut;

        if (tokenIn == pool.token0) {
            reserveIn = pool.reserve0;
            reserveOut = pool.reserve1;

        } else {
            reserveIn = pool.reserve1;
            reserveOut = pool.reserve0;
        }

        if (reserveIn == 0 || reserveOut == 0) {
            revert PoolHasNoLiquidity();
        }

        SafeERC20.safeTransferFrom(IERC20(tokenIn), user, address(this), amountIn);

        // (x + Δx) * (y - Δy) = k
        // Δy = (y * Δx) / (x + Δx)

        uint256 balanceIn = IERC20(tokenIn).balanceOf(address(this));
        uint256 actualAmountIn = balanceIn - reserveIn;

        uint256 amountOut = ((actualAmountIn * FEE_NUMERATOR) * reserveOut) / (reserveIn * FEE_DENOMINATOR + (actualAmountIn * FEE_NUMERATOR));
        if (amountOut >= reserveOut) {
            revert NotEnoughLiquidity();
        }
        if (amountOutAMin > amountOut) {
            revert SlippageTooHigh(amountOut);
        }
        if (tokenIn == pool.token0) {
            pool.reserve0 += actualAmountIn;
            pool.reserve1 -= amountOut;

        } else {
            pool.reserve1 += actualAmountIn;
            pool.reserve0 -= amountOut;
        }
        if (IERC20(tokenIn).balanceOf(address(this)) != (reserveIn + actualAmountIn)) {
            revert();
        }

        SafeERC20.safeTransfer(IERC20(tokenOut), user, amountOut);
    } 

    function swapProtected(address user, address tokenIn, address tokenOut, uint256 amountIn, uint256 minAmountOut, bytes32 nonce, bytes32 commitmentID) nonReentrant public {
        if (!mevProtection.revealTrade(user, commitmentID, amountIn, minAmountOut, nonce)) {
            revert MinBlockThresholdNotPassed(block.number);
        }
        return _executeSwap(user,tokenIn, tokenOut, amountIn, minAmountOut);
    }

    function getCommitment(bytes32 ID) public view returns (Commitment memory) {
        return mevProtection.getCommitment(ID);
    }

    function _sort(address a , address b) internal pure returns (address, address) {
        return  a < b ? (a, b) : (b, a);
    }

    function isContract(address addr) public view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }

    function checkIfPoolAndTokensMatch(bytes32 poolID, address tokenA, address tokenB) external pure returns (bool) {
        bytes32 expectedHash = getPoolId(tokenA, tokenB);
        return (expectedHash == poolID);
    }
    // GETTERS 

    function getReserves(bytes32 poolID) public view returns(uint256, uint256){
        Pool memory pool = pools[poolID];
        return (pool.reserve0, pool.reserve1);
    }

    function checkPoolExists(bytes32 poolID) public view returns (bool) {
        return poolExists[poolID];
    }


    function getPool(address tokenA, address tokenB) public view returns(bytes32) {
        (address tokenL, address tokenH) = _sort(tokenA, tokenB);
        bytes32 hash = addressToPool[tokenL][tokenH];
        if (hash == 0){
            revert PoolDoesNotExist();
        }
        return hash;
    }

    function getLPTokenAddress(bytes32 poolID) external view returns (address) {
        return poolToLPToken[poolID];
    }

}
