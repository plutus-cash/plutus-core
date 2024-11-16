//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "../../interfaces/IMasterFacet.sol";
import "../../interfaces/Modifiers.sol";
import "../../interfaces/Constants.sol";
import { TickMath, LiquidityAmounts } from "../../libraries/util/Math.sol";

contract ProportionFacet is IProportionFacet, Modifiers {

    function getProportion(
        address pair,
        int24[] memory tickRange,
        uint32 _eid
    ) public view returns (uint256 token0Amount, uint256 token1Amount) {
        (uint256 decimals0, uint256 decimals1) = IMasterFacet(address(this)).getPoolDecimals(pair, _eid);
        uint256 dec0 = 10 ** decimals0;
        uint256 dec1 = 10 ** decimals1;
        uint160 sqrtRatioX96 = IMasterFacet(address(this)).getPoolSqrtRatioX96(pair, _eid);

        uint160 sqrtRatio0 = TickMath.getSqrtRatioAtTick(tickRange[0]);
        uint160 sqrtRatio1 = TickMath.getSqrtRatioAtTick(tickRange[1]);
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(sqrtRatioX96, sqrtRatio0, sqrtRatio1, dec0 * 1000, dec1 * 1000);
        (token0Amount, token1Amount) = LiquidityAmounts.getAmountsForLiquidity(sqrtRatioX96, sqrtRatio0, sqrtRatio1, liquidity);
        uint256 denominator = dec0 > dec1 ? dec0 : dec1;

        token0Amount = token0Amount * (denominator / dec0);
        token1Amount = token1Amount * (denominator / dec1);
    }
}
