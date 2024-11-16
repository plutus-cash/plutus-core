//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/**
 * @title IProtocolFacet
 * @dev Interface for the Protocol Facet
 * This interface defines the structure and functions for managing liquidity positions
 * in a DEX environment.
 */
interface IProtocolFacet {

    event CollectRewards(uint256 fee0, uint256 fee1);

    /// @notice Structure for protocol storage
    /// @param npm The address of the non-fungible position manager
    struct ProtocolStorage {
        address npm;
        uint32 eid;
    }

    struct PoolData {
        address token0;
        address token1;
        uint160 sqrtPriceX96;
        int24 currentTick;
        int24 tickSpacing;
    }

    error SwapError(uint256 amount0, uint256 amount1, uint256 ratio0, uint256 ratio1);

    /// @notice Sets the protocol parameters
    /// @param args The protocol parameters
    function setProtocolParams(ProtocolStorage memory args) external;

    /// @notice Gets the npm address
    function npm() external view returns (address);

    /// @notice Gets the eid
    function eid() external view returns (uint32);

    function getPoolData(address pair) external view returns (PoolData memory);

    function closePosition(uint256 tokenId, address recipient, address feeRecipient) external;

    function mintPosition(
        address pair,
        int24 tickRange0,
        int24 tickRange1,
        uint256 amountOut0,
        uint256 amountOut1,
        address recipient
    ) external returns (uint256 tokenId);

    function increaseLiquidity(uint256 tokenId, uint256 amount0, uint256 amount1) external returns (uint128 liquidity);

    function swap(
        address pair,
        uint256 amountIn,
        uint160 sqrtPriceLimitX96,
        bool zeroForOne
    ) external;

    function simulateSwap(
        address pair,
        uint256 amountIn,
        uint160 sqrtPriceLimitX96,
        bool zeroForOne,
        int24[] memory tickRange
    ) external;

    /**
     * @dev Retrieves the decimal places for both tokens in a pool.
     * @param pair The address of the pool.
     * @return The decimal places for token0 and token1.
     */
    function getPoolDecimals(address pair, uint32 eid) external view returns (uint256, uint256);

    /**
     * @dev Retrieves the current square root price of a pool.
     * @param pair The address of the pool.
     * @return The current square root price in Q64.96 format.
     */
    function getPoolSqrtRatioX96(address pair, uint32 eid) external view returns (uint160);

    /**
     * @dev Retrieves the tick spacing of a pool.
     * @param pair The address of the pool.
     * @return The tick spacing.
     */
    function getPoolTickSpacing(address pair, uint32 eid) external view returns (int24);

    /**
     * @dev Retrieves the current tick of a pool.
     * @param pair The address of the pool.
     * @return The current tick.
     */
    function getPoolTick(address pair, uint32 eid) external view returns (int24);

    /**
     * @dev Retrieves the addresses of both tokens in a pool.
     * @param pair The address of the pool.
     * @return The addresses of token0 and token1.
     */
    function getPoolTokens(address pair, uint32 eid) external view returns (address, address);

    function getPositionAmounts(uint256 tokenId, uint32 _eid) external view returns (uint256 amount0, uint256 amount1);

    function getPositionTicks(uint256 tokenId, uint32 _eid) external view returns (int24 tickLower, int24 tickUpper);
}