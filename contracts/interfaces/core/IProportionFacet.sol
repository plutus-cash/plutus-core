//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/// @title IProportionFacet Interface
/// @notice Interface for the ProportionFacet which computes token ratios in a liquidity pool
interface IProportionFacet {
    /// @notice Struct representing an input token for a swap
    /// @param tokenAddress The address of the token
    /// @param amount The amount of the token
    /// @param price The price of the token in USD * 10^18
    struct InputSwapToken {
        address tokenAddress;
        uint256 amount;
        uint256 price;
    }

    /// @notice Calculates the proportion for a given pool and tick range
    /// @param pair The address of the token pool
    /// @param tickRange The range of position in ticks
    /// @return The proportion of the pool in abstract measurements
    function getProportion(
        address pair,
        int24[] memory tickRange
    ) external view returns (uint256, uint256);
}
