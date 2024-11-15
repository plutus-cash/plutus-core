//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "../../connectors/UniswapV3.sol";
import "../../interfaces/IMasterFacet.sol";
import "../../interfaces/Modifiers.sol";
import "../../interfaces/IProtocolFacet.sol";

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
        protocolStorage().npm = args.npm;
    }

    function npm() public view returns (address) {
        return protocolStorage().npm;
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


}