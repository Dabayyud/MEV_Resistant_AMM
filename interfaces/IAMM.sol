// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IVWAPOracle.sol";
import "./IMEVProtection.sol";

/**
 * @title IAMM
 * @notice Interface for MEV-Resistant Automated Market Maker
 * @dev Combines AMM functionality with MEV protection and VWAP oracles
 */
interface IAMM {
    // =============== Events ===============

    /**
     * @dev Emitted when liquidity is added to a pool
     * @param provider Address providing liquidity
     * @param tokenA First token address
     * @param tokenB Second token address
     * @param amountA Amount of tokenA added
     * @param amountB Amount of tokenB added
     * @param liquidityTokens Amount of LP tokens minted
     */
    event LiquidityAdded(
        address indexed provider,
        address indexed tokenA,
        address indexed tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidityTokens
    );

    /**
     * @dev Emitted when liquidity is removed from a pool
     * @param provider Address removing liquidity
     * @param tokenA First token address
     * @param tokenB Second token address
     * @param amountA Amount of tokenA removed
     * @param amountB Amount of tokenB removed
     * @param liquidityTokens Amount of LP tokens burned
     */
    event LiquidityRemoved(
        address indexed provider,
        address indexed tokenA,
        address indexed tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidityTokens
    );

    /**
     * @dev Emitted when a swap is executed
     * @param trader Address executing swap
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @param amountIn Input amount
     * @param amountOut Output amount
     * @param fee Swap fee collected
     * @param protectionFee MEV protection fee collected
     */
    event SwapExecuted(
        address indexed trader,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fee,
        uint256 protectionFee
    );

    /**
     * @dev Emitted when a pool is created
     * @param tokenA First token address
     * @param tokenB Second token address
     * @param pool Address of the created pool
     * @param poolType Type of pool (0 = Constant Product, 1 = StableSwap)
     */
    event PoolCreated(address indexed tokenA, address indexed tokenB, address pool, uint8 poolType);

    /**
     * @dev Emitted when pool parameters are updated
     * @param tokenA First token address
     * @param tokenB Second token address
     * @param newFee New swap fee in basis points
     * @param newFeeRecipient New fee recipient address
     */
    event PoolParametersUpdated(address indexed tokenA, address indexed tokenB, uint16 newFee, address newFeeRecipient);

    // =============== Structs ===============

    /**
     * @dev Pool information structure
     * @param poolAddress Address of the pool contract
     * @param token0 First token in sorted order
     * @param token1 Second token in sorted order
     * @param reserve0 Reserve amount of token0
     * @param reserve1 Reserve amount of token1
     * @param totalLiquidity Total liquidity tokens minted
     * @param fee Swap fee in basis points (e.g., 30 = 0.3%)
     * @param poolType Type of pool (0 = Constant Product, 1 = StableSwap)
     * @param isActive Whether pool is active
     */
    struct PoolInfo {
        address poolAddress;
        address token0;
        address token1;
        uint256 reserve0;
        uint256 reserve1;
        uint256 totalLiquidity;
        uint16 fee;
        uint8 poolType;
        bool isActive;
    }

    /**
     * @dev Swap parameters
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @param amountIn Exact input amount
     * @param minAmountOut Minimum output amount (slippage protection)
     * @param deadline Latest block timestamp for execution
     * @param recipient Address to receive output tokens
     * @param useMEVProtection Whether to use MEV protection
     * @param useCommitReveal Whether to use commit-reveal scheme
     */
    struct SwapParams {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 minAmountOut;
        uint256 deadline;
        address recipient;
        bool useMEVProtection;
        bool useCommitReveal;
    }

    /**
     * @dev Liquidity parameters
     * @param tokenA First token address
     * @param tokenB Second token address
     * @param amountADesired Desired amount of tokenA to add
     * @param amountBDesired Desired amount of tokenB to add
     * @param amountAMin Minimum amount of tokenA to add
     * @param amountBMin Minimum amount of tokenB to add
     * @param recipient Address to receive LP tokens
     * @param deadline Latest block timestamp for execution
     */
    struct LiquidityParams {
        address tokenA;
        address tokenB;
        uint256 amountADesired;
        uint256 amountBDesired;
        uint256 amountAMin;
        uint256 amountBMin;
        address recipient;
        uint256 deadline;
    }

    /**
     * @dev Pool creation parameters
     * @param tokenA First token address
     * @param tokenB Second token address
     * @param fee Swap fee in basis points
     * @param poolType Type of pool (0 = Constant Product, 1 = StableSwap)
     * @param initialPrice Initial price (for stable pools, can be 0 for CPMM)
     */
    struct PoolCreationParams {
        address tokenA;
        address tokenB;
        uint16 fee;
        uint8 poolType;
        uint256 initialPrice;
    }

