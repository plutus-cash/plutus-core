// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import "./interfaces/core/IProportionFacet.sol";
import "./interfaces/core/IOReadFacet.sol";

contract MyOAppRead is IOReadFacet, OAppRead, OAppOptionsType3 {

    uint8 internal constant MAP_ONLY = 0;
    uint8 internal constant REDUCE_ONLY = 1;
    uint8 internal constant MAP_AND_REDUCE = 2;
    uint8 internal constant NONE = 3;

    uint8 private constant READ_MSG_TYPE = 1;

    mapping(uint32 => ChainConfig) public chainConfigs;
    uint32 public READ_CHANNEL;

    uint256 public amount1;
    uint256 public amount2;


    constructor(
        address _endpoint,
        uint32 _readChannel
    ) OAppRead(_endpoint, msg.sender) Ownable(msg.sender) {
        READ_CHANNEL = _readChannel;
        _setPeer(READ_CHANNEL, AddressCast.toBytes32(address(this)));
    }

    function addChain(uint32 eid, ChainConfig memory chainConfig) external {
        chainConfigs[eid] = chainConfig;
    }

    function setReadChannel(uint32 _channelId, bool _active) public override {
        _setPeer(_channelId, _active ? AddressCast.toBytes32(address(this)) : bytes32(0));
        READ_CHANNEL = _channelId;
    }

    bytes public data = abi.encode("Nothing received yet.");

    function getProportion(uint32 _eid, address _pool, int24[] memory tickRange, bytes calldata _extraOptions) public payable returns (MessagingReceipt memory receipt) {

        bytes memory cmd = getCmdData(_eid, _pool, tickRange);
        return
            _lzSend(
                READ_CHANNEL,
                cmd,
                combineOptions(READ_CHANNEL, READ_MSG_TYPE, _extraOptions),
                MessagingFee(msg.value, 0),
                payable(msg.sender)
            );
    }

    function getCmdData(uint32 targetEid, address _pool, int24[] memory tickRange) public view returns (bytes memory) {
        EVMCallRequestV1[] memory readRequests = new EVMCallRequestV1[](1);
        
        ChainConfig memory config = chainConfigs[targetEid];
        
        bytes memory callData = abi.encodeWithSelector(IProportionFacet.getProportion.selector, _pool, tickRange, targetEid);
        readRequests[0] = EVMCallRequestV1({
            appRequestLabel: uint16(1),
            targetEid: targetEid,
            isBlockNum: false,
            blockNumOrTimestamp: uint64(block.timestamp),
            confirmations: config.confirmations,
            to: config.zapAddress,
            callData: callData
        });
        

        EVMCallComputeV1 memory computeSettings = EVMCallComputeV1({
            computeSetting: NONE, // lzMap() and lzReduce()
            targetEid: ILayerZeroEndpointV2(endpoint).eid(),
            isBlockNum: false,
            blockNumOrTimestamp: uint64(block.timestamp),
            confirmations: 15,
            to: address(this)
        });

        return ReadCodecV1.encode(0, readRequests, computeSettings);
    }

    // hardcode NOT to pay in ZRO
    function quoteCmdData(uint32 targetEid, address _pool, int24[] memory tickRange, bytes calldata _extraOptions) external view returns (MessagingFee memory fee) {
        bytes memory cmd = getCmdData(targetEid, _pool, tickRange);
        return _quote(READ_CHANNEL, cmd, combineOptions(READ_CHANNEL, READ_MSG_TYPE, _extraOptions), false);
    }


    function _lzReceive(
        Origin calldata,
        bytes32 /*_guid*/,
        bytes calldata _message,
        address,
        bytes calldata
    ) internal override {
        require(_message.length == 32, "Invalid message length");
        (amount1, amount2) = abi.decode(_message, (uint256, uint256));
        
    }
}