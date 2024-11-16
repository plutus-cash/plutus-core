//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/// @title IZapFacet
/// @notice Interface for the ZapFacet contract, which handles various liquidity management operations
/// @dev This interface defines the structures and functions for zapping in/out, rebalancing, increasing, and merging liquidity positions
interface IZapFacet {

    /// @notice Structure for zap storage
    /// @param odosRouter The address of the odos router
    /// @param slippageBps The slippage basis points
    /// @param binSearchIterations The number of iterations for the secondary swap bin search
    /// @param remainingLiquidityThreshold The remaining liquidity threshold, if sum of token0 and token1 after first increase is more than this, the swap will be adjusted
    struct ZapStorage {
        address odosRouter;
        uint256 slippageBps;
        uint256 binSearchIterations;
        uint256 remainingLiquidityThreshold;
    }

    /// @notice Sets the zap parameters
    /// @param args The zap storage parameters
    function setZapParams(ZapStorage memory args) external;

    /// @notice Gets the slippage basis points
    /// @return The slippage basis points
    function slippageBps() external view returns (uint256);

    /// @notice Structure for input token information
    /// @param tokenAddress The address of the input token
    /// @param amountIn The amount of tokens to input
    struct InputToken {
        address tokenAddress;
        uint256 amountIn;
    }

    /// @notice Structure for pool's tokens information
    /// @param tokenAddress The address of the token
    /// @param amountMin The minimum amount of tokens after the swap
    struct OutputToken {
        address tokenAddress;
        uint256 amountMin;
    }

    /// @notice Structure containing swap data
    /// @param inputs An array of input tokens
    /// @param outputs An array of output tokens
    /// @param data Odos router data
    struct SwapData {
        InputToken[] inputs;
        OutputToken[] outputs;
        bytes data;
    }


    /// @notice Zaps in to a liquidity position
    /// @param swapData The swap data for the zap
    /// @param paramsData The parameters for the zap
    function zapIn(SwapData memory swapData, ZapInParams memory paramsData) external;

    /// @notice Zaps out of a liquidity position
    /// @param tokenId The ID of the token to zap out of
    function zapOut(uint256 tokenId) external;
}
