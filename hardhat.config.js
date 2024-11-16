require('hardhat-deploy');
require("@nomiclabs/hardhat-waffle");
const dotenv = require('dotenv/config');

const ETH_NODE_URI="https://rpc.ankr.com/eth"
const BASE_NODE_URI="https://rpc.ankr.com/base"
BLOCK_NUMBER = 1

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
      accounts: [process.env.PK]
    }
  }
};

