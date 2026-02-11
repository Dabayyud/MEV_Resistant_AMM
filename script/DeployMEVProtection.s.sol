// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "../lib/forge-std/src/Script.sol";
import {MEVProtection} from "../src/MEVProtection.sol";
import {HelperConfig} from './HelperConfig.sol';
import {console} from "../lib/forge-std/src/Console.sol";

contract deployMEVProtection is Script {

    MEVProtection mevProtection;
    HelperConfig helperConfig; 

    function run() external returns (MEVProtection, HelperConfig, address, address, bytes32, bytes32) {
        HelperConfig helperConfig = new HelperConfig();
        (uint256 deployerKey, uint256 commitDeposit, address tokenIn,  address tokenOut, bytes32 commitHash, bytes32 commitHash2) = helperConfig.activeNetworkConfigInstance();
        
        vm.startBroadcast(deployerKey);
        MEVProtection mevProtection = new MEVProtection(commitDeposit);
        console.log("MEV ADDRESS AT", address(mevProtection));
        vm.stopBroadcast();

        return (mevProtection, helperConfig, tokenIn, tokenOut, commitHash, commitHash2);
    }
}