# Plutus

# [dapp code!!!](https://github.com/plutus-cash/plutus-app) \\
# [backend code!!!](https://github.com/plutus-cash/plutus-backend)

**Plutus** is an innovative decentralized application (dApp) designed to streamline cross-chain liquidity management by leveraging the capabilities of [LayerZero](https://layerzero.network/) and [1inch Fusion+](https://1inch.io/). The platform enables users to seamlessly invest assets from one blockchain into liquidity pools on another while maintaining ownership of their funds throughout the entire process. This approach sets Plutus apart from other aggregators by ensuring users retain control over their assets at all times.

## Table of Contents

- [Features](#features)
- [How It Works](#how-it-works)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
- [Usage](#usage)
- [Technical Details](#technical-details)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [License](#license)
- [Contact](#contact)
- [Acknowledgments](#acknowledgments)

## Features

- **Cross-Chain Liquidity Management**: Invest assets from one blockchain into liquidity pools on another seamlessly.
- **User Ownership**: Maintain ownership of your funds throughout the entire process.
- **LayerZero Integration**: Utilize LayerZero's `lzRead` method to fetch real-time data about liquidity pools on the destination chain.
- **1inch Fusion+ Integration**: Swap assets efficiently with minimal slippage and optimal rates.
- **Security and Transparency**: All transactions are transparent and verifiable on the blockchain, with thoroughly audited smart contracts.

## How It Works

Plutus operates by utilizing the `lzRead` method from LayerZero to fetch real-time data about specific liquidity pools on the destination chain. This data includes crucial information such as token proportions within a specified tick range in a Uniswap V3 pool. With this information, Plutus calculates the exact proportions of tokens needed for the investment on the source chain.

For example, suppose a user holds **1,000 DAI** on the **Optimism** network and wishes to invest in the **Uniswap V3 WETH/USDC** pool on the **Ethereum** network within the tick range **-199,500** to **-175,000**. Plutus determines the required amounts of WETH and USDC based on the pool's state within this specified range. It then creates an order through 1inch Fusion+ to swap the user's DAI into the exact proportions of WETH and USDC needed. The swapped tokens are prepared for cross-chain transfer to the Ethereum network.

Upon arrival on Ethereum, the tokens are automatically deposited into the specified Uniswap V3 pool within the desired tick range. Throughout the entire process, users retain ownership of their funds. Plutus's smart contracts are designed to operate without taking custody of user assets, enhancing security.

## Getting Started

### Prerequisites

- **Node.js** and **npm** installed on your machine.
- **Metamask** or any Ethereum-compatible wallet.
- Funds in your wallet on the source chain (e.g., DAI on Optimism).

### Installation

1. **Clone the Repository**

   ```bash
   git clone https://github.com/yourusername/plutus.git
   ```

2. **Navigate to the Project Directory**

   ```bash
   cd plutus-core
   ```

3. **Install Dependencies**

   ```bash
   yarn
   ```

## Usage

1. **Connect Your Wallet**

   - Open the dApp and connect your Ethereum-compatible wallet.

2. **Specify Investment Preferences**

   - Enter the amount you wish to invest.
   - Select the source asset and source chain.
   - Choose the destination liquidity pool and specify the tick range.

3. **Review Transaction Details**

   - Verify the calculated token proportions and transaction summary.

4. **Confirm and Execute**

   - Confirm the transaction in your wallet.
   - The dApp will handle swapping, cross-chain transfer, and investment automatically.

5. **Monitor Your Investment**

   - Track your liquidity positions directly through Plutus or any compatible DeFi dashboard.

## Technical Details

- **LayerZero Integration**: Utilizes LayerZero's `lzRead` for cross-chain data retrieval.
- **1inch Fusion+**: Swaps assets on the source chain with optimal rates and minimal slippage.
- **Smart Contracts**: Designed to ensure users maintain ownership of their assets throughout the process.
- **Cross-Chain Mechanism**: Securely transfers assets between source and destination chains.

## Roadmap

- **Single-Transaction Process**: Streamline the entire investment process into a single transaction.
- **Expanded Network Support**: Integrate additional blockchain networks.
- **Advanced Strategies**: Implement automated rebalancing and yield optimization tools.
- **Governance Mechanisms**: Develop community governance for platform development.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request for any bugs, feature requests, or improvements.

## License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for details.

## Contact

- **Email**: [ramil.amirov.2004@gmail.com](mailto:ramil.amirov.2004@gmail.com)
- **Twitter**: [@mcp0x](https://x.com/mcp0x)
- **Telegram**: [@r8mych](https://t.me/r8mych)

## Acknowledgments

- [LayerZero](https://layerzero.network/) for cross-chain communication.
- [1inch](https://1inch.io/) for efficient asset swapping.
- [Uniswap V3](https://uniswap.org/) for liquidity pools.

---

*Plutus is committed to revolutionizing cross-chain liquidity management by providing a secure, efficient, and user-centric platform.*