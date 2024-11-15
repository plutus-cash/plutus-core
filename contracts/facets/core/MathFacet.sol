//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "../../interfaces/IMasterFacet.sol";
import "../../interfaces/Constants.sol";

contract MathFacet is IMathFacet, Modifiers {
    
    function getCurrentPrice(address pair, uint32 eid) external view returns (uint256) {
        (uint256 dec0,) = IMasterFacet(address(this)).getPoolDecimals(pair);
        uint160 sqrtRatioX96 = IMasterFacet(address(this)).getPoolSqrtRatioX96(pair);
        return (IMasterFacet(address(this)).mulDiv(uint256(sqrtRatioX96) * 10 ** (dec0 + PRECISION_DEC), uint256(sqrtRatioX96), 2 ** (96 + 96)));
    }

    function getTickSpacing(address pair) external view returns (int24) {
        return IMasterFacet(address(this)).getPoolTickSpacing(pair);
    }

    function tickToPrice(address pair, int24 tick) external view returns (uint256) {
        (uint256 dec0,) = IMasterFacet(address(this)).getPoolDecimals(pair);
        uint256 dec = 10 ** (dec0 + PRECISION_DEC);
        uint160 sqrtRatioX96 = IMasterFacet(address(this)).getSqrtRatioAtTick(tick);
        return (_getPriceBySqrtRatio(sqrtRatioX96, dec));
    }

    // NOTE: prices should be multiplied by 10 ** PRECISION_DEC
    function priceToClosestTick(address pair, uint256[] memory prices) external view returns (int24[] memory) {
        (uint256 dec0,) = IMasterFacet(address(this)).getPoolDecimals(pair);
        uint256 dec = 10 ** (dec0 + PRECISION_DEC);
        int24 tickSpacing = IMasterFacet(address(this)).getPoolTickSpacing(pair);

        int24[] memory closestTicks = new int24[](prices.length);
        for (uint256 i = 0; i < prices.length; i++) {
            uint160 sqrtRatioX96 = _getSqrtRatioByPrice(prices[i], dec);
            int24 currentTick = IMasterFacet(address(this)).getTickAtSqrtRatio(sqrtRatioX96);
            if (currentTick % tickSpacing >= 0) {
                closestTicks[i] = currentTick - currentTick % tickSpacing;
            } else {
                closestTicks[i] = currentTick - tickSpacing - (currentTick % tickSpacing);
            }
        }
        return closestTicks;
    }
    
    function getCurrentPoolTick(address pair) external view returns (int24) {
        return IMasterFacet(address(this)).getPoolTick(pair);
    }

    function closestTicksForCurrentTick(address pair) external view returns (int24 left, int24 right) {
        int24 tick = IMasterFacet(address(this)).getPoolTick(pair);
        int24 tickSpacing = IMasterFacet(address(this)).getPoolTickSpacing(pair);
        if (tick % tickSpacing >= 0) {
            left = tick - tick % tickSpacing;
            right = tick + tickSpacing - (tick % tickSpacing);
        } else {
            left = tick - tickSpacing - (tick % tickSpacing);
            right = tick - (tick % tickSpacing);
        }
    }

    function _getSqrtRatioByPrice(uint256 price, uint256 decimals) internal view returns (uint160) {
        return IMasterFacet(address(this)).toUint160(_sqrt(IMasterFacet(address(this)).mulDiv(price, 2 ** 192, decimals)));
    }

    function _getPriceBySqrtRatio(uint160 sqrtRatio, uint256 decimals) internal view returns (uint256) {
        return IMasterFacet(address(this)).mulDiv(uint256(sqrtRatio), uint256(sqrtRatio) * decimals, 2 ** 192);
    }

    function _sqrt(uint y) internal pure returns (uint z) {
        z = 0;
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function compareRatios(uint256 a, uint256 b, uint256 c, uint256 d) external pure returns (bool) {
        return a * d > b * c;
    }
}
