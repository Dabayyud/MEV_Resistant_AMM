// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;


import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MOCKERC20TOG is ERC20 {

    constructor() ERC20("MOCK", "TOG") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MOCKERC20LUQ is ERC20 {

    constructor() ERC20("MOCK", "LUQ") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

}

