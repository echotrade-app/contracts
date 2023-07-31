// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./ITRC20.sol";
import "./lib/SafeMath.sol";

contract Token is ITRC20 {
  using SafeMath for uint256;

  string private _name;
  string private _symbol;
  uint8 private _decimals;

  mapping(address => uint256) _balaces; 

  

}