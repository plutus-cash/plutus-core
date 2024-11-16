import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "dotenv/config"

export const ETH_NODE_URI="https://rpc.ankr.com/eth"
export const BASE_NODE_URI="https://rpc.ankr.com/base"


export const BLOCK_NUMBER=21960475



const config: HardhatUserConfig = {
  solidity: "0.8.27",
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
      accounts: [process.env.PK!]
    }
  }
};

export default config;
