//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/**
 * @title IProtocolFacet
 * @dev Interface for the Protocol Facet
 * This interface defines the structure and functions for managing liquidity positions
 * in a DEX environment.
 */
interface IProtocolFacet {

    /// @notice Structure for protocol storage
    /// @param npm The address of the non-fungible position manager
    struct ProtocolStorage {
        address npm;
    }

    struct PoolData {
        address token0;
        address token1;
        uint160 sqrtPriceX96;
        int24 currentTick;
        int24 tickSpacing;
    }

    /// @notice Sets the protocol parameters
    /// @param args The protocol parameters
    function setProtocolParams(ProtocolStorage memory args) external;

    /// @notice Gets the npm address
    function npm() external view returns (address);

    function getPoolData(address pair) external view returns (PoolData memory);

    /**
     * @dev Retrieves the decimal places for both tokens in a pool.
     * @param pair The address of the pool.
     * @return The decimal places for token0 and token1.
     */
    function getPoolDecimals(address pair) external view returns (uint256, uint256);
}