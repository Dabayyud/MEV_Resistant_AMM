
// This file is used to create an off-chain 32 byte hash similar to the inputs required by the MEV protection contract
// keccak256(abi.encodePacked(msg.sender, amountIn, minAmountOut, commitment.tokenIn, commitment.tokenOut, nonce));

import { ethers } from "ethers";

const types = [
    'address',
    'uint256',
    'uint256',
    'address',
    'address',
    'uint256'
];

const sender: string = "0x29E3b139f4393aDda86303fcdAa35F60Bb7092bF";
const amountIn: ethers.BigNumberish = ethers.parseEther("1.0");
console.log(amountIn);
const minAmountOut: ethers.BigNumberish = ethers.parseEther("0.5");
console.log(minAmountOut);
const tokenIn: string = "0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9";
const tokenOut: string =  "0x16EFdA168bDe70E05CA6D349A690749d622F95e0";
const nonce: ethers.BigNumberish = 67n // 6767676767676767676767676767

const values = [
    sender,
    amountIn,
    minAmountOut,
    tokenIn,
    tokenOut,
    nonce
];

const bytes32Hash: string = ethers.solidityPackedKeccak256(types, values);
console.log(bytes32Hash);

// 0xe106abeec5a63667df7c35f3128bdb531796a30f718426a641e6d95c22e6a9e1



