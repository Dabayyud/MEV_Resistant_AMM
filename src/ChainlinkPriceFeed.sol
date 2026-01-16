// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {AggregatorV3Interface} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract ChainlinkDataFetch {

    /** @notice Only the top 6 most liquid pairs is used.
     * This price feed will also be used in the MEV resistant AMM.
     * This price feed is a VWAP.
     * It integrates a staleness check for price.
    */

    error TokenPairAddressNotFound();
    error PriceIsCurrentlyStale();
    error NegativePrice();
    error InvalidDivisionByZero();
    error PrecisionNotMaintained();



    mapping(address => address) public tokenToChainlinkProxyAddress;

    uint256 constant STALE_THRESHOLD = 3600;
    uint8 constant PRICE_PRECISION = 18;

    constructor() {
        _initializeMapping();
    }

    function _initializeMapping() internal {

        address[] memory token = new address[](9);
        address[] memory priceFeed = new address[](9);

        token[0] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        token[1] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        token[2] = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        token[3] = 0xB8c77482e45F1F44dE1745F52C74426C631bDD52;
        token[4] = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
        token[5] = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
        token[6] = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;
        token[7] = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        token[8] = 0xD533a949740bb3306d119CC777fa900bA034cd52;


        priceFeed[0] = 0x5f4ec3df9cbd43714fE2740F5E3616155C5B84dc;
        priceFeed[1] = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
        priceFeed[2] = 0x3e7D1E070F9f25754f24D0a3C9E35e32d065BCAd;
        priceFeed[3] = 0x14e613AC84a31f709eadbdF89C6CC390fDc9540A;
        priceFeed[4] = 0xfdFD9C85aD200c506Cf9e21F1FD8dd01932FBB23;
        priceFeed[5] = 0x86392dC19c0b719886221c78AB11eb8Cf5c52812;
        priceFeed[6] = 0xbd7F896e60B650C01caf2d7279a1148189A68884;
        priceFeed[7] = 0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9;
        priceFeed[8] = 0xCd627aA160A6fA45Eb793D19Ef54f5062F20f33f;

        for (uint i = 0; i < token.length; i++) {
            tokenToChainlinkProxyAddress[token[i]] = priceFeed[i];
        }
    }

    function getChainlinkPriceForToken(address token) public view returns (uint256) {

        address feedAddr = tokenToChainlinkProxyAddress[token];
        if (feedAddr == address(0)) {
            revert TokenPairAddressNotFound();
        }

        (uint80 roundId, int256 price, , uint256 updatedAt, uint80 answeredInRound) = AggregatorV3Interface(feedAddr).latestRoundData();
        if (updatedAt == 0 || block.timestamp - updatedAt > STALE_THRESHOLD || answeredInRound < roundId) {
            revert PriceIsCurrentlyStale();
        }
        if (price <= 0) {
            revert NegativePrice();
        }
        return uint256(price);
    }

    function _checkIfPriceStale(address token) internal view returns (bool) {
        
        address feedAddr = tokenToChainlinkProxyAddress[token];
        if (feedAddr == address(0)) {
            revert TokenPairAddressNotFound();
        }

        AggregatorV3Interface priceFeed = AggregatorV3Interface(token);
        (, , , uint256 updatedAt, ) = priceFeed.latestRoundData();

        if (updatedAt == 0 || block.timestamp - updatedAt > STALE_THRESHOLD) {
            return true;
        }
        return false;
    }

    function checkIfPriceStale(address tokenA, address tokenB) external view returns (bool) {
        bool feedAIsStale = _checkIfPriceStale(tokenA);
        if (feedAIsStale) {
            return true;
        }
        bool feedBIsStale = _checkIfPriceStale(tokenB);
        if (feedBIsStale) {
            return true;
        }

        return false;
    }

    function getChainlinkPriceForPair(address tokenA, address tokenB) external view returns (uint256) {
        uint256 tokenAPrice = getChainlinkPriceForToken(tokenA);
        uint256 tokenBPrice = getChainlinkPriceForToken(tokenB);
        if (tokenBPrice == 0) {
            revert InvalidDivisionByZero(); 
        }

        address feedAddrA = tokenToChainlinkProxyAddress[tokenA];
        address feedAddrB = tokenToChainlinkProxyAddress[tokenB];

        uint8 decimalsA = AggregatorV3Interface(feedAddrA).decimals();
        uint8 decimalsB = AggregatorV3Interface(feedAddrB).decimals();

        uint256 commonBase = 10**uint256(PRICE_PRECISION);
        uint256 adjustedPriceA = uint256(tokenAPrice) * (10**(uint256(PRICE_PRECISION) - uint256(decimalsA)));
        uint256 adjustedPriceB = uint256(tokenBPrice) * (10**(uint256(PRICE_PRECISION) - uint256(decimalsB)));

        uint256 result = (adjustedPriceA * commonBase) / adjustedPriceB;
        return result;
    }
}