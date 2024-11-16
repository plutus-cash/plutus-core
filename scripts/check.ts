const { expect } = require('chai');
const { deployments, ethers, getNamedAccounts, artifacts } = require('hardhat');

const axios = require('axios');
const { ComputeSetting, Options } = require('@layerzerolabs/lz-v2-utilities')

async function main() {

    const options = Options.newOptions().addExecutorLzReadOption(500000, 100, 0).toHex().toString()
    console.log(options)
    // let oread = await ethers.getContractAt("OReadFacet", "0xBd7445BE830BB6d11D4187C50a4be8fCF4784957");  

    // await oread.addChain(30110n, {confirmations: 5n, zapAddress: "0x68A213C21C9DBB6A38646B860ef10a9a95B85Da4"});
}


main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
