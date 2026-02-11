// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {UniswapV4DataFetch} from 'priceFeeds/UniswapV4PriceFeed.sol';
import {UniswapV3DataFetch} from 'priceFeeds/UniswapV3PriceFeed.sol';
import {ChainlinkDataFetch} from 'priceFeeds/ChainlinkPriceFeed.sol';



contract TWAP {

    error TokenPairPricesAreCurrentlyStale();
    error PriceOfTokenPairHaveExceededDeviationThreshold(uint256);

    event FallbackPriceFeedUsed(address indexed tokenA, address indexed tokenB);

    UniswapV4DataFetch immutable public uniswapV4DataFetch;
    UniswapV3DataFetch immutable public uniswapV3DataFetch;
    ChainlinkDataFetch immutable public chainlinkDataFetch;

    uint256 public constant MAX_DEVIATION_BPS = 50; 

    constructor(
        address _v4PriceFeedAddress,
        address _v3PriceFeedAddress,
        address _chainlinkPriceFeedAddress
    ) {
        uniswapV4DataFetch = UniswapV4DataFetch(_v4PriceFeedAddress);
        uniswapV3DataFetch = UniswapV3DataFetch(_v3PriceFeedAddress);
        chainlinkDataFetch = ChainlinkDataFetch(_chainlinkPriceFeedAddress);
    }


    function _isPriceDeviated(address tokenA, address tokenB) internal view returns (bool, uint256) { // change to twap

        uint256 p1 = uniswapV3DataFetch.getUniswapV3SpotPrice(tokenA, tokenB);
        uint256 p2 = uniswapV4DataFetch.getUniswapV4SpotPrice(tokenA, tokenB);

        uint256 priceDiff;
        uint256 priceAvg;

        if (p1 >= p2) {
            priceDiff = p1 - p2;
        }
        else {
            priceDiff = p2 - p1;
        }
        priceAvg = (p1 + p2) / 2;

        uint256 currentDeviationBPS = (priceDiff * 10000) / priceAvg;

        if (currentDeviationBPS > MAX_DEVIATION_BPS) {
            return (true, currentDeviationBPS);
        }

        return (false, currentDeviationBPS);
    }

    function isProtocolPriceStale(address tokenA, address tokenB) public view returns (bool) {

        bool uniswap = uniswapV3DataFetch.checkIfPriceStale(tokenA, tokenB);
        bool chainlink = chainlinkDataFetch.checkIfPriceStale(tokenA, tokenB);

        return ((uniswap) && (chainlink));
    }

    function getTWAP(address tokenA, address tokenB) public returns (uint256) {

        (bool deviated, uint256 currentDeviationBPS) = _isPriceDeviated(tokenA, tokenB);
        if (deviated) {
            revert PriceOfTokenPairHaveExceededDeviationThreshold(currentDeviationBPS);
        }

        bool isUniswapStale = uniswapV3DataFetch.checkIfPriceStale(tokenA, tokenB);

        if (!isUniswapStale) {
            uint256 twapPriceU = uniswapV3DataFetch.getUniswapV3TokenTWAP(tokenA, tokenB);
            return twapPriceU;
        }

        bool isChainlinkStale = chainlinkDataFetch.checkIfPriceStale(tokenA, tokenB);

        if (!isChainlinkStale) {
            uint256 twapPriceC = chainlinkDataFetch.getChainlinkPriceForPair(tokenA, tokenB);
            emit FallbackPriceFeedUsed(tokenA, tokenB);
            return twapPriceC;
        }

        revert TokenPairPricesAreCurrentlyStale();
    }
}