require('hardhat-deploy');
require("@nomiclabs/hardhat-waffle");
const dotenv = require('dotenv/config');

const ETH_NODE_URI="https://rpc.ankr.com/eth";
const BASE_NODE_URI="https://rpc.ankr.com/base";
const OP_NODE_URI="https://rpc.ankr.com/optimism";
const ARB_NODE_URI="https://rpc.ankr.com/arbitrum";
const BLOCK_NUMBER = 1;

module.exports = {
  namedAccounts: {
    deployer: {
      default: 0
  },
  recipient: {
      default: 1,
  },
  anotherAccount: {
      default: 2
  }
  },
  solidity: {
    version: "0.8.27",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000,
      },
    },
  },
  networks: {
    hardhat: {
      forking: {
          url: BASE_NODE_URI,
          blockNumber: BLOCK_NUMBER,
      },  
    },
    base: {
      url: BASE_NODE_URI,
      chainId: 8453,
      accounts: [process.env.PK],
      gasPrice: "auto"
    },
    arbitrum: {
      url: ARB_NODE_URI,
      chainId: 42161,
      accounts: [process.env.PK],
      gasPrice: "auto"
    }
  },
  etherscan: {
    apiKey: {
        mainnet: "YOUR_ETHERSCAN_API_KEY",
        optimisticEthereum: "YOUR_OPTIMISTIC_ETHERSCAN_API_KEY",
        arbitrum: "U9MN9J48117ABB7I594GF9FKW85IQJGA72",
    }
  }
};