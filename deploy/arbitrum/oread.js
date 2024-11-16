const { ethers } = require("hardhat");
const hre = require("hardhat");
const { deployDiamond, deployFacets, prepareCut, updateFacets, updateAbi } = require("../util");

const name = 'ORead';

module.exports = async ({ getNamedAccounts, deployments }) => {
    const { save, deploy } = deployments;
    const { deployer } = await getNamedAccounts();
    console.log('deployer', deployer);

    console.log(await deployments.deploy(name, {
        from: deployer,
        args: ["0x1a44076050125825900e736c501f859c50fE728c", 4294967295],
        log: true,
        skipIfAlreadyDeployed: false
    }));
}

module.exports.tags = [name];