import dotenv from 'dotenv';
import axios from 'axios';
import BN from "bn.js";

dotenv.config();

function fromE6(value: number) {
    return value / 10 ** 6;
}

function toE18(value: any) {
    return new BN(value.toString()).muln(10 ** 18).toString();
}

function toE6(value: any) {
    return new BN(value.toString()).muln(10 ** 6).toString();
}

async function getERC20ByAddress(address: any, wallet: any) {
    const ERC20 = require("../abi/IERC20.json");
    return await ethers.getContractAt(ERC20, address, wallet);
}

async function main(): Promise<void> {   
    let zap = await ethers.getContract("UniswapV3Arb");
    let account = await new ethers.Wallet(process.env['PK'], ethers.provider);

    // -------------- get user's positions ----------------------

    let positions = await zap.getPositions("0x01a9fF225a51750599b55C0a23c9d2fCD17969d4");
    console.log("length: ", positions.length);
    for (let i = 0; i < positions.length; i++) {
        console.log("platform:", positions[i].platform);
        console.log("tokenId:", positions[i].tokenId.toString());
        console.log("poolId:", positions[i].poolId.toString());
        console.log("token0:", positions[i].token0.toString());
        console.log("token1:", positions[i].token1.toString());
        console.log("amount0:", positions[i].amount0.toString());
        console.log("amount1:", positions[i].amount1.toString());
        console.log("fee0:", positions[i].fee0.toString());
        console.log("fee1:", positions[i].fee1.toString());
        console.log("emissions:", positions[i].emissions.toString());
        console.log("tickLower:", positions[i].tickLower.toString());
        console.log("tickUpper:", positions[i].tickUpper.toString());
        console.log("currentTick:", positions[i].currentTick.toString());
        console.log("isStaked:", positions[i].isStaked.toString());
        console.log("----------------------------------");
    }

    // -------------------------------------------------------------

    let poolId = "0x641C00A822e8b671738d32a431a4Fb6074E5c79d";
    let tickRange = await zap.closestTicksForCurrentTick(poolId);
    tickRange = [tickRange.left, tickRange.right];
    console.log("tickRange", tickRange);
    let inputTokens = [
        {
            tokenAddress: "0xaf88d065e77c8cc2239327c5edb3a432268e5831",
            amount: "100000",
            price: "1000000000000000000"
        }
    ];

    let proportionRequest = {
        pair: poolId,
        tickRange: tickRange,
        inputTokens: inputTokens,
        tokenIds: []
    };

    let proportionResponse = await zap.getProportionForZap(proportionRequest);

    let handledResponse = {
        inputTokenAddresses: proportionResponse.inputTokenAddresses,
        inputTokenAmounts: proportionResponse.inputTokenAmounts.map((x: any) => x.toString()),
        outputTokenAddresses: proportionResponse.outputTokenAddresses,
        outputTokenProportions: proportionResponse.outputTokenProportions.map((x: any) => x.toString()),
        outputTokenAmounts: proportionResponse.outputTokenAmounts.map((x: any) => x.toString()),
        poolProportionsUsd: proportionResponse.poolProportionsUsd.map((x: any) => x.toString()),
    };

    let proportions = {
        "inputToken": {
            "tokenAddress": handledResponse.inputTokenAddresses[0],
            "amount": handledResponse.inputTokenAmounts[0].toString()
        },
        "outputTokens": handledResponse.outputTokenAddresses.map((e: string, i: number) => ({
            "tokenAddress": e,
            "proportion": fromE6(handledResponse.outputTokenProportions[i].toString()),
        })),
        "amountToken0Out": handledResponse.outputTokenAmounts[0].toString(),
        "amountToken1Out": handledResponse.outputTokenAmounts[1].toString(),
    };

    console.log("proportions", proportions);
    let requests = [];
    if (!proportions.inputToken && proportions.outputTokens.length === 0) {
        requests = [{
            "outAmount": "0",
            "data": "0x"
        }];
    } else {
        requests = await get1InchRequest(
            {
                'inputToken': proportions.inputToken,
                'outputTokens': proportions.outputTokens
            }, 
            zap.address, 
            account.address
        );
    }
    console.log(requests);

    let swapData = {
        inputs: [{
            'tokenAddress': proportions.inputToken.tokenAddress,
            'amountIn': proportions.inputToken.amount
        }],
        outputs: proportions.outputTokens.map((e: any, i: number) => ({
            'tokenAddress': e.tokenAddress,
            'amountMin': new BN(requests[i].outAmount).muln(0.99).toString()
        })),
        data: requests.map((e: any) => e.data)
    };

    let paramsData = {
        pool: poolId,
        tickRange: tickRange,
        amountsOut: [proportions.amountToken0Out, proportions.amountToken1Out]
    }
    console.log("swapData:", swapData);
    console.log("paramsData:", paramsData);

    let inputTokensERC20Arr = await Promise.all(inputTokens.map(async (token: any) => (await getERC20ByAddress(token.tokenAddress, account)).connect(account)));
    for (let i = 0; i < inputTokensERC20Arr.length; i++) {
        await (await inputTokensERC20Arr[i].approve(zap.address, (new BN(10).pow(new BN(64))).toString())).wait();
    }

    const zapResult = await (await zap.connect(account).zapIn(swapData, paramsData)).wait();    
    console.log("zapResult:", zapResult);
}

async function get1InchRequest(params: any, zapAddress: string, walletAddress: string) {
    const url = `https://api.1inch.dev/swap/v6.0/${process.env.CHAIN_ID}/swap`;

    let requests = [];
    for (let i = 0; i < params.outputTokens.length; i++) {
        const config = {
            headers: {
                "Authorization": `Bearer ${process.env.ONE_INCH_API_KEY}`
            },
            params: {
                "src": params.inputToken.tokenAddress,
                "dst": params.outputTokens[i].tokenAddress,
                "amount": new BN(params.inputToken.amount).muln(Number(params.outputTokens[i].proportion)).toString(),
                "from": zapAddress,
                "origin": walletAddress,
                "slippage": 1,
                "disableEstimate": "true"
            },
            paramsSerializer: {
                indexes: null
            }
        };
    
        try {
            const response = await axios.get(url, config);
            requests.push({
                "outAmount": response.data.dstAmount,
                "data": response.data.tx.data
            });
            // console.log(config);
            // console.log(response.data);
        } catch (error) {
            console.error(error);
        }
    }
    // console.log("requests:", requests);
    return requests;
}

main();
