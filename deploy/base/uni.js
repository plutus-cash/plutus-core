const { ethers } = require("hardhat");
const hre = require("hardhat");
const { deployDiamond, deployFacets, prepareCut, updateFacets, updateAbi } = require("../util");

const name = 'UniswapV3Base';

module.exports = async ({ getNamedAccounts, deployments }) => {
    // await transferETH(0.00001, "0x0000000000000000000000000000000000000000");
    const { save, deploy } = deployments;
    const { deployer } = await getNamedAccounts();
    console.log('deployer', deployer);
    let zap = await deployDiamond(name, deployer);
    const facetNames = [
        'AccessControlFacet',
        'UniswapV3Facet',
        'OReadFacet',
        'MathFacet',
        'ProportionFacet',
        'ZapFacet'
    ];
    await deployFacets(facetNames, deployer);
    const cut = await prepareCut(facetNames, zap.address, deployer);
    await updateFacets(cut, zap.address);
    await updateAbi(name, zap, facetNames);

    zap = await ethers.getContract(name);
    let zapParams = {
        inchRouter: "0x111111125421cA6dc452d289314280a0f8842A65",
        binSearchIterations: 20,
        remainingLiquidityThreshold: 1
    };
    let protocolParams = {
        npm: "0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1",
        eid: 30184
    };

    let lzParams = {
        amount0: 0n,
        amount1: 0n,
        oread: "0x0B409D8f7DB675D23206e06a372Fede0719B23ba"
    }
    
    await (await zap.setZapParams(zapParams)).wait();
    await (await zap.setProtocolParams(protocolParams)).wait();
    await (await zap.setLzStorage(lzParams)).wait();
    console.log('setParams done()');
};

module.exports.tags = [name];
