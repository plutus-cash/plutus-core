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
        require(args.inchRouter != address(0), 'inchRouter is empty');
        require(args.binSearchIterations != 0, 'binSearchIterations is empty');
        
        zapStorage().inchRouter = args.inchRouter;
        zapStorage().binSearchIterations = args.binSearchIterations;
        zapStorage().remainingLiquidityThreshold = args.remainingLiquidityThreshold;
    }

    function inchRouter() public view returns (address) {
        return zapStorage().inchRouter;
    }

    function remainingLiquidityThreshold() public view returns (uint256) {
        return zapStorage().remainingLiquidityThreshold;
    }

    function zapIn(SwapData memory swapData, ZapInParams memory paramsData) external {
        _zapIn(swapData, paramsData, true, 0);
    }

    function zapOut(uint256 tokenId) external {
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
        bool needTransfer,
        uint256 tokenId
    ) internal {
        validateInputs(swapData, paramsData);
        for (uint256 i = 0; i < swapData.inputs.length; i++) {
            IERC20 asset = IERC20(swapData.inputs[i].tokenAddress);
            if (needTransfer) {
                asset.transferFrom(msg.sender, address(this), swapData.inputs[i].amountIn);
            }
            asset.approve(zapStorage().inchRouter, swapData.inputs[i].amountIn);
        }
        swap1Inch(swapData);
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
        if (tokenId != 0) {
            (positionAmounts[0], positionAmounts[1]) = IMasterFacet(address(this)).getPositionAmounts(tokenId);
        }
        tokenId = manageLiquidity(paramsData, poolTokens, tokenId);
        adjustSwap(paramsData, poolTokens, tokenId);
        (newPositionAmounts[0], newPositionAmounts[1]) = IMasterFacet(address(this)).getPositionAmounts(tokenId);

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
        // IMasterFacet(address(this)).isOwner(tokenId, msg.sender);
        IMasterFacet(address(this)).closePosition(tokenId, recipient, feeRecipient);
    }

    function validateInputs(SwapData memory swapData, ZapInParams memory paramsData) internal pure {
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
        require(paramsData.tickRange.length == 2, "Invalid tick range length, must be exactly 2");
        require(paramsData.tickRange[0] < paramsData.tickRange[1], "Invalid tick range");
    }

    function swap1Inch(SwapData memory swapData) internal {
        for (uint256 i = 0; i < swapData.data.length; i++) {
            (bool success,) = zapStorage().inchRouter.call{value : 0}(swapData.data[i]);
            require(success, "router swap invalid");
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

    function manageLiquidity(ZapInParams memory paramsData, PoolTokens memory poolTokens, uint256 tokenId) internal returns (uint256) {
        poolTokens.asset[0].approve(IProtocolFacet(address(this)).npm(), poolTokens.amount[0]);
        poolTokens.asset[1].approve(IProtocolFacet(address(this)).npm(), poolTokens.amount[1]);

        if (tokenId == 0) {
            tokenId = IMasterFacet(address(this)).mintPosition(
                paramsData.pool,
                paramsData.tickRange[0],
                paramsData.tickRange[1],
                poolTokens.amount[0],
                poolTokens.amount[1],
                msg.sender
            );
            emit TokenId(tokenId);
        } else {
            IMasterFacet(address(this)).increaseLiquidity(tokenId, poolTokens.amount[0], poolTokens.amount[1]);
        }
        return tokenId;
    }

    function adjustSwap(
        ZapInParams memory paramsData,
        PoolTokens memory poolTokens,
        uint256 tokenId
    ) internal {
        if (paramsData.isSimulation) {
            (paramsData.adjustSwapAmount, paramsData.adjustSwapSide) = simulateSwap(paramsData, poolTokens);
        }
        if (paramsData.adjustSwapAmount > 0) {
            IMasterFacet(address(this)).swap(paramsData.pool, paramsData.adjustSwapAmount, 0, paramsData.adjustSwapSide);
        }
        paramsData.amountsOut[0] = poolTokens.asset[0].balanceOf(address(this));
        paramsData.amountsOut[1] = poolTokens.asset[1].balanceOf(address(this));
        poolTokens.asset[0].approve(IProtocolFacet(address(this)).npm(), paramsData.amountsOut[0]);
        poolTokens.asset[1].approve(IProtocolFacet(address(this)).npm(), paramsData.amountsOut[1]);

        IMasterFacet(address(this)).increaseLiquidity(tokenId, paramsData.amountsOut[0], paramsData.amountsOut[1]);
    }

    struct BinSearchParams {
        uint256 left;
        uint256 right;
        uint256 mid;
    }

    function simulateSwap(
        ZapInParams memory paramsData, 
        PoolTokens memory poolTokens
    ) internal returns (uint256 amountToSwap, bool zeroForOne) {
        zeroForOne = poolTokens.asset[0].balanceOf(address(this)) > poolTokens.asset[1].balanceOf(address(this));
        BinSearchParams memory binSearchParams;
        binSearchParams.right = poolTokens.asset[zeroForOne ? 0 : 1].balanceOf(address(this));
        for (uint256 i = 0; i < zapStorage().binSearchIterations; i++) {
            binSearchParams.mid = (binSearchParams.left + binSearchParams.right) / 2;

            try IMasterFacet(address(this)).simulateSwap(
                paramsData.pool, 
                binSearchParams.mid, 
                0, 
                zeroForOne, 
                paramsData.tickRange
            ) 
            {} catch (bytes memory _data) {
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
}