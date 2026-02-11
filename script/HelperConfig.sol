// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "../lib/forge-std/src/Script.sol";
import {Vm} from "lib/forge-std/src/Vm.sol";

contract HelperConfig is Script {

    struct activeNetworkConfig {
        uint256 deployerKey;
        uint256 commitDeposit;
        address tokenIn;
        address tokenOut;
        bytes32 commitHash;
        bytes32 commitHash2;
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
        uint256 sepoliaPrivateKey = vm.envUint("SEPOLIA_PRIVATE_KEY");
        return activeNetworkConfig ({
            deployerKey: sepoliaPrivateKey,
            commitDeposit: 0.0001 ether,
            tokenIn: 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9,
            tokenOut: 0x16EFdA168bDe70E05CA6D349A690749d622F95e0,
            commitHash: 0xe106abeec5a63667df7c35f3128bdb531796a30f718426a641e6d95c22e6a9e1,
            commitHash2: 0x328f15d8fe5683e041751338355b96f3d837641ad38af2379d8d1dd30ef907e1
        });
    }

    function getAnvilConfig() internal returns (activeNetworkConfig memory) {
        uint256 anvilPrivateKey = vm.envUint("ANVIL_PRIVATE_KEY");
        return activeNetworkConfig ({
            deployerKey: anvilPrivateKey,
            commitDeposit: 0.1 ether,
            tokenIn: 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9,
            tokenOut: 0x16EFdA168bDe70E05CA6D349A690749d622F95e0,
            commitHash: 0xe106abeec5a63667df7c35f3128bdb531796a30f718426a641e6d95c22e6a9e1,
            commitHash2: 0x328f15d8fe5683e041751338355b96f3d837641ad38af2379d8d1dd30ef907e1
        });
    }

    function getActiveNetworkConfig() external view returns (activeNetworkConfig memory) {
        return activeNetworkConfigInstance;
    }
}

// 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
