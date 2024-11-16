// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import { ILayerZeroEndpointV2, MessagingFee, MessagingReceipt, Origin } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { AddressCast } from "@layerzerolabs/lz-evm-protocol-v2/contracts/libs/AddressCast.sol";

import { ReadCodecV1, EVMCallComputeV1, EVMCallRequestV1 } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/ReadCodecV1.sol";
import { OAppOptionsType3 } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import { OAppRead } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppRead.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { Modifiers } from "../../interfaces/Modifiers.sol";
import "../../interfaces/IMasterFacet.sol";

contract OReadFacet is IOReadFacet, OAppRead, OAppOptionsType3, Modifiers {

    uint8 internal constant MAP_ONLY = 0;
    uint8 internal constant REDUCE_ONLY = 1;
    uint8 internal constant MAP_AND_REDUCE = 2;
    uint8 internal constant NONE = 3;

    uint8 internal constant READ_MSG_TYPE = 1;

    mapping(uint32 => ChainConfig) public chainConfigs;
    uint32 public READ_CHANNEL;


    constructor(
        address _endpoint,
        uint32 _readChannel
    ) OAppRead(_endpoint, msg.sender) Ownable(msg.sender) {
        READ_CHANNEL = _readChannel;
        _setPeer(READ_CHANNEL, AddressCast.toBytes32(address(this)));
    }

    function addChain(uint32 eid, ChainConfig memory chainConfig) external onlyAdmin {
        chainConfigs[eid] = chainConfig;
    }

    function setReadChannel(uint32 _channelId, bool _active) public override onlyAdmin {
        _setPeer(_channelId, _active ? AddressCast.toBytes32(address(this)) : bytes32(0));
        READ_CHANNEL = _channelId;
    }

    bytes public data = abi.encode("Nothing received yet.");

    function getPoolData(uint32 _eid, address _pool) public {
        bytes memory options = "0x0";
        getPoolData(_eid, _pool, options);
    }

    function getPoolData(uint32 _eid, address _pool, bytes calldata _extraOptions) public payable returns (MessagingReceipt memory receipt) {

        bytes memory cmd = getCmdData(_eid, _pool);
        return
            _lzSend(
                READ_CHANNEL,
                cmd,
                combineOptions(READ_CHANNEL, READ_MSG_TYPE, _extraOptions),
                MessagingFee(msg.value, 0),
                payable(msg.sender)
            );
    }

    function getCmdData(uint32 targetEid, address _pool) public view returns (bytes memory) {
        EVMCallRequestV1[] memory readRequests = new EVMCallRequestV1[](1);
        
        ChainConfig memory config = chainConfigs[targetEid];
        
        address params = _pool;

        bytes memory callData = abi.encodeWithSelector(IMathFacet.getCurrentPrice.selector, params);
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
    function quoteCmdData(uint32 targetEid, address _pool, bytes calldata _extraOptions) external view returns (MessagingFee memory fee) {
        bytes memory cmd = getCmdData(targetEid, _pool);
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
        // uint256 averagePrice = abi.decode(_message, (uint256));
        
    }
}