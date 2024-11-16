const { deployments, ethers } = require('hardhat');
const { mergeABIs } = require('hardhat-deploy/dist/src/utils');

async function getOrDeploy(name, deployer, skipIfAlreadyDeployed) {
    return await deployments.deploy(name, {
        from: deployer,
        args: [],
        log: true,
        skipIfAlreadyDeployed: skipIfAlreadyDeployed,
    });
}

async function deployDiamond(name, deployer) {
    let diamondCutFacet = await getOrDeploy('DiamondCutFacet', deployer, true);
    let diamondLoupeFacet = await getOrDeploy('DiamondLoupeFacet', deployer, true);
    try {
        let contract = await ethers.getContract(name);
        console.log(`Diamond: ${name} already deployed at ${contract.address}`);
        return contract;
    } catch (e) {
        const diamond = await deployments.deploy('Diamond', {
            from: deployer,
            args: [deployer, diamondCutFacet.address],
            log: true,
            skipIfAlreadyDeployed: false,
        });
        console.log(`Diamond: ${name} deployed at ` + diamond.address);

        const cut = [];
        cut.push({
            facetAddress: diamondLoupeFacet.address,
            action: FacetCutAction.Add,
            functionSelectors: getSelectors(await ethers.getContractFactory('DiamondLoupeFacet')),
        });

        const diamondCut = await ethers.getContractAt('IDiamondCut', diamond.address);
        await (await diamondCut.diamondCut(cut, ethers.constants.AddressZero, '0x')).wait();
        console.log('Add DiamondLoupeFacet to Diamond');

        const facets = [];
        facets.push(await ethers.getContractFactory('DiamondCutFacet'));
        facets.push(await ethers.getContractFactory('DiamondLoupeFacet'));
        let abi = await mergeABIFacets(facets);
        await deployments.delete('Diamond');
        delete diamond['abi'];

        await deployments.save(name, {
            address: diamond.address,
            abi: abi,
            ...diamond,
        });
        return await ethers.getContract(name);
    }
}

async function mergeABIFacets(facets) {
    let primaryABI = [];
    for (let i = 0; i < facets.length; i++) {
        let facet = facets[i];

        if (facet.interface) {
            let items = JSON.parse(facet.interface.format(ethers.utils.FormatTypes.json));
            primaryABI.push(...items);
        } else {
            console.log(`Facet: ${facet.name} not has field: interface`);
        }
    }

    return mergeABIs([primaryABI]);
}

async function getCurrentFacets(address) {
    let contract = await ethers.getContractAt(require('./abi/DIAMOND_LOUPLE.json'), address);
    return await contract.facets();
}

async function prepareCut(facetNames, address) {
    console.log(`Prepare cut for Diamond: ${address} ...`);

    let diamondFacets = ['DiamondCutFacet', 'DiamondLoupeFacet'];

    let facetFactories = await getFacetFactories(facetNames);
    facetFactories.push(...(await getFacetFactories(diamondFacets)));

    const oldSelectors = [];
    const oldSelectorsFacetAddress = {};

    const newSelectors = [];
    const newSelectorsFacetAddress = {};
    const newSelectorsFacetNames = {};

    const facetCuts = [];
    let printItems = [];

    let oldFacets = await getCurrentFacets(address);
    for (const oldFacet of oldFacets) {
        for (const selector of oldFacet.functionSelectors) {
            oldSelectors.push(selector);
            oldSelectorsFacetAddress[selector] = oldFacet.facetAddress;
        }
    }
    const newFacets = await getFacets(facetNames);
    for (const newFacet of newFacets) {
        for (const selector of newFacet.functionSelectors) {
            newSelectors.push(selector);
            newSelectorsFacetAddress[selector] = newFacet.facetAddress;
            newSelectorsFacetNames[selector] = newFacet.facetName;
        }
    }
    for (let newSelector of newSelectors) {
        // Method exist in old facet and new facet
        if (oldSelectors.indexOf(newSelector) >= 0) {
            let oldFacetAddress = oldSelectorsFacetAddress[newSelector].toLowerCase();
            let newFacetAddress = newSelectorsFacetAddress[newSelector].toLowerCase();

            if (oldFacetAddress === newFacetAddress) {
                // Update not needed because bytecode not changed

                printItems.push({
                    name: newSelectorsFacetNames[newSelector],
                    address: oldFacetAddress,
                    selector: newSelector,
                    method: getFunctionNameBySelector(facetFactories, newSelector),
                    action: 'Nothing',
                });
            } else {
                // Update method by replace on a new address Facet
                facetCuts.push({
                    facetAddress: newFacetAddress,
                    functionSelectors: newSelector,
                    action: FacetCutAction.Replace,
                });

                printItems.push({
                    name: newSelectorsFacetNames[newSelector],
                    address: newFacetAddress,
                    selector: newSelector,
                    method: getFunctionNameBySelector(facetFactories, newSelector),
                    action: getFacetActionName(FacetCutAction.Replace),
                });
            }
        } else {
            let newFacetAddress = newSelectorsFacetAddress[newSelector].toLowerCase();
            facetCuts.push({
                facetAddress: newFacetAddress,
                functionSelectors: newSelector,
                action: FacetCutAction.Add,
            });
            printItems.push({
                name: newSelectorsFacetNames[newSelector],
                address: newFacetAddress,
                selector: newSelector,
                method: getFunctionNameBySelector(facetFactories, newSelector),
                action: getFacetActionName(FacetCutAction.Add),
            });
        }
    }
    console.table(printItems);

    if (facetCuts.length === 0) {
        console.log('All facets methods already updated');
        return [];
    } else {
        return convertToCut(facetCuts);
    }
}

