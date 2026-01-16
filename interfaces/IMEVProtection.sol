// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IMEVProtection
 * @notice Interface for MEV protection mechanisms in AMM
 * @dev Combines commit-reveal, JIT liquidity, and trade execution protection
 */
interface IMEVProtection {
    // =============== Events ===============

    /**
     * @dev Emitted when a trade commitment is made
     * @param commitmentId Unique identifier for the commitment
     * @param trader Address of the trader
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @param commitBlock Block number when commitment was made
     */
    event TradeCommitted(
        bytes32 indexed commitmentId, address indexed trader, address tokenIn, address tokenOut, uint256 commitBlock
    );

    /**
     * @dev Emitted when a trade is revealed and executed
     * @param commitmentId Unique identifier for the commitment
     * @param trader Address of the trader
     * @param amountIn Actual input amount
     * @param amountOut Actual output amount
     * @param fee Protection fee charged
     */
    event TradeRevealed(
        bytes32 indexed commitmentId, address indexed trader, uint256 amountIn, uint256 amountOut, uint256 fee
    );

    /**
     * @dev Emitted when JIT liquidity is added
     * @param provider Address providing JIT liquidity
     * @param tokenA First token in pair
     * @param tokenB Second token in pair
     * @param amountA Amount of tokenA added
     * @param amountB Amount of tokenB added
     * @param expiryBlock Block when liquidity expires
     */
    event JITLiquidityAdded(
        address indexed provider,
        address indexed tokenA,
        address indexed tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 expiryBlock
    );

    /**
     * @dev Emitted when a sandwich attack is detected
     * @param attacker Address attempting the attack
     * @param victim Victim trader address
     * @param prevented Whether attack was prevented
     * @param penalty Penalty applied to attacker
     */
    event MEVAttackDetected(address indexed attacker, address indexed victim, bool prevented, uint256 penalty);

    // =============== Structs ===============

    /**
     * @dev Commitment structure for commit-reveal scheme
     * @param trader Address of the trader
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @param commitHash Hash of trade details (amountIn, minAmountOut, deadline, salt)
     * @param commitBlock Block number when committed
     * @param revealed Whether trade has been revealed
     */
    struct TradeCommitment {
        address trader;
        address tokenIn;
        address tokenOut;
        bytes32 commitHash;
        uint256 commitBlock;
        bool revealed;
    }

    /**
     * @dev JIT liquidity position
     * @param provider Address providing liquidity
     * @param amountA Amount of tokenA
     * @param amountB Amount of tokenB
     * @param addedBlock Block when added
     * @param expiryBlock Block when position expires
     * @param isActive Whether position is active
     */
    struct JITPosition {
        address provider;
        uint256 amountA;
        uint256 amountB;
        uint256 addedBlock;
        uint256 expiryBlock;
        bool isActive;
    }

    /**
     * @dev Trade execution parameters
     * @param amountIn Amount of input token
     * @param minAmountOut Minimum acceptable output
     * @param deadline Latest block for execution
     * @param salt Random salt for commitment
     * @param useJIT Whether to use JIT liquidity
     */
    struct TradeParams {
        uint256 amountIn;
        uint256 minAmountOut;
        uint256 deadline;
        bytes32 salt;
        bool useJIT;
    }

    /**
     * @dev Protection configuration
     * @param commitDelayBlocks Minimum blocks between commit and reveal
     * @param maxCommitAgeBlocks Maximum age of commitment before expiry
     * @param jitLiquidityDurationBlocks Duration of JIT liquidity positions
     * @param protectionFeeBps Fee for MEV protection (basis points)
     * @param minTradeSizeForCommit Minimum trade size requiring commit-reveal
     * @param maxPriceImpactBps Maximum allowed price impact (basis points)
     */
    struct ProtectionConfig {
        uint256 commitDelayBlocks;
        uint256 maxCommitAgeBlocks;
        uint256 jitLiquidityDurationBlocks;
        uint16 protectionFeeBps;
        uint256 minTradeSizeForCommit;
        uint16 maxPriceImpactBps;
    }

    // =============== State Getters ===============

    /**
     * @notice Get protection configuration
     * @return config Current protection configuration
     */
    function getProtectionConfig() external view returns (ProtectionConfig memory config);

    /**
     * @notice Get trade commitment details
     * @param commitmentId The commitment identifier
     * @return commitment Commitment details
     */
    function getCommitment(bytes32 commitmentId) external view returns (TradeCommitment memory commitment);

    /**
     * @notice Check if a commitment is valid and can be revealed
     * @param commitmentId The commitment identifier
     * @return isValid True if commitment is valid and can be revealed
     */
    function isValidCommitment(bytes32 commitmentId) external view returns (bool isValid);

    /**
     * @notice Get active JIT positions for a token pair
     * @param tokenA First token address
     * @param tokenB Second token address
     * @return positions Array of active JIT positions
     */
    function getActiveJITPositions(address tokenA, address tokenB)
        external
        view
        returns (JITPosition[] memory positions);

    /**
     * @notice Estimate protection fee for a trade
     * @param amountIn Trade input amount
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @return feeAmount Estimated protection fee amount
     */
    function estimateProtectionFee(uint256 amountIn, address tokenIn, address tokenOut)
        external
        view
        returns (uint256 feeAmount);

    /**
     * @notice Check if address has pending commitments
     * @param trader Trader address to check
     * @return hasPending True if trader has pending commitments
     */
    function hasPendingCommitments(address trader) external view returns (bool hasPending);

    // =============== User Functions ===============

