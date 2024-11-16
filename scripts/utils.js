const axios = require('axios');
const hre = require("hardhat");
const path = require('path'),
    fs = require('fs');

let ethers = require('hardhat').ethers;
let wallet = undefined;

async function initWallet() {
    let provider = ethers.provider;

    networkName = process.env.NETWORK;
    wallet = await new ethers.Wallet(process.env['PK'], provider);
    

    console.log('[User] Wallet: ' + wallet.address);
    const balance = await provider.getBalance(wallet.address);
    console.log('[User] Balance wallet: ' + balance.toString());

    return wallet;
}


async function getContract(name, network) {

    if (!network) network = process.env.NETWORK;

    let ethers = hre.ethers;
    let wallet = await initWallet();

    try {
        let searchPath = fromDir(require('app-root-path').path, path.join(network, name + ".json"));
        console.log(searchPath);
        let contractJson = JSON.parse(fs.readFileSync(searchPath));
        return await ethers.getContractAt(contractJson.abi, contractJson.address, wallet);
    } catch (e) {
        console.error(`Error: Could not find a contract named [${name}] in network: [${network}]`);
        throw new Error(e);
    }
}

function fromDir(startPath, filter) {
    if (!fs.existsSync(startPath)) {
        console.log("no dir ", startPath);
        return;
    }

    let files = fs.readdirSync(startPath);
    for (let i = 0; i < files.length; i++) {
        let filename = path.join(startPath, files[i]);
        let stat = fs.lstatSync(filename);
        if (stat.isDirectory()) {
            let value = fromDir(filename, filter); //recurse
            if (value)
                return value;

        } else if (filename.endsWith(filter)) {
            // console.log('Fond: ' + filename)
            return filename;
        }
    }
}


module.exports = {
    getContract: getContract,
    initWallet: initWallet
}