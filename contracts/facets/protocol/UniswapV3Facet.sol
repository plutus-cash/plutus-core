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
        require(args.npm != 0, 'eid is empty');
        protocolStorage().npm = args.npm;
        protocolStorage().eid = args.eid;
    }

    function npm() public view returns (address) {
        return protocolStorage().npm;
    }

    function eid() public view returns (uint32) {
        return protocolStorage().eid;
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

    function getPoolDecimals(address pair, uint32 eid) external onlyDiamond view returns (uint256, uint256) {
        if (eid == eid()) {
            IUniswapV3Pool pool = IUniswapV3Pool(pair);
            return (IERC20Metadata(pool.token0()).decimals(), IERC20Metadata(pool.token1()).decimals());
        } else {
            IMasterFacet(address(this)).
        }
    }

    function getPoolSqrtRatioX96(address pair, uint32 eid) external onlyDiamond view returns (uint160 sqrtRatioX96) {
        (sqrtRatioX96,,,,,,) = IUniswapV3Pool(pair).slot0();
    }

    function getPoolTickSpacing(address pair, uint32 eid) external onlyDiamond view returns (int24) {
        return IUniswapV3Pool(pair).tickSpacing();
    }

    function getPoolTick(address pair, uint32 eid) external onlyDiamond view returns (int24 tick) {
        (, tick,,,,,) = IUniswapV3Pool(pair).slot0();
    }

    function getPoolTokens(address pair, uint32 eid) public view returns (address, address) {
        IUniswapV3Pool pool = IUniswapV3Pool(pair);
        return (pool.token0(), pool.token1());
    }
}