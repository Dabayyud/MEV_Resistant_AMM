// I did not have enough sepoliaEth to conduct comprehensive tests like i usually do with other projects
// so instead, ill test as much as i can off chain without deploying any contracts while trying to 
// replicate similar logic i use in this project. This is in my opinion, the next best alternative.
// where i comment out the logs, the intended value was obtained.

import {createWalletClient, http, publicActions, getContract, checksumAddress, formatEther} from "viem";
import {mainnet} from "viem/chains";
import {uniswapV3FactoryAbi, uniswapV3PoolEthUsdc_500Abi, chainlinkEthusdAbi} from "../src/0generated.js";
import {chainlinkBtcusdAbi} from "../src/1generated.js"; // wagmi plug only allows three contracts at a time
import {stateviewAbi} from "../src/generated.js"
// import {Pool} from '@uniswap/v4-sdk'; issue with package so ill have to manually convert poolKey to bytes32 
// import {Token} from "@uniswap/sdk-core";
import { keccak256, encodeAbiParameters, parseAbiParameter} from "viem";
import type { Hex } from "viem";


const API_URL = "https://eth-mainnet.g.alchemy.com/v2/DgZjnWu4OqRlWGA4G8RkS";
const account = "0x3934573D2A9681F751F6e1aBB6Ea35170Acb4869";
const UNISWAP_V3_ADDRESS = "0x1F98431c8aD98523631AE4a59f267346ea31F984";
const CHAINLINK_ETH_ADDRESS = "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419";
const CHAINLINK_BTC_ADDRESS = "0xf4030086522a5beea4988f8ca5b36dbc97bee88c";
const STATE_VIEW_ADDRESS = "0x7fFE42C4a5DEeA5b0feC41C94C136Cf115597227";

const WETH_ADDRESS = "0xC02aaA39b223FE8d0A0e5C4f27eAD9083C756Cc2";
const WBTC_ADDRESS = "0x2260fac5e5542a773aa44fbcfedf7c193bc2c599";

const WETH_ADDRESSV4 = "0xC02aaA39b223FE8d0A0e5C4f27eAD9083C756Cc2" as const ; 
const WBTC_ADDRESSV4 = "0x2260fac5e5542a773aa44fbcfedf7c193bc2c599" as const ; // 

// const CHAIN_ID = 1;
// const WETH = new Token(CHAIN_ID, WETH_ADDRESS, 18, 'WETH', "Wrapped Ether");
// const WBTC = new Token(CHAIN_ID, WBTC_ADDRESS, 8, 'WBTC', 'Wrapped Bitcoin');

const NO_HOOKS = "0x0000000000000000000000000000000000000000" as const; 

const FEE_TIER = 3000; 
const STALE_THRESHOLD = 2;
const STANDARD_TICK_SPACING = 60;
const secondsAgos = [0, 1800];
const decimals0 = 18;
const decimals1 = 8;

export function standardPrice(
    sqrtPriceX96: bigint, 
    token0Decimals: number, 
    token1Decimals: number,
): string {
    const rawPriceNumber = Number(sqrtPriceX96) ** 2 / (2 ** 192);
    const priceAdjustedForDecimals = rawPriceNumber * (10 ** (token1Decimals - token0Decimals));
    return priceAdjustedForDecimals.toFixed(token1Decimals); 
}

interface PoolKey {
    currency0: Hex;      
    currency1: Hex;      
    fee: number;         
    tickSpacing: number; 
    hooks: Hex;   
}

export function getPoolID(poolKey: PoolKey): string {
    const encodedparams = encodeAbiParameters(
        [
            parseAbiParameter('address currency0'),
            parseAbiParameter('address currency1'),
            parseAbiParameter('uint24 fee'),
            parseAbiParameter('int24 tickSpacing'),
            parseAbiParameter('address hooks'),
        ],
        [
            checksumAddress(poolKey.currency0),
            checksumAddress(poolKey.currency1),
            poolKey.fee,
            poolKey.tickSpacing,
            checksumAddress(poolKey.hooks),
        ]
    );
    const poolID: Hex = keccak256(encodedparams);
    return poolID;
}

interface Slot0 {
    sqrtPriceX96: BigInt;
    tick: number;
    observationIndex: number;
    observationCardinality: number;
    observationCardinalityNext: number;
    feeProtocol: number;
    unlocked: boolean;
}

interface TWAP {
    tickCumulatives: number[];
    secondsPerLiquidityCumulativeX128s: number[];
}

interface Observations {
    blockTimestamp: number,
    tickCumulative: number,
    secondsPerLiquidityCumulativeX128: number,
    initialized: boolean,
}


