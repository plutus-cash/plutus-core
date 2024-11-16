// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import { MessagingFee, Origin } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { OAppRead } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppRead.sol";
import { MessagingReceipt } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import { IOAppMapper } from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppMapper.sol";
import { IOAppReducer } from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppReducer.sol";
import { ReadCodecV1, EVMCallComputeV1, EVMCallRequestV1 } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/ReadCodecV1.sol";

import "../../interfaces/IMasterFacet.sol";

contract OReadFacet is IOReadFacet, OAppRead, IOAppMapper, IOAppReducer {

    mapping(uint32 => ChainConfig) public chainConfigs;
    uint32 public READ_CHANNEL;


    constructor(
        address _endpoint,
        uint32 _readChannel
    ) OAppRead(_endpoint, msg.sender) {
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

    function getPoolData(uint32 _eid, address _pool) onlyDiamond {
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
        EVMCallRequestV1 memory readRequest;
        
        ChainConfig memory config = chainConfigs[targetEid];
        
        address memory params = _pool;

        bytes memory callData = abi.encodeWithSelector(IMasterFacet.getPoolData.selector, params);
        readRequest = EVMCallRequestV1({
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

        return ReadCodecV1.encode(0, readRequest, computeSettings);
    }

    // hardcode NOT to pay in ZRO
    function quoteCmdData(bytes calldata _extraOptions) external view returns (MessagingFee memory fee) {
        bytes memory cmd = getCmd();
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