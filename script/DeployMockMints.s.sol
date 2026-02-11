// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from 'lib/forge-std/src/Script.sol';
import {MOCKERC20TOG, MOCKERC20LUQ} from "../src/MockMint.sol";
import {AMM} from "../src/AMM.sol";
import {HelperConfig} from "./HelperConfig.sol";
import {MEVProtection} from "../src/MEVProtection.sol";

contract deployMockMintsAndAMM is Script {
    
    function run() external returns (string memory, address, string memory, address, string memory, address, string memory, address) {

        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.activeNetworkConfig memory cfg = helperConfig.getActiveNetworkConfig();

        vm.startBroadcast();

        MEVProtection mev = new MEVProtection(cfg.commitDeposit);
        AMM amm = new AMM(address(mev));
        MOCKERC20TOG mock1 = new MOCKERC20TOG();
        MOCKERC20LUQ mock2 = new MOCKERC20LUQ();

        vm.stopBroadcast();

        return ("AMM address at", address(amm), "MEV address at", address(mev), "MOCK1 addresss at", address(mock1), "MOCK2 addresss at", address(mock2));
    }
}


