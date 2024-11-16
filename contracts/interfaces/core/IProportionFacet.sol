//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/// @title IProportionFacet Interface
/// @notice Interface for the ProportionFacet which computes token ratios in a liquidity pool
interface IProportionFacet {

    struct InputSwapToken {
        address tokenAddress;
        uint256 amount;
        uint256 price;
    }

    struct GetProportionRequest {
        address pair;
        int24[] tickRange;
        InputSwapToken[] inputTokens;
        uint256[] tokenIds;
    }

    struct ResultOfProportion {
        address[] inputTokenAddresses;
        uint256[] inputTokenAmounts;
        address[] outputTokenAddresses;
        uint256[] outputTokenProportions;
        uint256[] outputTokenAmounts;
        uint256[] poolProportionsUsd;
    }

    /// @notice Calculates the proportion for a given pool and tick range
    /// @param pair The address of the token pool
    /// @param tickRange The range of position in ticks
    /// @return The proportion of the pool in abstract measurements
    function getProportion(
        address pair,
        int24[] memory tickRange
    ) external view returns (uint256, uint256);

    function getProportionForZap(
        GetProportionRequest memory request
    ) external view returns (ResultOfProportion memory result);
}
