// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IPoolManager} from "lib/v4-core/src/interfaces/IPoolManager.sol";
import {PoolId} from "lib/v4-core/src/types/PoolId.sol";
import {StateLibrary} from "lib/v4-core/src/libraries/StateLibrary.sol";


using StateLibrary for IPoolManager;

contract UniswapV4DataFetch {

error tokenAddressIsIdentical();

uint24 constant FEE_TIER = 500;
uint32 constant STALE_THRESHOLD = 60;
address constant NO_HOOKS = 0x0000000000000000000000000000000000000000;
int24 constant STANDARD_TICK_SPACING = 60;

int56[] secondsAgos;


IPoolManager public immutable poolManager;


constructor(IPoolManager _poolManager) {
    poolManager = _poolManager;

}

struct PoolKey {
    address currency0;
    address currency1;
    uint24 fee;
    int24 tickSpacing;
    address hooks;
}


function getUniswapV4SpotPrice(address tokenA, address tokenB) public view returns (uint256 price) {

    if (tokenA == tokenB) {
        revert tokenAddressIsIdentical();
    }
    
    address currency0 = tokenA < tokenB ? tokenA : tokenB;
    address currency1 = tokenA < tokenB ? tokenB : tokenA;

    PoolKey memory key = PoolKey({
        currency0: currency0,
        currency1: currency1,
        fee: FEE_TIER,
        tickSpacing: STANDARD_TICK_SPACING,
        hooks: NO_HOOKS
    });

    bytes32 poolIdHash = calculatePoolId(key);
    PoolId poolId = PoolId.wrap(poolIdHash); // 
    (uint160 sqrtPriceX96, , , ) = poolManager.getSlot0(poolId);
    return _convertSqrtPriceToPrice(sqrtPriceX96);

}

function _convertSqrtPriceToPrice(uint160 _sqrtPriceX96) internal pure returns (uint256) {
    uint256 spotPrice = (uint256(_sqrtPriceX96) * uint256(_sqrtPriceX96) * 1e18) >> 192;
    return spotPrice;
}

function calculatePoolId(PoolKey memory poolKey) public pure returns (bytes32 poolId) {
        // Uniswap V4 specific assembly block for correct hashing of the struct
        assembly ("memory-safe") {
            poolId := keccak256(poolKey, 0xa0)
        }
        return poolId;
}

function getPoolKeyFromAddress(address tokenA, address tokenB) public pure returns (PoolKey memory poolKey) {
    address currency0 = tokenA > tokenB ? tokenB : tokenA;
    address currency1 = tokenA > tokenB ? tokenA : tokenB;

    PoolKey memory key = PoolKey({
        currency0: currency0,
        currency1: currency1,
        fee: FEE_TIER,
        tickSpacing: STANDARD_TICK_SPACING,
        hooks: NO_HOOKS
    }); 

    return key;
}

}