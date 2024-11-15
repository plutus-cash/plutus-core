const { ethers } = require("hardhat");
const hre = require("hardhat");
const { ARBITRUM } = require("@overnight-contracts/common/utils/assets");
const { deployDiamond, deployFacets, prepareCut, updateFacets, updateAbi } = require("@overnight-contracts/common/utils/deployDiamond");

const name = 'UniswapV3CLZapArb';

module.exports = async ({ getNamedAccounts, deployments }) => {
    // await transferETH(0.00001, "0x0000000000000000000000000000000000000000");
    const { save, deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    let zap = await deployDiamond(name, deployer);
    const facetNames = [
        'AccessControlFacet',
        'UniswapV3Facet',
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
        odosRouter: ARBITRUM.odosRouterV2,
        slippageBps: 100,
        binSearchIterations: 10,
        remainingLiquidityThreshold: 1
    };
    let protocolParams = {
        npm: ARBITRUM.uniswapNpm
    };

    let versionParams = {
        version: process.env.ZAP_VERSION,
        isDev: process.env.ZAP_IS_DEV
    };
    
    await (await zap.setZapParams(zapParams)).wait();
    await (await zap.setProtocolParams(protocolParams)).wait();
    await (await zap.setVersion(versionParams)).wait();
    console.log('setParams done()');
};

module.exports.tags = [name];
