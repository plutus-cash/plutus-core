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

const privateKey = process.env.DEV_PRIVATE_KEY!;
const authKey = process.env.ONE_INCH_API_KEY!;
const rpc = process.env.RPC_OPTIMISM!;
const source = 'plutus-fusion-test';
  
const web3 = new Web3(rpc);
const walletAddress = web3.eth.accounts.privateKeyToAccount(privateKey).address;
  
const sdk = new SDK({  
    url: 'https://api.1inch.dev/fusion-plus',  
    authKey,  
    blockchainProvider: new PrivateKeyProviderConnector(privateKey, web3.currentProvider as any) // only required for order creation  
});

async function sleep(ms: number): Promise<void> {  
    return new Promise((resolve) => setTimeout(resolve, ms))  
}  
  
async function main(): Promise<void> {   
    const quote = await sdk.getQuote({  
        amount: '1000000',
        srcChainId: NetworkEnum.OPTIMISM,
        dstChainId: NetworkEnum.ARBITRUM,
        enableEstimate: true,
        srcTokenAddress: '0x0b2c639c533813f4aa9d7837caf62653d097ff85', // USDC
        dstTokenAddress: '0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9', // USDT
        walletAddress
    });
  
    const preset = PresetEnum.fast;
  
    // generate secrets  
    const secrets = Array.from({  
        length: quote.presets[preset].secretsCount  
    }).map(() => '0x' + randomBytes(32).toString('hex'));
  
    const hashLock =  
        secrets.length === 1  
            ? HashLock.forSingleFill(secrets[0])  
            : HashLock.forMultipleFills(HashLock.getMerkleLeaves(secrets));
  
    const secretHashes = secrets.map((s) => HashLock.hashSecret(s));
    
    // create order  
    const {hash, quoteId, order} = await sdk.createOrder(quote, {  
        walletAddress,  
        hashLock,  
        preset,  
        source,  
        secretHashes  
    });
    console.log({hash}, 'order created');

    // submit order  
    const _orderInfo = await sdk.submitOrder(  
        quote.srcChainId,
        order,
        quoteId,
        secretHashes
    );
    console.log({hash}, 'order submitted');
  
    // submit secrets for deployed escrows  
    while (true) {  
        const secretsToShare = await sdk.getReadyToAcceptSecretFills(hash);
  
        if (secretsToShare.fills.length) {  
            for (const {idx} of secretsToShare.fills) {  
                await sdk.submitSecret(hash, secrets[idx])  
  
                console.log({idx}, 'shared secret');
            }  
        }  

        // check if order finished  
        const {status} = await sdk.getOrderStatus(hash);

        if (
            status === OrderStatus.Executed ||  
            status === OrderStatus.Expired ||  
            status === OrderStatus.Refunded  
        ) {  
            break;
        }  

        await sleep(1000);
    }

    const statusResponse = await sdk.getOrderStatus(hash);
    console.log(statusResponse);
}

main();