    /**
     * @dev AMM configuration
     * @param defaultFee Default swap fee in basis points
     * @param maxFee Maximum allowed swap fee
     * @param protocolFeeRecipient Address receiving protocol fees
     * @param protocolFeeBps Protocol fee in basis points (taken from swap fees)
     * @param minLiquidity Minimum liquidity required for pool
     * @param maxPriceImpactBps Maximum price impact allowed
     */
    struct AMMConfig {
        uint16 defaultFee;
        uint16 maxFee;
        address protocolFeeRecipient;
        uint16 protocolFeeBps;
        uint256 minLiquidity;
        uint16 maxPriceImpactBps;
    }

    // =============== State Getters ===============

    /**
     * @notice Get pool information for a token pair
     * @param tokenA First token address
     * @param tokenB Second token address
     * @return poolInfo Pool information structure
     */
    function getPool(address tokenA, address tokenB) external view returns (PoolInfo memory poolInfo);

    /**
     * @notice Check if pool exists for token pair
     * @param tokenA First token address
     * @param tokenB Second token address
     * @return exists True if pool exists
     */
    function poolExists(address tokenA, address tokenB) external view returns (bool exists);

    /**
     * @notice Get quote for swap (without executing)
     * @param amountIn Input amount
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @return amountOut Output amount
     * @return fee Swap fee amount
     * @return protectionFee MEV protection fee (if applicable)
     */
    function getQuote(uint256 amountIn, address tokenIn, address tokenOut)
        external
        view
        returns (uint256 amountOut, uint256 fee, uint256 protectionFee);

    /**
     * @notice Get reserves for a token pair
     * @param tokenA First token address
     * @param tokenB Second token address
     * @return reserveA Reserve amount of tokenA
     * @return reserveB Reserve amount of tokenB
     */
    function getReserves(address tokenA, address tokenB) external view returns (uint256 reserveA, uint256 reserveB);

    /**
     * @notice Get price from AMM (tokenB per tokenA)
     * @param tokenA First token address
     * @param tokenB Second token address
     * @return price Price of tokenA in terms of tokenB (scaled by 1e18)
     */
    function getPrice(address tokenA, address tokenB) external view returns (uint256 price);

    /**
     * @notice Get price impact for a swap
     * @param amountIn Input amount
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @return priceImpactBps Price impact in basis points
     */
    function getPriceImpact(uint256 amountIn, address tokenIn, address tokenOut)
        external
        view
        returns (uint256 priceImpactBps);

    /**
     * @notice Get AMM configuration
     * @return config Current AMM configuration
     */
    function getAMMConfig() external view returns (AMMConfig memory config);

    /**
     * @notice Get addresses of integrated modules
     * @return vwapOracle Address of VWAP oracle
     * @return mevProtection Address of MEV protection module
     */
    function getModules() external view returns (address vwapOracle, address mevProtection);

    // =============== Pool Management ===============

    /**
     * @notice Create a new liquidity pool
     * @dev Only callable by owner or approved pool creator
     * @param params Pool creation parameters
     * @return poolAddress Address of the created pool
     */
    function createPool(PoolCreationParams calldata params) external returns (address poolAddress);

    /**
     * @notice Update pool parameters
     * @dev Only callable by pool owner or AMM admin
     * @param tokenA First token address
     * @param tokenB Second token address
     * @param newFee New swap fee in basis points
     * @param newFeeRecipient New fee recipient address
     */
    function updatePoolParameters(address tokenA, address tokenB, uint16 newFee, address newFeeRecipient) external;

    /**
     * @notice Activate/deactivate a pool
     * @dev Only callable by AMM admin in emergency
     * @param tokenA First token address
     * @param tokenB Second token address
     * @param active Whether pool should be active
     */
    function setPoolActive(address tokenA, address tokenB, bool active) external;

    // =============== Liquidity Functions ===============

    /**
     * @notice Add liquidity to a pool
     * @param params Liquidity parameters
     * @return amountA Actual amount of tokenA added
     * @return amountB Actual amount of tokenB added
     * @return liquidity Amount of LP tokens minted
     */
    function addLiquidity(LiquidityParams calldata params)
        external
        returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    /**
     * @notice Remove liquidity from a pool
     * @param tokenA First token address
     * @param tokenB Second token address
     * @param liquidity Amount of LP tokens to burn
     * @param amountAMin Minimum amount of tokenA to receive
     * @param amountBMin Minimum amount of tokenB to receive
     * @param recipient Address to receive tokens
     * @param deadline Latest block timestamp for execution
     * @return amountA Amount of tokenA received
     * @return amountB Amount of tokenB received
     */
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address recipient,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    /**
     * @notice Add liquidity with asymmetric amounts (single-sided)
     * @param tokenA First token address
     * @param tokenB Second token address
     * @param amount Amount of token to add
     * @param isTokenA Whether amount is in tokenA (true) or tokenB (false)
     * @param recipient Address to receive LP tokens
     * @return amountA Amount of tokenA added
     * @return amountB Amount of tokenB added
     * @return liquidity Amount of LP tokens minted
     */
    function addLiquiditySingle(address tokenA, address tokenB, uint256 amount, bool isTokenA, address recipient)
        external
        returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    // =============== Swap Functions ===============

