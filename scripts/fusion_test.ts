import { HashLock } from '@1inch/cross-chain-sdk';
import {randomBytes} from 'node:crypto';
import axios from 'axios';
import dotenv from 'dotenv';

dotenv.config();

async function run() {
	const receiveUrl = "https://api.1inch.dev/fusion-plus/quoter/v1.0/quote/receive";
	const buildUrl   = "https://api.1inch.dev/fusion-plus/quoter/v1.0/quote/build";

	const config = {
		headers: {
			Authorization: `Bearer ${process.env.ONE_INCH_API_KEY}`
		},
		params: {
			srcChain: "10",
			dstChain: "42161",
			srcTokenAddress: "0x0b2c639c533813f4aa9d7837caf62653d097ff85",
			dstTokenAddress: "0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9",
			amount: "1000000",
			walletAddress: "0xce314cCe0E74f01E2E75B0BbD518dB13aD27C5BA",
			enableEstimate: "true"
		},
		paramsSerializer: {
			indexes: null
		}
	};

	let quote;
	try {
		quote = await axios.get(receiveUrl, config);
	} catch (error) {
		console.error(error);
	}
	console.log(quote!.data);

	const secrets = Array.from({  
        length: quote!.data.presets["fast"].secretsCount  
    }).map(() => '0x' + randomBytes(32).toString('hex'));
    const secretHashes = secrets.map((s) => HashLock.hashSecret(s));
	console.log(secretHashes);

	// const body = {
	// 	...quote!.data,
	// 	secretsHashList: secretHashes
	// };

	// try {
	// 	const buildResponse = await axios.post(buildUrl, body, config);
	// 	console.log(buildResponse.data);
	// } catch (error) {
	// 	console.error(error);
	// }
}

run();
