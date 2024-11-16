const { getContract, initWallet, } = require("../utils");
const path = require('path');

let filename = path.basename(__filename);
filename = filename.substring(0, filename.indexOf(".js"));

const { ComputeSetting, Options } = require('@layerzerolabs/lz-v2-utilities');
const { parseEther } = require("ethers/lib/utils");

async function main() {
    let wallet = await initWallet();

    let zap = await getContract("UniswapV3Arb", "arbitrum");
    let oread = await getContract("ORead", "arbitrum");

    let poolBase = "0xd0b53D9277642d899DF5C87A3966A349A798F224"; // weth/usdc
    let poolArb = "0xC6962004f452bE9203591991D15f6b388e09E8D0"; // weth/usdc

    let baseEID = 30184;

    const options = Options.newOptions().addExecutorLzReadOption(500000, 100, 0).toHex().toString()
    console.log(options)

    console.log("amounts: ", await zap.getResult());
    console.log("readCH: ", await oread.READ_CHANNEL());
    console.log("end: ", await oread.endpoint());
    // console.log("eid: ", await zap.eid());
    
    await oread.addChain(30184n, {confirmations: 5n, zapAddress: "0x88496773aC402210D21Bd7b3Bd8E540038A2f75f"});

    console.log("data: ", await oread.getCmdData(baseEID, poolBase, ["-5", "0"]));
    
    console.log("quote: ", await oread.quoteCmdData(baseEID, poolBase, ["-5", "0"], options));

    console.log("cur tick: ", await zap.getPoolTick(poolArb));
    console.log("arb prop: ", await zap.getProportion(poolArb, ["0", "100"]));
    await zap.getProportionLZ(baseEID, poolBase, ["-5", "0"], options, {value: parseEther("0.0001"), gasLimit: 1500000});

    console.log("amount1: ", await zap.amount1());
    console.log("amount2: ", await zap.amount2());
}   

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
