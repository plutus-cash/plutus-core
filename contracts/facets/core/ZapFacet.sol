//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "../../interfaces/IMasterFacet.sol";

contract ZapFacet is IZapFacet, Modifiers {

    bytes32 internal constant ZAP_STORAGE_POSITION = keccak256("zap.storage");

    function zapStorage() internal pure returns (ZapStorage storage ds) {
        bytes32 position = ZAP_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    function setZapParams(ZapStorage memory args) external onlyAdmin {
        
        require(args.slippageBps != 0, 'slippageBps is empty');
        require(args.binSearchIterations != 0, 'binSearchIterations is empty');
        
        zapStorage().slippageBps = args.slippageBps;
        zapStorage().binSearchIterations = args.binSearchIterations;
        zapStorage().remainingLiquidityThreshold = args.remainingLiquidityThreshold;
    }

    function slippageBps() public view returns (uint256) {
        return zapStorage().slippageBps;
    }

    function remainingLiquidityThreshold() public view returns (uint256) {
        return zapStorage().remainingLiquidityThreshold;
    }

    function zapIn(SwapData memory swapData, ZapInParams memory paramsData) external {
        _zapIn(swapData, paramsData, true);
    }

    function zapOut(uint256 tokenId) external {
        IMasterFacet(address(this)).isValidPosition(tokenId);
        IMasterFacet(address(this)).isNotStakedPosition(tokenId);

        _zapOut(tokenId, msg.sender, msg.sender);
    }


    struct PoolTokens {
        address[] token;
        IERC20[] asset;
        uint256[] amount;
    }

    struct TokenAmounts {
        address[] tokens;
        uint256[] initial;
        uint256[] put;
        uint256[] returned;
    }

    function _zapIn(
        SwapData memory swapData,
        ZapInParams memory paramsData,
        bool needTransfer
    ) internal {
        _validateInputs(swapData, paramsData);
        for (uint256 i = 0; i < swapData.inputs.length; i++) {
            IERC20 asset = IERC20(swapData.inputs[i].tokenAddress);
            if (needTransfer) {
                asset.transferFrom(msg.sender, address(this), swapData.inputs[i].amountIn);
            }
            asset.approve(odosRouter(), swapData.inputs[i].amountIn);
        }
        _swapOdos(swapData);
        PoolTokens memory poolTokens = PoolTokens({
            token: new address[](2),
            asset: new IERC20[](2),
            amount: new uint256[](2)
        });
        TokenAmounts memory tokenAmounts = TokenAmounts({
            tokens: new address[](2),
            initial: new uint256[](2),
            put: new uint256[](2),
            returned: new uint256[](2)
        });
        (poolTokens.token[0], poolTokens.token[1]) = IMasterFacet(address(this)).getPoolTokens(paramsData.pool);
        tokenAmounts.tokens = poolTokens.token;
        for (uint256 i = 0; i < 2; i++) {
            poolTokens.asset[i] = IERC20(poolTokens.token[i]);
            if (needTransfer && paramsData.amountsOut[i] > 0) {
                poolTokens.asset[i].transferFrom(msg.sender, address(this), paramsData.amountsOut[i]);
            }
            poolTokens.amount[i] = poolTokens.asset[i].balanceOf(address(this));
            paramsData.amountsOut[i] = poolTokens.amount[i];
        }
        tokenAmounts.initial = poolTokens.amount;
        uint256[] memory positionAmounts = new uint256[](2);
        uint256[] memory newPositionAmounts = new uint256[](2);
        if (paramsData.tokenId != 0) {
            (positionAmounts[0], positionAmounts[1]) = IMasterFacet(address(this)).getPositionAmounts(paramsData.tokenId);
        }
        
        paramsData.tokenId = _manageLiquidity(paramsData, poolTokens);
        if (_checkRemainingLiquidity(paramsData, poolTokens)) {
            _adjustSwap(paramsData, poolTokens);
        }
        (newPositionAmounts[0], newPositionAmounts[1]) = IMasterFacet(address(this)).getPositionAmounts(paramsData.tokenId);

        for (uint256 i = 0; i < 2; i++) {
            if (newPositionAmounts[i] > positionAmounts[i]) {
                tokenAmounts.put[i] = newPositionAmounts[i] - positionAmounts[i];
            }
            tokenAmounts.returned[i] = poolTokens.asset[i].balanceOf(address(this));
            if (tokenAmounts.returned[i] > 0) {
                poolTokens.asset[i].transfer(msg.sender, tokenAmounts.returned[i]);
            }
        }
        for (uint256 i = 0; i < swapData.inputs.length; i++) {
            IERC20 asset = IERC20(swapData.inputs[i].tokenAddress);
            uint256 balance = asset.balanceOf(address(this));
            if (balance > 0) {
                asset.transfer(msg.sender, balance);
            }
        }
        if (!paramsData.isSimulation) {
            emit ZapResult(tokenAmounts.tokens, tokenAmounts.initial, tokenAmounts.put, tokenAmounts.returned);
        } else {
            revert SimulationResult(
                tokenAmounts.tokens, 
                tokenAmounts.initial, 
                tokenAmounts.put, 
                tokenAmounts.returned, 
                paramsData.adjustSwapAmount, 
                paramsData.adjustSwapSide
            );
        }
    }

    function _zapOut(uint256 tokenId, address recipient, address feeRecipient) internal {
        IMasterFacet(address(this)).isOwner(tokenId, msg.sender);
        IMasterFacet(address(this)).closePosition(tokenId, recipient, feeRecipient);
    }

    function _validateInputs(SwapData memory swapData, ZapInParams memory paramsData) internal view {
        for (uint256 i = 0; i < swapData.inputs.length; i++) {
            for (uint256 j = 0; j < i; j++) {
                require(
                    swapData.inputs[i].tokenAddress != swapData.inputs[j].tokenAddress,
                    "Duplicate input tokens"
                );
            }
            require(swapData.inputs[i].amountIn > 0, "Input amount is 0");
        }

        require(paramsData.amountsOut.length == 2, "Invalid output length, must be exactly 2");
        require(IMasterFacet(address(this)).isValidPool(paramsData.pool), "Pool address in not valid");
        require(paramsData.tickRange.length == 2, "Invalid tick range length, must be exactly 2");
        require(paramsData.poolTokenPrices.length == 2, "Invalid pool token prices length, must be exactly 2");
        require(paramsData.tickRange[0] < paramsData.tickRange[1], "Invalid tick range");
    }

    function _swapOdos(SwapData memory swapData) internal {
        if (swapData.inputs.length > 0) {
            (bool success,) = odosRouter().call{value: 0}(swapData.data);
            // require(success, _getRevertReason(result, "router swap invalid"));
            require(success,  "router swap invalid");
        }

        for (uint256 i = 0; i < swapData.outputs.length; i++) {
            uint256 amountOut = IERC20(swapData.outputs[i].tokenAddress).balanceOf(address(this));
            if (amountOut < swapData.outputs[i].amountMin) {
                revert BelowAmountMin({
                    tokenAddress: swapData.outputs[i].tokenAddress,
                    amountMin: swapData.outputs[i].amountMin,
                    amountReceived: amountOut
                });
            }
        }
        {
            address[] memory tokensIn = new address[](swapData.inputs.length);
            uint256[] memory amountsIn = new uint256[](swapData.inputs.length);
            for (uint256 i = 0; i < swapData.inputs.length; i++) {
                tokensIn[i] = swapData.inputs[i].tokenAddress;
                amountsIn[i] = swapData.inputs[i].amountIn;
            }
            emit InputTokens(tokensIn, amountsIn);
        }
        {
            address[] memory tokensOut = new address[](swapData.outputs.length);
            uint256[] memory amountsOut = new uint256[](swapData.outputs.length);
            for (uint256 i = 0; i < swapData.outputs.length; i++) {
                tokensOut[i] = swapData.outputs[i].tokenAddress;
                amountsOut[i] = IERC20(tokensOut[i]).balanceOf(address(this));
            }
            emit OutputTokens(tokensOut, amountsOut);
        }
    }

    function _manageLiquidity(ZapInParams memory paramsData, PoolTokens memory poolTokens) internal returns (uint256) {
        poolTokens.asset[0].approve(IProtocolFacet(address(this)).npm(), poolTokens.amount[0]);
        poolTokens.asset[1].approve(IProtocolFacet(address(this)).npm(), poolTokens.amount[1]);

        if (paramsData.tokenId == 0) {
            paramsData.tokenId = IMasterFacet(address(this)).mintPosition(
                paramsData.pool,
                paramsData.tickRange[0],
                paramsData.tickRange[1],
                poolTokens.amount[0],
                poolTokens.amount[1],
                msg.sender
            );
            emit TokenId(paramsData.tokenId);
        } else {
            IMasterFacet(address(this)).increaseLiquidity(paramsData.tokenId, poolTokens.amount[0], poolTokens.amount[1]);
        }
        return paramsData.tokenId;
    }

    function _adjustSwap(
        ZapInParams memory paramsData,
        PoolTokens memory poolTokens
    ) internal {
        if (paramsData.isSimulation) {
            (paramsData.adjustSwapAmount, paramsData.adjustSwapSide) = _simulateSwap(paramsData, poolTokens);
        }
        if (paramsData.adjustSwapAmount == 0) {
            return;
        }
        IMasterFacet(address(this)).swap(paramsData.pool, paramsData.adjustSwapAmount, 0, paramsData.adjustSwapSide);
        paramsData.amountsOut[0] = poolTokens.asset[0].balanceOf(address(this));
        paramsData.amountsOut[1] = poolTokens.asset[1].balanceOf(address(this));
        poolTokens.asset[0].approve(IProtocolFacet(address(this)).npm(), paramsData.amountsOut[0]);
        poolTokens.asset[1].approve(IProtocolFacet(address(this)).npm(), paramsData.amountsOut[1]);

        IMasterFacet(address(this)).increaseLiquidity(paramsData.tokenId, paramsData.amountsOut[0], paramsData.amountsOut[1]);
    }

    struct BinSearchParams {
        uint256 left;
        uint256 right;
        uint256 mid;
    }

    function _simulateSwap(
        ZapInParams memory paramsData, 
        PoolTokens memory poolTokens
    ) internal returns (uint256 amountToSwap, bool zeroForOne) {
        zeroForOne = poolTokens.asset[0].balanceOf(address(this)) > poolTokens.asset[1].balanceOf(address(this));
        BinSearchParams memory binSearchParams;
        binSearchParams.right = poolTokens.asset[zeroForOne ? 0 : 1].balanceOf(address(this));
        for (uint256 i = 0; i < binSearchIterations(); i++) {
            binSearchParams.mid = (binSearchParams.left + binSearchParams.right) / 2;
            if (binSearchParams.mid == 0) {
                break;
            }
            try IMasterFacet(address(this)).simulateSwap(
                paramsData.pool, 
                binSearchParams.mid, 
                0, 
                zeroForOne, 
                paramsData.tickRange
            ) 
            {} 
            catch Error(string memory) {
                break;
            }
            catch (bytes memory _data) {
                bytes memory data;
                assembly {
                    data := add(_data, 4)
                }
                uint256[] memory swapResult = new uint256[](4);
                (swapResult[0], swapResult[1], swapResult[2], swapResult[3]) = abi.decode(data, (uint256, uint256, uint256, uint256));
                bool compareResult = zeroForOne ? 
                    IMasterFacet(address(this)).compareRatios(swapResult[0], swapResult[1], swapResult[2], swapResult[3]) : 
                    IMasterFacet(address(this)).compareRatios(swapResult[1], swapResult[0], swapResult[3], swapResult[2]);
                if (compareResult) {
                    binSearchParams.left = binSearchParams.mid;
                } else {
                    binSearchParams.right = binSearchParams.mid;
                }
            }
        }
        amountToSwap = binSearchParams.mid;
    }

    function _checkRemainingLiquidity(ZapInParams memory paramsData, PoolTokens memory poolTokens) internal view returns (bool) {
        (uint256 decimals0, uint256 decimals1) = IMasterFacet(address(this)).getPoolDecimals(paramsData.pool);
        uint256 tokenAmount0Usd = IMasterFacet(address(this)).mulDiv(
            poolTokens.asset[0].balanceOf(address(this)), 
            paramsData.poolTokenPrices[0], 
            10 ** decimals0
        );
        uint256 tokenAmount1Usd = IMasterFacet(address(this)).mulDiv(
            poolTokens.asset[1].balanceOf(address(this)), 
            paramsData.poolTokenPrices[1], 
            10 ** decimals1
        );
        return (tokenAmount0Usd + tokenAmount1Usd) >= BASE_PRICE_DIV * remainingLiquidityThreshold();
    }

    function _getRevertReason(bytes memory returnData, string memory defaultReason) internal pure returns (string memory) {
        // The return data contains the error message in ABI-encoded format
        if (returnData.length < 68) return defaultReason;

        bytes memory revertData = returnData;
        // Remove the selector which is the first 4 bytes
        assembly {
            revertData := add(revertData, 0x04)
        }
        return abi.decode(revertData, (string)); // Decode the revert reason as a string
    }
}
