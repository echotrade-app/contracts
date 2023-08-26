// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./SafeMath.sol";
import "hardhat/console.sol";

error FundsIsNotReleasedYet(uint256 wait);

contract Vesting {
  uint256 private _startReleaseAt;
  uint256 private _releaseDuration;
  uint256 private _endReleaseAt;

  modifier _isReleased(uint256 base,uint256 remiding) {
    console.log("blockTimestamp",block.timestamp);
    console.log("\tbase:",base);
    console.log("\trem:",remiding);
    if (base != 0 || block.timestamp >= _endReleaseAt) {
      uint256 T = _startReleaseAt + SafeMath.div(SafeMath.mul(base-remiding, _releaseDuration), base);
    console.log("\tT:",T);
      if (block.timestamp < T) {
        revert FundsIsNotReleasedYet(T);
      }
    }
    _;
  }

  constructor (uint256 __startReleaseAt, uint256 __releaseDuration) {
    _startReleaseAt = __startReleaseAt;
    _releaseDuration = __releaseDuration;
    _endReleaseAt = __startReleaseAt+__releaseDuration;
    
    console.log("start",_startReleaseAt);
    console.log("end:",_endReleaseAt);
  }

  function whenWillRelease(uint256 base, uint256 remiding) public view returns (uint256 wait) {
    return _endReleaseAt - SafeMath.div(SafeMath.mul(base-remiding, _releaseDuration), base);
  }
  
}