    /**
     * @notice Execute a swap
     * @param params Swap parameters
     * @return amountOut Output amount received
     */
    function swap(SwapParams calldata params) external returns (uint256 amountOut);

    /**
     * @notice Execute a swap with exact output
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @param amountOut Exact output amount desired
     * @param maxAmountIn Maximum input amount willing to pay
     * @param deadline Latest block timestamp for execution
     * @param recipient Address to receive output tokens
     * @param useMEVProtection Whether to use MEV protection
     * @return amountIn Input amount used
     */
    function swapExactOut(
        address tokenIn,
        address tokenOut,
        uint256 amountOut,
        uint256 maxAmountIn,
        uint256 deadline,
        address recipient,
        bool useMEVProtection
    ) external returns (uint256 amountIn);

    /**
     * @notice Execute a flash swap (borrow without collateral)
     * @dev Must repay in same transaction with fee
     * @param tokenBorrow Token to borrow
     * @param amountBorrow Amount to borrow
     * @param tokenPay Token to repay with
     * @param recipient Address to receive borrowed tokens
     * @param data Arbitrary data to pass to callback
     */
    function flashSwap(
        address tokenBorrow,
        uint256 amountBorrow,
        address tokenPay,
        address recipient,
        bytes calldata data
    ) external;

    // =============== MEV Protection Integration ===============

    /**
     * @notice Execute a swap using commit-reveal scheme
     * @param commitmentId Commitment ID from MEV protection module
     * @param amountIn Actual input amount
     * @param minAmountOut Minimum output amount
     * @param deadline Execution deadline
     * @param salt Random salt from commitment
     * @param recipient Output recipient
     * @return amountOut Output amount received
     */
    function executeCommittedSwap(
        bytes32 commitmentId,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline,
        bytes32 salt,
        address recipient
    ) external returns (uint256 amountOut);

    /**
     * @notice Update oracle with AMM price after swap
     * @dev Called internally after swaps
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @param amountIn Input amount
     * @param amountOut Output amount
     */
    function updateOracleAfterSwap(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut) external;

    // =============== Admin Functions ===============

    /**
     * @notice Update AMM configuration
     * @dev Only callable by owner/AMM admin
     * @param defaultFee New default swap fee in basis points
     * @param maxFee New maximum swap fee in basis points
     * @param protocolFeeRecipient New protocol fee recipient
     * @param protocolFeeBps New protocol fee in basis points
     * @param minLiquidity New minimum liquidity requirement
     * @param maxPriceImpactBps New maximum price impact in basis points
     */
    function updateAMMConfig(
        uint16 defaultFee,
        uint16 maxFee,
        address protocolFeeRecipient,
        uint16 protocolFeeBps,
        uint256 minLiquidity,
        uint16 maxPriceImpactBps
    ) external;

    /**
     * @notice Update module addresses
     * @dev Only callable by owner/AMM admin
     * @param vwapOracle New VWAP oracle address
     * @param mevProtection New MEV protection module address
     */
    function updateModules(address vwapOracle, address mevProtection) external;

    /**
     * @notice Withdraw protocol fees
     * @dev Only callable by protocol fee recipient
     * @param token Token address to withdraw fees for
     * @param amount Amount to withdraw
     */
    function withdrawProtocolFees(address token, uint256 amount) external;

    /**
     * @notice Emergency shutdown of a pool
     * @dev Only callable by AMM admin in emergency
     * @param tokenA First token address
     * @param tokenB Second token address
     */
    function emergencyShutdown(address tokenA, address tokenB) external;

    // =============== Callback Functions ===============

    /**
     * @notice Callback for flash swaps
     * @dev Must be implemented by flash swap initiator
     * @param tokenBorrow Token that was borrowed
     * @param amountBorrow Amount borrowed
     * @param tokenPay Token to repay with
     * @param amountPay Amount to repay
     * @param data Arbitrary data passed in flash swap
     */
    function flashSwapCallback(
        address tokenBorrow,
        uint256 amountBorrow,
        address tokenPay,
        uint256 amountPay,
        bytes calldata data
    ) external;
}
