//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "../../connectors/UniswapV3.sol";
import "../../interfaces/IMasterFacet.sol";
import "../../interfaces/Modifiers.sol";

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract UniswapV3Facet is IProtocolFacet, Modifiers {

    bytes32 internal constant PROTOCOL_STORAGE_POSITION = keccak256("protocol.storage");

    struct SwapCallbackData {
        address tokenA;
        address tokenB;
        uint24 fee;
    }
    
    function protocolStorage() internal pure returns (ProtocolStorage storage ds) {
        bytes32 position = PROTOCOL_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    function setProtocolParams(ProtocolStorage memory args) external onlyAdmin {
        require(args.npm != address(0), 'npm is empty');
        require(args.eid != 0, 'eid is empty');
        protocolStorage().npm = args.npm;
        protocolStorage().eid = args.eid;
    }

    function npm() public view returns (address) {
        return protocolStorage().npm;
    }

    function eid() public view returns (uint32) {
        return protocolStorage().eid;
    }

    function mintPosition(
        address pair,
        int24 tickRange0,
        int24 tickRange1,
        uint256 amountOut0,
        uint256 amountOut1,
        address recipient
    ) external onlyDiamond returns (uint256 tokenId) {
        IUniswapV3Pool pool = IUniswapV3Pool(pair);
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: pool.token0(),
            token1: pool.token1(),
            fee: pool.fee(),
            tickLower: tickRange0,
            tickUpper: tickRange1,
            amount0Desired: amountOut0,
            amount1Desired: amountOut1,
            amount0Min: 0,
            amount1Min: 0,
            recipient: recipient,
            deadline: block.timestamp
        });
        (tokenId,,,) = _getNpmInstance().mint(params);
    }

    function closePosition(uint256 tokenId, address recipient, address feeRecipient) onlyDiamond external {
        INonfungiblePositionManager.DecreaseLiquidityParams memory params = INonfungiblePositionManager.DecreaseLiquidityParams({
            tokenId: tokenId,
            liquidity: getLiquidity(tokenId),
            amount0Min: 0,
            amount1Min: 0,
            deadline: block.timestamp
        });
        (uint256 fee0, uint256 fee1) = _collectRewards(tokenId, feeRecipient);
        emit CollectRewards(fee0, fee1);
        if (params.liquidity > 0) {
            _getNpmInstance().decreaseLiquidity(params);
        }
        _collectRewards(tokenId, recipient);
        _getNpmInstance().burn(tokenId);
    }

    function increaseLiquidity(
        uint256 tokenId,
        uint256 amount0,
        uint256 amount1
    ) external onlyDiamond returns (uint128 liquidity) {
        INonfungiblePositionManager.IncreaseLiquidityParams memory params = INonfungiblePositionManager.IncreaseLiquidityParams({
            tokenId: tokenId,
            amount0Desired: amount0,
            amount1Desired: amount1,
            amount0Min: 0,
            amount1Min: 0,
            deadline: block.timestamp
        });
        (liquidity,,) = _getNpmInstance().increaseLiquidity(params);
    }

    function swap(
        address pair,
        uint256 amountIn,
        uint160 sqrtPriceLimitX96,
        bool zeroForOne
    ) public onlyDiamond {
        IUniswapV3Pool pool = IUniswapV3Pool(pair);
        SwapCallbackData memory data = SwapCallbackData({
            tokenA: pool.token0(),
            tokenB: pool.token1(),
            fee: pool.fee()
        });
 
        pool.swap(
            address(this), 
            zeroForOne, 
            int256(amountIn), 
            sqrtPriceLimitX96 == 0
                ? (zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1)
                : sqrtPriceLimitX96, 
            abi.encode(data)
        );
    }
 
    function simulateSwap(
        address pair,
        uint256 amountIn,
        uint160 sqrtPriceLimitX96,
        bool zeroForOne,
        int24[] memory tickRange
    ) external onlyDiamond {
        (address token0Address, address token1Address) = getPoolTokens(pair);
        swap(pair, amountIn, sqrtPriceLimitX96, zeroForOne);
 
        uint256[] memory ratio = new uint256[](2);
        (ratio[0], ratio[1]) = IMasterFacet(address(this)).getProportion(pair, tickRange);
        revert SwapError(
            IERC20(token0Address).balanceOf(address(this)),
            IERC20(token1Address).balanceOf(address(this)),
            ratio[0],
            ratio[1]
        );
    }
 
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata _data
    ) external {
        SwapCallbackData memory data = abi.decode(_data, (SwapCallbackData));
        address factory = _getNpmInstance().factory();
        CallbackValidation.verifyCallback(factory, data.tokenA, data.tokenB, data.fee);
 
        (bool isExactInput, uint256 amountToPay) =
            amount0Delta > 0
                ? (data.tokenA < data.tokenB, uint256(amount0Delta))
                : (data.tokenB < data.tokenA, uint256(amount1Delta));
 
        if (isExactInput) {
            IERC20(data.tokenA).transfer(msg.sender, amountToPay);
        } else {
            IERC20(data.tokenB).transfer(msg.sender, amountToPay);
        }
    }

    function _collectRewards(uint256 tokenId, address recipient) internal returns (uint256, uint256) {
        INonfungiblePositionManager.CollectParams memory collectParams = INonfungiblePositionManager.CollectParams({
            tokenId: tokenId,
            recipient: recipient,
            amount0Max: type(uint128).max,
            amount1Max: type(uint128).max
        });
        return _getNpmInstance().collect(collectParams);
    }

    function getPoolData(address pair) external view returns (PoolData memory poolData) {
        IUniswapV3Pool pool = IUniswapV3Pool(pair);
        (uint160 _sqrtRatioX96, int24 tick,,,,,) = pool.slot0();
        int24 ts = pool.tickSpacing();

        poolData = PoolData({
            token0: pool.token0(),
            token1: pool.token1(),
            sqrtPriceX96: _sqrtRatioX96,
            currentTick: tick,
            tickSpacing: ts
        });
    }

    function getPoolDecimals(address pair) external onlyDiamond view returns (uint256, uint256) {
        IUniswapV3Pool pool = IUniswapV3Pool(pair);
        return (IERC20Metadata(pool.token0()).decimals(), IERC20Metadata(pool.token1()).decimals());
    }

    function getPoolSqrtRatioX96(address pair) external onlyDiamond view returns (uint160 sqrtRatioX96) {
        (sqrtRatioX96,,,,,,) = IUniswapV3Pool(pair).slot0();
    }

    function getPoolTickSpacing(address pair) external onlyDiamond view returns (int24) {
        return IUniswapV3Pool(pair).tickSpacing();
    }

    function getPoolTick(address pair) external onlyDiamond view returns (int24 tick) {
        (, tick,,,,,) = IUniswapV3Pool(pair).slot0();
    }

    function getPoolTokens(address pair) public view returns (address, address) {
        IUniswapV3Pool pool = IUniswapV3Pool(pair);
        return (pool.token0(), pool.token1());
    }

    function getPositionAmounts(uint256 tokenId) public view returns (uint256 amount0, uint256 amount1) {
        address poolId = getPool(tokenId);
        (int24 tickLower, int24 tickUpper) = getPositionTicks(tokenId);
        (uint160 sqrtRatioX96,,,,,,) = IUniswapV3Pool(poolId).slot0();
        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtRatioX96,
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            getLiquidity(tokenId)
        );
    }

    function getPositionTokens(uint256 tokenId) public view returns (address token0, address token1) {
        (,, token0, token1,,,,,,,,) = _getNpmInstance().positions(tokenId);
    }

    function getPool(uint256 tokenId) public view returns (address poolId) {
        (address token0, address token1) = getPositionTokens(tokenId);
        (,,,, uint24 fee,,,,,,,) = _getNpmInstance().positions(tokenId);
        IUniswapV3Factory factory = IUniswapV3Factory(_getNpmInstance().factory());
        poolId = factory.getPool(token0, token1, fee);
    }

    function getPositionTicks(uint256 tokenId) public view returns (int24 tickLower, int24 tickUpper) {
        (,,,,, tickLower, tickUpper,,,,,) = _getNpmInstance().positions(tokenId);
    }

    function getLiquidity(uint256 tokenId) internal view returns (uint128 liquidity) {
        (,,,,,,, liquidity,,,,) = _getNpmInstance().positions(tokenId);
    }

    function _getTickSpacing(uint256 tokenId) internal view returns (int24 tickSpacing) {
        IUniswapV3Pool pool = IUniswapV3Pool(getPool(tokenId));
        tickSpacing = pool.tickSpacing();
    }

    function _getNpmInstance() internal view returns (INonfungiblePositionManager) {
        return INonfungiblePositionManager(protocolStorage().npm);
    }
}
