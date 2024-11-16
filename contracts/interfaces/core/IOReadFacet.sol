//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IOReadFacet {

    uint8 internal constant MAP_ONLY = 0;
    uint8 internal constant REDUCE_ONLY = 1;
    uint8 internal constant MAP_AND_REDUCE = 2;
    uint8 internal constant NONE = 3;

    uint8 private constant READ_MSG_TYPE = 1;

    struct EvmReadRequest {
        uint16 appRequestLabel;
        uint32 targetEid;
        bool isBlockNum;
        uint64 blockNumOrTimestamp;
        uint16 confirmations;
        address to;
    }

    struct EvmComputeRequest {
        uint8 computeSetting;
        uint32 targetEid;
        bool isBlockNum;
        uint64 blockNumOrTimestamp;
        uint16 confirmations;
        address to;
    }

    struct ChainConfig {
        uint16 confirmations; // Number of confirmations required
        address zapAddress; // Address of the zap contract
        // address poolAddress; // Address of the pool contract
    }

    function getPoolData(uint32 _eid, address _pool) external;

    
}