// @ts-check

import { etherscan } from '@wagmi/cli/plugins';

/** @type {import('@wagmi/cli').Config} */
export default {
  out: 'src/generated.js',
  contracts: [],
  plugins: [
    etherscan({
      apiKey:"KJI3HRR4WVJRXKEJ1BJTFPQSY832MAPXVJ",
      chainId: 1,
      contracts: [
        {
          name: 'UniswapV3Factory',
          address:'0x1F98431c8aD98523631AE4a59f267346ea31F984',
        },
        {
          name: 'UniswapV3Pool_ETH_USDC_500',
          address: '0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8',
        },
        {
          name: 'ChainlinkETHUSD',
          address: '0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419'
        },
        {
          name: 'ChainlinkBTCUSD',
          address: '0xf4030086522a5beea4988f8ca5b36dbc97bee88c'
        },
        {
          name: 'Stateview',
          address: '0x7fFE42C4a5DEeA5b0feC41C94C136Cf115597227'
        }
      ]
    })
  ],
}
