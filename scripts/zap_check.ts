import {  
    HashLock,  
    NetworkEnum,  
    OrderStatus,  
    PresetEnum,  
    PrivateKeyProviderConnector,  
    SDK  
} from '@1inch/cross-chain-sdk';
import Web3 from 'web3';
import {randomBytes} from 'node:crypto';
import dotenv from 'dotenv';

dotenv.config();

async function main(): Promise<void> {   
    let zap = await ethers.getContract("UniswapV3Arb");

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
}

main();
