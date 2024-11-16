const BN = require('bn.js');
const hre = require("hardhat");
const axios = require('axios');

async function resetHardhatToLastBlock() {
    const provider = new ethers.providers.JsonRpcProvider("https://rpc.ankr.com/arbitrum");
    let block = (await provider.getBlockNumber()) - 31;

    await hre.network.provider.request({
        method: 'hardhat_reset',
        params: [
            {
                forking: {
                    jsonRpcUrl: "https://rpc.ankr.com/arbitrum",
                    blockNumber: block,
                },
            },
        ],
    });

    console.log(`[Hardhat]: hardhat_reset -> ${block.toString()}`);
}

function fromE6(value) {
    return value / 10 ** 6;
}

function fromE18(value) {
    return value / 10 ** 18;
}

function toE18(value) {
    return new BN(value.toString()).muln(10 ** 18).toString();
}

function toE6(value) {
    return new BN(value.toString()).muln(10 ** 6).toString();
}

async function getERC20ByAddress(address, wallet) {
    const ERC20 = require("../abi/IERC20.json");
    return await ethers.getContractAt(ERC20, address, wallet);
}

async function transferETH(amount, to) {
    let privateKey = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"; // Ganache key
    let walletWithProvider = new ethers.Wallet(privateKey, hre.ethers.provider);
    await walletWithProvider.sendTransaction({
        to: to,
        value: ethers.utils.parseEther(amount + "")
    });
    console.log(`[Node] Transfer ETH [${fromE18(await hre.ethers.provider.getBalance(to))}] to [${to}]`);
}

describe(`am ok`, function() {
    it('totally fine', async function() {
        let name = "UniswapV3Arb";

        await hre.run("compile");
        await resetHardhatToLastBlock();
        await deployments.fixture(name);

        await transferETH(100, "0x01a9fF225a51750599b55C0a23c9d2fCD17969d4");

        let zap = await ethers.getContract(name);
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
            console.log("decimals0:", positions[i].decimals0.toString());   
            console.log("decimals1:", positions[i].decimals1.toString());
            console.log("symbol0:", positions[i].symbol0);
            console.log("symbol1:", positions[i].symbol1);
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
            inputTokenAmounts: proportionResponse.inputTokenAmounts.map((x) => x.toString()),
            outputTokenAddresses: proportionResponse.outputTokenAddresses,
            outputTokenProportions: proportionResponse.outputTokenProportions.map((x) => x.toString()),
            outputTokenAmounts: proportionResponse.outputTokenAmounts.map((x) => x.toString()),
            poolProportionsUsd: proportionResponse.poolProportionsUsd.map((x) => x.toString()),
        };

        let proportions = {
            "inputToken": {
                "tokenAddress": handledResponse.inputTokenAddresses[0],
                "amount": handledResponse.inputTokenAmounts[0].toString()
            },
            "outputTokens": handledResponse.outputTokenAddresses.map((e, i) => ({
                "tokenAddress": e,
                "proportion": fromE6(handledResponse.outputTokenProportions[i].toString()),
            })),
            "amountToken0Out": handledResponse.outputTokenAmounts[0].toString(),
            "amountToken1Out": handledResponse.outputTokenAmounts[1].toString(),
        };

        console.log("proportions", proportions);
        let requests;
        if (!proportions.inputToken && proportions.outputTokens.length === 0) {
            requests = [{
                "outAmount": "0",
                "data": "0x"
            }];
        } else {
            requests = await getOdosRequest(
                {
                    'inputToken': proportions.inputToken,
                    'outputTokens': proportions.outputTokens
                }, 
                zap.address
            );
        }
        console.log(requests);

        let swapData = {
            inputs: [{
                'tokenAddress': proportions.inputToken.tokenAddress,
                'amountIn': proportions.inputToken.amount
            }],
            outputs: proportions.outputTokens.map((e, i) => ({
                'tokenAddress': e.tokenAddress,
                'amountMin': 1
            })),
            data: requests.request.data
        };

        let paramsData = {
            pool: poolId,
            tickRange: tickRange,
            amountsOut: [proportions.amountToken0Out, proportions.amountToken1Out]
        }
        console.log("swapData:", swapData);
        console.log("paramsData:", paramsData);

        let inputTokensERC20Arr = await Promise.all(inputTokens.map(async (token) => (await getERC20ByAddress(token.tokenAddress, account)).connect(account)));
        for (let i = 0; i < inputTokensERC20Arr.length; i++) {
            await (await inputTokensERC20Arr[i].approve(zap.address, (new BN(10).pow(new BN(64))).toString())).wait();
        }

        const zapResult = await (await zap.connect(account).zapIn(swapData, paramsData)).wait();
        console.log("zapResult:", zapResult);
    });
});

async function getOdosRequest(params, zapAddress) {
    let swapParams = {
        'chainId': `${process.env.CHAIN_ID}`,
        'gasPrice': 1,
        'inputTokens': [params.inputToken],
        'outputTokens': params.outputTokens,
        'userAddr': zapAddress,
        'slippageLimitPercent': 1,
        'sourceWhitelist': [],
        'simulate': false,
        'pathViz': false,
        'disableRFQs': false,
    };

    const urlQuote = 'https://api.odos.xyz/sor/quote/v2';
    const urlAssemble = 'https://api.odos.xyz/sor/assemble';
    let transaction;
    let outAmounts;

    let quotaResponse = (await axios.post(urlQuote, swapParams, { headers: { 'Accept-Encoding': 'br' } }));
    outAmounts = quotaResponse.data.outAmounts;
    let assembleData = {
        'userAddr': zapAddress,
        'pathId': quotaResponse.data.pathId,
        'simulate': true,
    };
    transaction = (await axios.post(urlAssemble, assembleData, { headers: { 'Accept-Encoding': 'br' } }));

    if (transaction.statusCode === 400) {
        throw new Error(`[zap] ${transaction.description}`);
    }

    if (transaction.data.transaction === undefined) {
        throw new Error('[zap] transaction.tx is undefined');
    }

    console.log('Success get data from Odos!');
    return {
        "request": transaction.data.transaction,
        "outAmounts": outAmounts
    };
}
