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

    constructor(
        address _endpoint
    ) OAppRead(_endpoint, msg.sender) {
        
    }

    function addChain(uint32 eid, ChainConfig memory chainConfig) external onlyAdmin {
        chainConfigs[eid] = chainConfig;
    }

    string public identifier;
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


    /**
     * @notice Send a read command in loopback through channelId
     * @param _channelId Read Channel ID to be used for the message.
     * @param _appLabel The application label to use for the message.
     * @param _requests An array of `EvmReadRequest` structs containing the read requests to be made.
     * @param _computeRequest A `EvmComputeRequest` struct containing the compute request to be made.
     * @param _options Message execution options (e.g., for sending gas to destination).
     * @dev Encodes the message as bytes and sends it using the `_lzSend` internal function.
     * @return receipt A `MessagingReceipt` struct containing details of the message sent.
     */
    function send(
        uint32 _channelId,
        uint16 _appLabel,
        EvmReadRequest[] memory _requests,
        EvmComputeRequest memory _computeRequest,
        bytes calldata _options
    ) external payable returns (MessagingReceipt memory receipt) {
        bytes memory cmd = buildCmd(_appLabel, _requests, _computeRequest);
        receipt = _lzSend(_channelId, cmd, _options, MessagingFee(msg.value, 0), payable(msg.sender));
    }

    /**
     * @notice Quotes the gas needed to pay for the full read command in native gas or ZRO token.
     * @param _channelId Read Channel ID to be used for the message.
     * @param _appLabel The application label to use for the message.
     * @param _requests An array of `EvmReadRequest` structs containing the read requests to be made.
     * @param _computeRequest A `EvmComputeRequest` struct containing the compute request to be made.
     * @param _options Message execution options (e.g., for sending gas to destination).
     * @param _payInLzToken Whether to return fee in ZRO token.
     * @return fee A `MessagingFee` struct containing the calculated gas fee in either the native token or ZRO token.
     */
    function quote(
        uint32 _channelId,
        uint16 _appLabel,
        EvmReadRequest[] memory _requests,
        EvmComputeRequest memory _computeRequest,
        bytes calldata _options,
        bool _payInLzToken
    ) public view returns (MessagingFee memory fee) {
        bytes memory cmd = buildCmd(_appLabel, _requests, _computeRequest);
        fee = _quote(_channelId, cmd, _options, _payInLzToken);
    }

    /**
     * @notice Builds the command to be sent
     * @param appLabel The application label to use for the message.
     * @param _readRequests An array of `EvmReadRequest` structs containing the read requests to be made.
     * @param _computeRequest A `EvmComputeRequest` struct containing the compute request to be made.
     * @return cmd The encoded command to be sent to to the channel.
     */
    function buildCmd(
        uint16 appLabel,
        EvmReadRequest[] memory _readRequests,
        EvmComputeRequest memory _computeRequest
    ) public pure returns (bytes memory) {
        require(_readRequests.length > 0, "LzReadCounter: empty requests");
        // build read requests
        EVMCallRequestV1[] memory readRequests = new EVMCallRequestV1[](_readRequests.length);

        bytes memory callData = abi.encodeWithSelector(bytes4, arg);
        
        for (uint256 i = 0; i < _readRequests.length; i++) {
            EvmReadRequest memory req = _readRequests[i];
            readRequests[i] = EVMCallRequestV1({
                appRequestLabel: req.appRequestLabel,
                targetEid: req.targetEid,
                isBlockNum: req.isBlockNum,
                blockNumOrTimestamp: req.blockNumOrTimestamp,
                confirmations: req.confirmations,
                to: req.to,
                callData: callData
            });
        }

        require(_computeRequest.computeSetting <= COMPUTE_SETTING_NONE, "LzReadCounter: invalid compute type");
        EVMCallComputeV1 memory evmCompute = EVMCallComputeV1({
            computeSetting: _computeRequest.computeSetting,
            targetEid: _computeRequest.computeSetting == COMPUTE_SETTING_NONE ? 0 : _computeRequest.targetEid,
            isBlockNum: _computeRequest.isBlockNum,
            blockNumOrTimestamp: _computeRequest.blockNumOrTimestamp,
            confirmations: _computeRequest.confirmations,
            to: _computeRequest.to
        });
        bytes memory cmd = ReadCodecV1.encode(appLabel, readRequests, evmCompute);

        return cmd;
    }

    function _lzReceive(
        Origin calldata,
        bytes32 /*_guid*/,
        bytes calldata _message,
        address,
        bytes calldata
    ) internal override {
        require(_message.length == 32, "Invalid message length");
        uint256 averagePrice = abi.decode(_message, (uint256));
        emit AggregatedPrice(averagePrice);
    }

    function lzMap(bytes calldata, bytes calldata _response) external pure returns (bytes memory) {
        require(_response.length >= 32, "Invalid response length"); // quoteExactInputSingle returns multiple values

        // Decode the response to extract amountOut
        (, , , , ) = abi.decode(_response, (address, address, uint160, int24, int24));
        return abi.encode(amountOut);
    }

    function lzReduce(bytes calldata _cmd, bytes[] calldata _responses) external pure returns (bytes memory) {
        uint16 appLabel = ReadCodecV1.decodeCmdAppLabel(_cmd);
        bytes memory concatenatedResponses;

        for (uint256 i = 0; i < _responses.length; i++) {
            concatenatedResponses = abi.encodePacked(concatenatedResponses, _responses[i]);
        }
        return abi.encodePacked(concatenatedResponses, "_reduced_appLabel:", appLabel);
    }
}