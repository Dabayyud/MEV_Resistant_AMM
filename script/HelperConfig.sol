// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "../lib/forge-std/src/Script.sol";
import {Vm} from "lib/forge-std/src/Vm.sol";

contract HelperConfig is Script {

    struct activeNetworkConfig {
        uint256 commitDeposit;
    }

    activeNetworkConfig public activeNetworkConfigInstance;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfigInstance = getSepoliaConfig();
        }
        else {
            activeNetworkConfigInstance = getAnvilConfig();
        }
    }

    function getSepoliaConfig() internal returns (activeNetworkConfig memory) {
        return activeNetworkConfig ({
            commitDeposit: 0.0001 ether
        });
    }

    function getAnvilConfig() internal returns (activeNetworkConfig memory) {
        return activeNetworkConfig ({
            commitDeposit: 0.1 ether
        });
    }

    function getActiveNetworkConfig() external view returns (activeNetworkConfig memory) {
        return activeNetworkConfigInstance;
    }
}