function getFunctionNameBySelector(facetFactories, selector) {
    for (const facetFactory of facetFactories) {
        for (const [key, value] of Object.entries(facetFactory.interface.functions)) {
            let sighash = facetFactory.interface.getSighash(value.name);
            if (sighash === selector) {
                return value.name;
            }
        }
    }
    return '-';
}

function convertToCut(facetCuts) {
    for (let facetCut of facetCuts) {
        facetCut.functionSelectors = [facetCut.functionSelectors];
    }
    return facetCuts;
}

async function updateAbi(name, contract, facetsNames) {
    let diamondFacets = ['DiamondCutFacet', 'DiamondLoupeFacet'];
    let facetFactories = await getFacetFactories(facetsNames);
    facetFactories.push(...(await getFacetFactories(diamondFacets)));

    let abi = await mergeABIFacets(facetFactories);
    await deployments.delete(name);
    delete contract['abi'];
    await deployments.save(name, {
        address: contract.address,
        abi: abi,
        ...contract,
    });
    console.log(`${name}:${contract.address} updated ABI`);
}

async function getFacets(facetNames) {
    const facets = [];
    for (let facetName of facetNames) {
        let facet;
        if (hre.network.name === 'localhost') {
            facet = await getContract(facetName);
        } else {
            try {
                facet = await ethers.getContract(facetName);
            } catch (e) {
                facet = await getContract(facetName);
            }
        }
        const newFacet = {
            facetAddress: facet.address,
            functionSelectors: getSelectors(facet),
            facetName: facetName,
        };
        facets.push(newFacet);
    }
    return facets;
}

function getFacetActionName(action) {
    switch (action) {
        case 0:
            return 'Add';
        case 1:
            return 'Replace';
        case 2:
            return 'Remove';
        default:
            throw new Error('Unknown mapping action: ' + action);
    }
}

async function updateFacets(cut, address, deployer) {
    console.log(`${address}.diamondCut ...`);
    let strategy = await ethers.getContractAt('IDiamondCut', address);
    await (await strategy.diamondCut(cut, ethers.constants.AddressZero, '0x', {gasLimit: 15000000})).wait();
    console.log(`${address}.diamondCut done()`);
}

const FacetCutAction = { Add: 0, Replace: 1, Remove: 2 }

async function deployFacets(facetNames, deployer) {
    const facets = [];
    for (let facetName of facetNames) {
        let oldContract;
        try {
            oldContract = await ethers.getContract(facetName);
        } catch (e) { }

        let newFacetContract;

        if (facetName == "OReadFacet") {
            newFacetContract = await deployments.deploy(facetName, {
                from: deployer,
                args: ["0x1a44076050125825900e736c501f859c50fE728c", 4294967295],
                log: true,
                skipIfAlreadyDeployed: false,
            });
        } else {
            newFacetContract = await deployments.deploy(facetName, {
                from: deployer,
                args: [],
                log: true,
                skipIfAlreadyDeployed: false,
            });
        }

        if (
            oldContract !== undefined &&
            (newFacetContract === undefined || (oldContract.address.toLowerCase() === newFacetContract.address.toLowerCase()))
        ) {
            console.log(`${facetName} no update required`);
        } else {
            console.log(`${facetName} deployed at ${newFacetContract.address}`);
        }
        facets.push(await ethers.getContractFactory(facetName));
    }
    return facets;
}

async function getFacetFactories(facetNames) {
    const facets = [];
    for (let facetName of facetNames) {
        try {
            let facet;
            try {
                facet = await ethers.getContractFactory(facetName);
            } catch (e) {
                facet = await getContract(facetName);
            }
            facet.name = facetName;
            facets.push(facet);
            console.log(`Success load factory: ${facetName}`);
        } catch (e) {
            console.log(`Cannot get factory: ${facetName} -> e: ${e}`);
        }
    }
    return facets;
}

function getSelectors(contract) {
    const signatures = Object.keys(contract.interface.functions)
    const selectors = signatures.reduce((acc, val) => {
        if (val !== 'init(bytes)') {
            acc.push(contract.interface.getSighash(val))
        }
        return acc
    }, [])
    selectors.contract = contract
    selectors.remove = remove
    selectors.get = get
    return selectors
}

// used with getSelectors to remove selectors from an array of selectors
// functionNames argument is an array of function signatures
function remove (functionNames) {
    const selectors = this.filter((v) => {
        for (const functionName of functionNames) {
            if (v === this.contract.interface.getSighash(functionName)) {
                return false
            }
        }
        return true
    })
    selectors.contract = this.contract
    selectors.remove = this.remove
    selectors.get = this.get
    return selectors
}

function get(functionNames) {
    const selectors = this.filter((v) => {
        for (const functionName of functionNames) {
            if (v === this.contract.interface.getSighash(functionName)) {
                return true
            }
        }
        return false
    })
    selectors.contract = this.contract
    selectors.remove = this.remove
    selectors.get = this.get
    return selectors
}

module.exports = {
    mergeABIFacets: mergeABIFacets,
    updateAbi: updateAbi,
    deployDiamond: deployDiamond,
    prepareCut: prepareCut,
    updateFacets: updateFacets,
    getFacets: getFacets,
    deployFacets: deployFacets,
    getSelectors: getSelectors,
    FacetCutAction: FacetCutAction,
    remove: remove,
};