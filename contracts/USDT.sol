// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./ITRC20.sol";
import "./Basket.sol";
import "./SafeMath.sol";
import "./IterableMapping.sol";
import "./SuperAdmin.sol";
import "./Vesting.sol";
import "./Token.sol";

contract USDT is Token {
   constructor(
    string memory name,
    string memory symbol,
    uint8 decimals,
    uint256 startReleaseAt,
    uint releaseDuration
    ) Token(name,symbol,decimals,startReleaseAt,releaseDuration) {
      _mint(msg.sender, 1000*10**decimals, true);
    }
}