interface Chainlink {
    roundId: number | bigint,
    answer: number | bigint,
    startedAt: number | bigint,
    updatedAt: number | bigint,
    answeredInRound: number | bigint,
}

(async () => {

    const walletClient = createWalletClient({
        account: account,
        chain: mainnet,
        transport: http(API_URL),
    }).extend(publicActions);

    // const balance = await walletClient.getBalance({
    //     address: account
    // });
    // console.log(balance);

    const UniswapV3 = getContract({
        address: UNISWAP_V3_ADDRESS,
        abi: uniswapV3FactoryAbi,
        client: walletClient,
    });

    const poolAddress = await UniswapV3.read.getPool([checksumAddress(WBTC_ADDRESS), checksumAddress(WETH_ADDRESS), FEE_TIER]);
    // console.log(poolAddress);

    // testing spot price functionality
    const data = await walletClient.readContract({
        address: poolAddress as `0x${string}`,
        abi: uniswapV3PoolEthUsdc_500Abi,
        functionName: 'slot0',
        args: [], //[checksumAddress(WETH_ADDRESS), checksumAddress(USDC_ADDRESS), FEE_TIER],
    }) as Slot0;

    // console.log(data);

    // const rawPrice = data.sqrtPriceX96; // not object, its an array
    const rawPrice = data[0];
    // console.log(rawPrice);

    // convert the sqrtPriceX96 (spot price) into standard form

    const priceStringT0InT1 = standardPrice(data[0], decimals0, decimals1);
    const invertedPrice = 1 / parseFloat(priceStringT0InT1);
    const invertedPriceString = invertedPrice.toFixed(18);

    console.log(invertedPriceString);
    // around 3300 

    // Next is the TWAP
    const data2 = await walletClient.readContract({
        address: poolAddress as `0x${string}`,
        abi: uniswapV3PoolEthUsdc_500Abi,
        functionName: 'observe',
        args:[secondsAgos],
    }) as TWAP;

    // console.log(data2);

    const cumalatives: bigint[] = data2[0];
    const avgTick = Number((cumalatives[0] - cumalatives[1]) / 1800n); 

    // console.log(avgTick)

    const base = Math.pow(1.0001, avgTick);
    const adjustmentFactor = Math.pow(10, 10);

    const usdcPerEthPrice = adjustmentFactor / base;

    const TWAP = usdcPerEthPrice.toFixed(18); 
    console.log(TWAP);

    // Staleness check
    const index = data[2];
    const data3 = await walletClient.readContract({
        address: poolAddress as `0x${string}`,
        abi: uniswapV3PoolEthUsdc_500Abi,
        functionName: 'observations',
        args: [index],
    }) as Observations;

    // console.log(data3);


    const currentTime = Math.floor(Date.now() / 1000);
    const isPriceStaleV3 : boolean = (currentTime - data3[0]) > STALE_THRESHOLD;
    
    console.log(isPriceStaleV3);

    const poolID_Input = {
    currency0: WETH_ADDRESSV4, // token object because uniswap v4 is highly typesafe
    currency1: WBTC_ADDRESSV4, // ..
    fee: FEE_TIER,
    tickSpacing: STANDARD_TICK_SPACING,
    hooks: NO_HOOKS,
    } ;

    const poolID = getPoolID(poolID_Input);

    // console.log(poolID);
    
    const data4 = await walletClient.readContract({
        address: STATE_VIEW_ADDRESS,
        abi: stateviewAbi,
        functionName: 'getSlot0',
        args:[poolID]
    })

    // console.log(data4);
    
    // Chainlink fallback pattern is engaged when (isPriceStale)
    if (isPriceStaleV3) {
        const data5 = await walletClient.multicall({
            contracts: [
                {
                    address: CHAINLINK_ETH_ADDRESS,
                    abi: chainlinkEthusdAbi,
                    functionName: 'latestRoundData',
                    args: [],
                },
                {
                    address: CHAINLINK_BTC_ADDRESS,
                    abi: chainlinkBtcusdAbi,
                    functionName: 'latestRoundData',
                    args:[],
                }
            ]
        });

        // console.log(data5);
        const ETH_DATA = data5[0].result as Chainlink;
        const BTC_DATA = data5[1].result as Chainlink;

        const ETH_PRICE = ETH_DATA[1];
        const BTC_PRICE = BTC_DATA[1];

        const ETH_BTC_PRICE = formatEther((ETH_PRICE * 10n**18n) / BTC_PRICE);

        console.log(ETH_BTC_PRICE)


    }

})();
