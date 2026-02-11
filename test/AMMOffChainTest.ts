import { createTestClient, http, formatEther, publicActions, walletActions, toBytes, trim, padHex} from "viem";
import { getBalance } from "viem/actions";
import { foundry } from "viem/chains";
import { generateCommitHash } from "./GenerateCommitHash.ts";


import MOCK1ABI from "../MOCKMINT1ABI.json" with {type:'json'};
import MOCK2ABI from "../MOCKMINT2ABI.json" with {type:'json'};

import AMMABI from "../AMMABI.json" with {type:'json'};
import { keccak256 } from "ethers";
import LPABI from "../LPABI.json" with {type:'json'};
import MEVABI from "../MEVABI.json" with {type:'json'}

const ANVIL_URL = "http://127.0.0.1:8545";
const account = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";

const MOCK1ADDR = "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0";
const MOCK2ADDR = "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9";
const AMMADDR = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512";
const MEVADDR = "0x5FbDB2315678afecb367f032d93F642f64180aa3";

(async() => {
    const testClient = createTestClient({
        account: account,
        mode: 'anvil',
        chain: foundry,
        transport: http(ANVIL_URL)
    }).extend(publicActions).extend(walletActions);
    
    console.log ("----------------");
    
    const NONCE = padHex('0x1a4', { size: 32 });
    console.log("GENERATED NONCE IS,", NONCE);
    console.log ("----------------");

    const balance = await getBalance(testClient, {
        address: account
    }) as bigint;

    console.log("USER BEGINNING USER BALANCE IS,", formatEther(balance));
    console.log ("----------------");

    const txMintUserToken1 = await testClient.writeContract({
        address: MOCK1ADDR,
        abi: MOCK1ABI,
        functionName: 'mint',
        args: [account, 1000000000000000000000000000]
    });

    const getBalance1 = await testClient.readContract({
        address: MOCK1ADDR,
        abi: MOCK1ABI,
        functionName: 'balanceOf',
        args: [account],
    }) as bigint;

    console.log("USER TOKEN1 BALANCE AFTER MINT,", formatEther(getBalance1));
    console.log ("----------------");

    const txMintUserToken2 = await testClient.writeContract({
        address: MOCK2ADDR,
        abi: MOCK2ABI,
        functionName: 'mint',
        args: [account, 100000000000000000000000000]
    });

    const getBalance2 = await testClient.readContract({
        address: MOCK2ADDR,
        abi: MOCK2ABI,
        functionName: 'balanceOf',
        args: [account],
    }) as bigint;

    console.log("USER TOKEN2 BALANCE AFTER MINT,", formatEther(getBalance2));
    console.log ("----------------");

    const txCreatePool = await testClient.writeContract({
        address: AMMADDR,
        abi: AMMABI,
        functionName: 'createPool',
        args: [MOCK1ADDR, MOCK2ADDR]
    });

    const POOLCREATED_SIG = keccak256(toBytes("PoolCreated(bytes32)"));
    const LPTOKEN_SIG = keccak256(toBytes("LPTokenAddress(address)"));

    const receipt1 = await testClient.waitForTransactionReceipt({hash: txCreatePool});
    const log1 = (receipt1).logs;
    const event1 = log1.find(
        log => log.address.toLowerCase() == AMMADDR.toLowerCase() &&
        log.topics[0] == POOLCREATED_SIG
    );
    if (!event1) {
        return;
    }

    const POOLID = event1.topics[1];
    console.log("THE CREATED POOL ID IS,", POOLID);
    console.log ("----------------");

    const receipt2 = await testClient.waitForTransactionReceipt({hash: txCreatePool});
    const log2 = (receipt2).logs;
    const event2 = log2.find(
        log => log.address.toLowerCase() == AMMADDR.toLowerCase() &&
        log.topics[0] == LPTOKEN_SIG
    );
    if (!event2) {
        return;
    }

    const LPADDR = trim(event2.topics[1]!);
    console.log("THE LPTOKEN ADDRESS IS AT,", LPADDR);
    console.log ("----------------");

    const txApproveToken1 = await testClient.writeContract({
        address: MOCK1ADDR,
        abi: MOCK1ABI,
        functionName: 'approve',
        args: [AMMADDR, 10000000000000000000000000],
    });

    const txApproveToken2 = await testClient.writeContract({
        address: MOCK2ADDR,
        abi: MOCK2ABI,
        functionName: 'approve',
        args: [AMMADDR, 10000000000000000000000000],
    });

    const txAddLiquidity = await testClient.writeContract({
        address: AMMADDR,
        abi: AMMABI,
        functionName: 'addLiquidity',
        args: [POOLID, 100000000000000000000000, 100000000000000000000000],
    });

    const txGetReserves = await testClient.readContract({
        address: AMMADDR,
        abi: AMMABI,
        functionName: 'getReserves',
        args: [POOLID],
    }) as bigint;

    const reserve0 = txGetReserves[0];
    const reserve1 = txGetReserves[1];
    console.log("POOL RESERVES ARE,", formatEther(reserve0), formatEther(reserve1));
    console.log ("----------------");

    const txGetUserLPTokenBalance = await testClient.readContract({
        address: LPADDR,
        abi: LPABI,
        functionName: "balanceOf",
        args: [account],
    }) as bigint;

    const LPBALANCE = txGetUserLPTokenBalance;
    console.log("USER LPTOKEN BALANCE IS,", formatEther(txGetUserLPTokenBalance));
    console.log ("----------------");
    

    const txApproveLPTOKENForAMM = await testClient.writeContract({
        address: LPADDR,
        abi: LPABI,
        functionName: 'approve',
        args: [AMMADDR, LPBALANCE],
    });

    const txRemoveLiquidity = await testClient.writeContract({
        address: AMMADDR,
        abi: AMMABI,
        functionName: 'removeLiquidity',
        args: [POOLID, 99999999n],
    });

    const txGetUserLPTokenBalance2 = await testClient.readContract({
        address: LPADDR,
        abi: LPABI,
        functionName: "balanceOf",
        args: [account],
    }) as bigint;

    console.log("USER LPTOKEN BALANCE AFTER REMOVE... ,", formatEther(txGetUserLPTokenBalance2));
    console.log ("----------------");

    const txGetReserves2 = await testClient.readContract({
        address: AMMADDR,
        abi: AMMABI,
        functionName: 'getReserves',
        args: [POOLID],
    }) as bigint;

    console.log("POOL RESERVES NOW ARE,", formatEther(txGetReserves2));
    console.log ("----------------");

    const commitHash = await generateCommitHash(account, 100000000000000n, 10000000n, MOCK1ADDR, MOCK2ADDR, NONCE)

    console.log("COMMIT HASH IS,", commitHash);
    console.log ("----------------");

    const txSafeSwapCommit = await testClient.writeContract({
        address: MEVADDR,
        abi: MEVABI,
        functionName: "commitTrade",
        args:[account, MOCK1ADDR, MOCK2ADDR, commitHash],
        value: 100000000000000000n
    });

    const TRADECOMMITED_SIG = keccak256(toBytes("TradeCommitted(bytes32,address,address,address,uint256)"))

    const receipt3 = await testClient.waitForTransactionReceipt({hash: txSafeSwapCommit})
    const log3 = (receipt3).logs
    const event3 = log3.find(
        log => log.address.toLowerCase() == MEVADDR.toLowerCase() &&
        log.topics[0] == TRADECOMMITED_SIG
    )
    if (!event3) {
        return;
    }
    const COMMIT_ID = event3.topics[1];
    console.log("COMMITMENT ID IS,", COMMIT_ID, "COMMITMENT USER IS,", event3.topics[2]);
    console.log ("----------------");

    console.log ("----------------");

    await testClient.mine({blocks: 5});

    const txRevealTrade = await testClient.writeContract({
        address: AMMADDR,
        abi: AMMABI,
        functionName: "swapProtected",
        args:[account, MOCK1ADDR, MOCK2ADDR ,100000000000000n, 10000000n, NONCE, COMMIT_ID]
    });

    const TRADEREVEALED_SIG = keccak256(toBytes("TradeRevealed(bytes32,address,uint256,uint256)"));

    const receipt4 = await testClient.waitForTransactionReceipt({hash: txRevealTrade});
    const log4 = (receipt4).logs
    const event4 = log4.find(
        log => log.address.toLowerCase() == MEVADDR.toLowerCase() &&
        log.topics[0] == TRADEREVEALED_SIG
    )
    if (!event4) {
        return;
    }
    console.log(event4.topics[1], ", ", trim(event4.topics[2]!));

    const txGetCommitDeposit = await testClient.readContract({
        address: MEVADDR,
        abi: MEVABI,
        functionName: "getCommitDepositValue",
        args:[account]
    }) as bigint;

    console.log("COMMIT DEPOSIT IS,", formatEther(txGetCommitDeposit));
    // forge script script/DeployMockMints.s.sol:deployMockMintsAndAMM --rpc-url 127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast


})();