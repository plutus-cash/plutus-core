const { ethers } = require("hardhat");
const hre = require("hardhat");
const { deployDiamond, deployFacets, prepareCut, updateFacets, updateAbi } = require("../util");

const name = 'UniswapV3Arb';

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
        inchRouter: "0x111111125421cA6dc452d289314280a0f8842A65"
    };
    let protocolParams = {
        npm: "0xC36442b4a4522E871399CD717aBDD847Ab11FE88",
        eid: 30110
    };

    let lzParams = {
        amount0: 0n,
        amount1: 0n,
        oread: "0x5be0CC1EF5b089d6cB4958910cc3dccD6AafB7Ae"
    }
    
    await (await zap.setZapParams(zapParams)).wait();
    await (await zap.setProtocolParams(protocolParams)).wait();
    await (await zap.setLzStorage(lzParams)).wait();
    console.log('setParams done()');
};

module.exports.tags = [name];
