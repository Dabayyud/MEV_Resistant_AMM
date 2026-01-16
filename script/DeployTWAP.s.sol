//// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "lib/forge-std/src/Script.sol";
import {console} from "lib/forge-std/src/console.sol";
import {TWAP} from "src/VWAP.sol";
import {UniswapV4DataFetch} from 'src/UniswapV4PriceFeed.sol';
import {UniswapV3DataFetch} from 'src/UniswapV3PriceFeed.sol';
import {ChainlinkDataFetch} from "src/ChainlinkPriceFeed.sol";
import {IPoolManager} from "lib/v4-core/src/interfaces/IPoolManager.sol";

contract DeployTWAP is Script {


    IPoolManager poolManager = IPoolManager(0x000000000004444c5dc75cB358380D2e3dE08A90);

    TWAP twap;
    UniswapV3DataFetch v3DataFetch;
    UniswapV4DataFetch v4DataFetch;
    ChainlinkDataFetch cDataFetch;

    uint256 public SEPOLIA_PRIVATE_KEY = 0x442194e000a1092ca8d98ef1d6345c8c61a3dc8a486af3eb9fd909d1113574be;
    function run() public returns (address twap, address v3, address c, address v4) {

        vm.startBroadcast(SEPOLIA_PRIVATE_KEY);

        UniswapV3DataFetch v3DataFetch = new UniswapV3DataFetch();
        UniswapV4DataFetch v4DataFetch = new UniswapV4DataFetch(poolManager);
        ChainlinkDataFetch cDataFetch = new ChainlinkDataFetch();

        console.log("V3", address(v3DataFetch));
        console.log("V4", address(v4DataFetch));
        console.log("C", address(cDataFetch));

        TWAP twap = new TWAP(address(v4DataFetch), address(v3DataFetch), address(cDataFetch));
        
        console.log("Oracle", address(twap));

        vm.stopBroadcast();

        return (address(twap), address(v3DataFetch), address(cDataFetch), address(v4DataFetch));
    }
}