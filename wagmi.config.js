// @ts-check

import {etherscan} from  "@wagmi/cli/plugins"

/** @type {import('@wagmi/cli').Config} */
export default {
  out: 'src/generated.js',
  contracts: [],
  plugins: [
    etherscan({
      apiKey: KJI3HRR4WVJRXKEJ1BJTFPQSY832MAPXVJ,
      chainId: 11155111,
      contracts
    })
  ],
}
