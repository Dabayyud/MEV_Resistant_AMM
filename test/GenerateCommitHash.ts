
// This file is used to create an off-chain 32 byte hash similar to the inputs required by the MEV protection contract
// keccak256(abi.encodePacked(msg.sender, amountIn, minAmountOut, commitment.tokenIn, commitment.tokenOut, nonce));

import {solidityPackedKeccak256 } from "ethers";


export async function generateCommitHash(sender: string, amountIn: bigint, minAmountOut: bigint, tokenIn: string, tokenOut: string, nonce: string)  : Promise<string> {
    const types = [
        'address',
        'uint256',
        'uint256',
        'address',
        'address',
        'bytes32'
    ] as const; 

    
    return solidityPackedKeccak256(
    ['address','uint256','uint256','address','address','bytes32'],
    [sender, amountIn, minAmountOut, tokenIn, tokenOut, nonce]
  );
}



