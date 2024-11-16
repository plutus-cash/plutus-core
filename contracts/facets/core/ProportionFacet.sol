//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "../../interfaces/IMasterFacet.sol";
import "../../interfaces/Modifiers.sol";
import "../../interfaces/Constants.sol";
import { TickMath, LiquidityAmounts, FullMath } from "../../libraries/util/Math.sol";

contract ProportionFacet is IProportionFacet, Modifiers {

    struct OutTokenInfo {
        uint256 idx;
        uint256 amount;
        uint256 amountUsd;
        uint256 prop;
        uint256 propAmount;
        uint256 amountToSwap;
        uint256 outAmount;
        address token;
    }

    function getProportionForZap(
        GetProportionRequest memory request
    ) external view returns (ResultOfProportion memory result) {
        IMasterFacet master = IMasterFacet(address(this));

        uint8[] memory decimals = new uint8[](request.inputTokens.length);
        OutTokenInfo[] memory outTokens = new OutTokenInfo[](2);
        uint256 sumInputsUsd;

        outTokens[0].idx = request.inputTokens.length;
        outTokens[1].idx = request.inputTokens.length;
        (outTokens[0].token, outTokens[1].token) = master.getPoolTokens(request.pair);

        result.inputTokenAddresses = new address[](request.inputTokens.length);
        result.inputTokenAmounts = new uint256[](request.inputTokens.length);
        result.outputTokenAddresses = new address[](2);
        result.outputTokenProportions = new uint256[](2);
        result.outputTokenAmounts = new uint256[](2);
        result.poolProportionsUsd = new uint256[](2);

        for (uint256 i = 0; i < request.tokenIds.length; i++) {
            bool matchTokens;
            (address token0, address token1) = master.getPositionTokens(request.tokenIds[i]);
            (uint256 amount0, uint256 amount1) = master.getPositionAmounts(request.tokenIds[i]);
            for (uint256 j = 0; j < request.inputTokens.length; j++) {
                if (request.inputTokens[j].tokenAddress == token0) {
                    matchTokens = true;
                    request.inputTokens[j].amount += amount0;
                }
                if (request.inputTokens[j].tokenAddress == token1) {
                    matchTokens = true;
                    request.inputTokens[j].amount += amount1;
                }
            }
            if (!matchTokens) {
                revert("Invalid input token address or position id");
            }
        }

        // extract pool tokens from input and calculate total input amount in USD
        for (uint256 i = 0; i < request.inputTokens.length; i++) {
            decimals[i] = IERC20Metadata(request.inputTokens[i].tokenAddress).decimals();
            // prices are in 18 decimals
            uint256 amountUsd = FullMath.mulDiv(request.inputTokens[i].price, request.inputTokens[i].amount, 10 ** decimals[i]);
            sumInputsUsd += amountUsd;
            if (request.inputTokens[i].tokenAddress == outTokens[0].token) {
                outTokens[0].idx = i;
                outTokens[0].amountUsd = amountUsd;
                continue;
            }
            if (request.inputTokens[i].tokenAddress == outTokens[1].token) {
                outTokens[1].idx = i;
                outTokens[1].amountUsd = amountUsd;
                continue;
            }
            // these tokens are not part of the pool and will be used for swap
            result.inputTokenAddresses[i] = request.inputTokens[i].tokenAddress;
            result.inputTokenAmounts[i] = request.inputTokens[i].amount;
        }
        // calculate the proportion of the pool tokens in USD
        (outTokens[0].propAmount, outTokens[1].propAmount) = getProportion(request.pair, request.tickRange);
        uint256 price = master.getCurrentPrice(request.pair);
        outTokens[0].prop = outTokens[0].propAmount * price / (10 ** PRECISION_DEC); 
        outTokens[1].prop = outTokens[0].prop + outTokens[1].propAmount * (10 ** IERC20Metadata(outTokens[1].token).decimals());
        result.poolProportionsUsd[0] = FullMath.mulDiv(sumInputsUsd, outTokens[0].prop, outTokens[1].prop);
        result.poolProportionsUsd[1] = sumInputsUsd - result.poolProportionsUsd[0];

        if (
            result.poolProportionsUsd[0] == outTokens[0].amountUsd && 
            result.poolProportionsUsd[1] == outTokens[1].amountUsd &&
            (outTokens[0].prop == 0 || outTokens[0].prop == outTokens[1].prop)) {
            delete result.inputTokenAddresses;
            delete result.inputTokenAmounts;
            result.outputTokenAmounts[0] = outTokens[0].idx < request.inputTokens.length ? request.inputTokens[outTokens[0].idx].amount : 0;
            result.outputTokenAmounts[1] = outTokens[1].idx < request.inputTokens.length ? request.inputTokens[outTokens[1].idx].amount : 0;
            return result;
        }

        for (uint256 i = 0; i < 2; i++) {
            uint256 j = outTokens[i].idx;
            // if the amount of pool token exceeds the required amount we need to swap
            if (j < request.inputTokens.length && result.poolProportionsUsd[i] < outTokens[i].amountUsd) {
                // swap the exceeded amount
                outTokens[i].amountToSwap = FullMath.mulDiv(outTokens[i].amountUsd - result.poolProportionsUsd[i], 10 ** decimals[j], request.inputTokens[j].price);
                result.inputTokenAddresses[j] = request.inputTokens[j].tokenAddress;
                result.inputTokenAmounts[j] = outTokens[i].amountToSwap;

                // we need another token in full amount
                result.outputTokenAddresses[0] = outTokens[1 - i].token;
                result.outputTokenProportions[0] = BASE_DIV;
                // amount of tokens come directly into pool (without swap)
                result.outputTokenAmounts[i] = request.inputTokens[j].amount - outTokens[i].amountToSwap;
                result.outputTokenAmounts[1 - i] = outTokens[1 - i].idx < request.inputTokens.length ? request.inputTokens[outTokens[1 - i].idx].amount : 0;
                return result;
            }
        }

        // both token amounts are less than required, put both directly into pool (without swap)
        result.outputTokenAddresses[0] = outTokens[0].token;
        result.outputTokenAddresses[1] = outTokens[1].token;
        // proportion of pool +/- direct transfer amount
        result.outputTokenProportions[0] = FullMath.mulDiv(result.poolProportionsUsd[0] - outTokens[0].amountUsd, BASE_DIV,
            (result.poolProportionsUsd[0] + result.poolProportionsUsd[1]) - (outTokens[0].amountUsd + outTokens[1].amountUsd));
        result.outputTokenProportions[1] = BASE_DIV - result.outputTokenProportions[0];
        result.outputTokenAmounts[0] = outTokens[0].idx < request.inputTokens.length ? request.inputTokens[outTokens[0].idx].amount : 0;
        result.outputTokenAmounts[1] = outTokens[1].idx < request.inputTokens.length ? request.inputTokens[outTokens[1].idx].amount : 0;
        return result;
    }

    function getProportion(
        address pair,
        int24[] memory tickRange
    ) public view returns (uint256 token0Amount, uint256 token1Amount) {
        (uint256 decimals0, uint256 decimals1) = IMasterFacet(address(this)).getPoolDecimals(pair);
        uint256 dec0 = 10 ** decimals0;
        uint256 dec1 = 10 ** decimals1;
        uint160 sqrtRatioX96 = IMasterFacet(address(this)).getPoolSqrtRatioX96(pair);

        uint160 sqrtRatio0 = TickMath.getSqrtRatioAtTick(tickRange[0]);
        uint160 sqrtRatio1 = TickMath.getSqrtRatioAtTick(tickRange[1]);
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(sqrtRatioX96, sqrtRatio0, sqrtRatio1, dec0 * 1000, dec1 * 1000);
        (token0Amount, token1Amount) = LiquidityAmounts.getAmountsForLiquidity(sqrtRatioX96, sqrtRatio0, sqrtRatio1, liquidity);
        uint256 denominator = dec0 > dec1 ? dec0 : dec1;

        token0Amount = token0Amount * (denominator / dec0);
        token1Amount = token1Amount * (denominator / dec1);
    }
}
