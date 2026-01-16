// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IUniswapV3Factory} from "lib/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {TickMath} from "Math/TickMath.sol";
import {FullMath} from "Math/FullMath.sol";

contract UniswapV3DataFetch {

    /** @dev This price feed is only effective with very liquid pairs (Fee Tier 5%). 
     * This price feed will be used in the MEV resistant AMM.
     * It has a spot price and a TWAP.
     * It already integrates a staleness check for both.
    */

    uint24 constant FEE_TIER = 500;
    uint32 constant STALE_THRESHOLD = 60;


    IUniswapV3Factory constant factory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);

    function getUniswapV3SpotPrice(address tokenA, address tokenB) public view returns (uint256 price) {

        address poolAddress = factory.getPool(tokenA, tokenB, FEE_TIER);
        IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);

        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
        return(_convertSqrtPriceToPrice(sqrtPriceX96));
    }

    function getUniswapV3TokenTWAP(address tokenA, address tokenB) public view returns (uint256 twapPrice) {

        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = 0;
        secondsAgos[1] = 1800;

        address poolAddress = factory.getPool(tokenA, tokenB, FEE_TIER);
        IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);
        (int56[] memory tickCumulatives, ) = pool.observe(secondsAgos);

        int56 tickDelta = tickCumulatives[1] - tickCumulatives[0];
        int24 avgTick = int24(tickDelta / int56(1800));
        twapPrice = _convertTickToPrice(avgTick);
        
        return twapPrice;
    }

   
    function checkIfPriceStale(address tokenA, address tokenB) external view returns (bool) {

        bool isStale;

        address poolAddress = factory.getPool(tokenA, tokenB, FEE_TIER);
        (, , uint16 index, , , ,) = IUniswapV3Pool(poolAddress).slot0();
        (uint32 lastTimestamp, , ,) = IUniswapV3Pool(poolAddress).observations(index);

        if (block.timestamp - lastTimestamp > STALE_THRESHOLD) {
            isStale = true;
        }
        else {
            isStale = false;
        }    
        return isStale;
    }

    // INTERNAL FUNCTIONS

    function _convertSqrtPriceToPrice(uint160 sqrtPriceX96) internal pure returns (uint256 spotPrice) {
        spotPrice = (uint256(sqrtPriceX96) * uint256(sqrtPriceX96) * 1e18) >> 192;
        return spotPrice;
    }

    function _convertTickToPrice(int24 tick) internal pure returns (uint256 twapPrice) {
        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tick);
        // x96 --> fixed point integer scaled by 2^96
        uint256 priceX96 = FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, 1 << 96);
        return FullMath.mulDiv(priceX96, 1e18, 1 << 96);
    }

}