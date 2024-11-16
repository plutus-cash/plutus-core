// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import { Modifiers } from "../../interfaces/Modifiers.sol";
import "../../interfaces/IMasterFacet.sol";
import "../../interfaces/core/IProportionFacet.sol";

contract OReadFacet is IOReadFacet, Modifiers {

    bytes32 internal constant LZ_STORAGE_POSITION = keccak256("lz.storage");

    function lzStorage() internal pure returns (LzStorage storage ds) {
        bytes32 position = LZ_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    function setLzStorage(LzStorage memory args) external onlyAdmin {
        lzStorage().amount0 = 0;
        lzStorage().amount1 = 0;
        lzStorage().oread = args.oread;
    }

    function getProportionLZ(uint32 _eid, address _pool, int24[] memory tickRange, bytes calldata _extraOptions) external payable returns (MessagingReceipt memory receipt) {
        return IOReadFacet(lzStorage().oread).getProportionLZ(_eid, _pool, tickRange, _extraOptions);
    }

    
    function getResult() public view returns(uint256, uint256) {
        return (lzStorage().amount0, lzStorage().amount1);
    }
}