    /**
     * @notice Commit to a trade (for large trades)
     * @dev Creates a commitment that can be revealed after commitDelayBlocks
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @param commitHash Hash of trade parameters
     * @return commitmentId Unique identifier for the commitment
     */
    function commitTrade(address tokenIn, address tokenOut, bytes32 commitHash) external returns (bytes32 commitmentId);

    /**
     * @notice Reveal and execute a committed trade
     * @dev Must be called after commitDelayBlocks and before maxCommitAgeBlocks
     * @param commitmentId The commitment identifier
     * @param amountIn Actual input amount
     * @param minAmountOut Minimum acceptable output
     * @param deadline Latest block for execution
     * @param salt Random salt used in commitment
     */
    function revealAndExecuteTrade(
        bytes32 commitmentId,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline,
        bytes32 salt
    ) external returns (uint256 amountOut);

    /**
     * @notice Execute trade directly (for small trades)
     * @dev Bypasses commit-reveal for trades below minTradeSizeForCommit
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @param amountIn Amount of input token
     * @param minAmountOut Minimum acceptable output
     * @param deadline Latest block for execution
     * @param useJIT Whether to use JIT liquidity
     * @return amountOut Amount of output token received
     */
    function executeTradeDirect(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline,
        bool useJIT
    ) external returns (uint256 amountOut);

    /**
     * @notice Add JIT liquidity for MEV protection
     * @dev Provides temporary liquidity that expires after jitLiquidityDurationBlocks
     * @param tokenA First token address
     * @param tokenB Second token address
     * @param amountA Amount of tokenA to provide
     * @param amountB Amount of tokenB to provide
     * @return positionId Unique identifier for the position
     */
    function addJITLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB)
        external
        returns (uint256 positionId);

    /**
     * @notice Remove JIT liquidity (after expiry)
     * @param positionId The JIT position identifier
     * @param tokenA First token address
     * @param tokenB Second token address
     * @return amountA Amount of tokenA returned
     * @return amountB Amount of tokenB returned
     */
    function removeJITLiquidity(uint256 positionId, address tokenA, address tokenB)
        external
        returns (uint256 amountA, uint256 amountB);

    // =============== Protection Functions ===============

    /**
     * @notice Validate trade for MEV protection
     * @dev Called by AMM before execution
     * @param trader Trader address
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @param amountIn Input amount
     * @param amountOut Output amount
     * @return allowed Whether trade is allowed
     * @return fee Protection fee to charge
     */
    function validateTrade(address trader, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut)
        external
        returns (bool allowed, uint256 fee);

    /**
     * @notice Detect and prevent sandwich attacks
     * @dev Monitors mempool-like patterns in same block trades
     * @param trader Trader address
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @param amountIn Input amount
     * @return isAttackDetected True if sandwich attack pattern detected
     */
    function detectSandwichAttack(address trader, address tokenIn, address tokenOut, uint256 amountIn)
        external
        returns (bool isAttackDetected);

    /**
     * @notice Check price impact before trade
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @param amountIn Input amount
     * @return priceImpactBps Estimated price impact in basis points
     */
    function checkPriceImpact(address tokenIn, address tokenOut, uint256 amountIn)
        external
        view
        returns (uint256 priceImpactBps);

    // =============== Admin Functions ===============

    /**
     * @notice Update protection configuration
     * @dev Only callable by owner/protection manager
     * @param commitDelayBlocks New commit delay in blocks
     * @param maxCommitAgeBlocks New max commit age in blocks
     * @param jitLiquidityDurationBlocks New JIT liquidity duration
     * @param protectionFeeBps New protection fee in basis points
     * @param minTradeSizeForCommit New minimum trade size for commit-reveal
     * @param maxPriceImpactBps New max price impact in basis points
     */
    function updateProtectionConfig(
        uint256 commitDelayBlocks,
        uint256 maxCommitAgeBlocks,
        uint256 jitLiquidityDurationBlocks,
        uint16 protectionFeeBps,
        uint256 minTradeSizeForCommit,
        uint16 maxPriceImpactBps
    ) external;

    /**
     * @notice Slash malicious actor for attempted MEV
     * @dev Only callable by protection system
     * @param attacker Address attempting MEV attack
     * @param penaltyAmount Amount to slash from attacker
     */
    function slashMEVAttacker(address attacker, uint256 penaltyAmount) external;

    /**
     * @notice Emergency cancel a commitment
     * @dev Only callable by owner in emergency situations
     * @param commitmentId Commitment to cancel
     */
    function emergencyCancelCommitment(bytes32 commitmentId) external;

    /**
     * @notice Withdraw collected protection fees
     * @dev Only callable by owner/treasury
     * @param token Token address to withdraw
     * @param amount Amount to withdraw
     */
    function withdrawFees(address token, uint256 amount) external;

    // =============== Utility Functions ===============

    /**
     * @notice Calculate commitment ID
     * @param trader Trader address
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @param commitHash Hash of trade parameters
     * @param commitBlock Block number of commitment
     * @return commitmentId Unique commitment identifier
     */
    function calculateCommitmentId(
        address trader,
        address tokenIn,
        address tokenOut,
        bytes32 commitHash,
        uint256 commitBlock
    ) external pure returns (bytes32 commitmentId);

    /**
     * @notice Calculate commit hash for trade parameters
     * @param amountIn Input amount
     * @param minAmountOut Minimum output amount
     * @param deadline Execution deadline
     * @param salt Random salt
     * @return commitHash Hash of trade parameters
     */
    function calculateCommitHash(uint256 amountIn, uint256 minAmountOut, uint256 deadline, bytes32 salt)
        external
        pure
        returns (bytes32 commitHash);
}
