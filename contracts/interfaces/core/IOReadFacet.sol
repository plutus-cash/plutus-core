//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IOReadFacet {
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