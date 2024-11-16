// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;
uint256 constant MAX_UINT_VALUE = type(uint256).max;
uint256 constant PRECISION_DEC = 18; // constant for more precise returns
uint256 constant BASE_DIV = 1000000; // 10

// layer0 constants

uint32 constant ETH_EID = 30101; // LayerZero EID for Ethereum Mainnet
// address constant ETH_ZAP = 0x0; // add actual address

uint32 constant BASE_EID = 30184; // LayerZero EID for Base Mainnet
// address constant BASE_ZAP = 0x0; // add actual address

uint32 constant OPT_EID = 30111; // LayerZero EID for Optimism Mainnet
// address constant OPT_ZAP = 0x0; // add actual address
