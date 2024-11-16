//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "./core/IMathFacet.sol";
import "./core/IOReadFacet.sol";
import "./core/IProportionFacet.sol";
import "./core/IZapFacet.sol";
import "./IProtocolFacet.sol";
import "./Modifiers.sol";

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IMasterFacet is IMathFacet, IOReadFacet, IProtocolFacet, IProportionFacet, IZapFacet {}
