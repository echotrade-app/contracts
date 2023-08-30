// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./SafeMath.sol";
import "hardhat/console.sol";

error FundsIsNotReleasedYet(uint256 wait);

contract Vesting {
  
  struct _Vesting {
    uint256 base;
    uint256 _startReleaseAt;
    uint256 _releaseDuration;
    uint256 _endReleaseAt;
  }

  mapping (address => _Vesting) private vestings ;

  modifier _isReleased(address account ,uint256 balance) {
    if (vestings[account].base != 0 && block.timestamp < vestings[account]._endReleaseAt) {
      uint256 T = vestings[account]._startReleaseAt + SafeMath.div(SafeMath.mul(vestings[account].base-balance, vestings[account]._releaseDuration), vestings[account].base);
      if (block.timestamp < T) {
        revert FundsIsNotReleasedYet(T);
      }
    }
    _;
  }

  function whenWillRelease(address account, uint256 balance) public view returns (uint256 wait) {
    return vestings[account]._startReleaseAt + SafeMath.div(SafeMath.mul(vestings[account].base-balance, vestings[account]._releaseDuration), vestings[account].base);
  }

  function vesting(address _account, uint256 _base, uint256 _startReleaseAt, uint256 _releaseDuration) internal {
    vestings[_account] = _Vesting(_base, _startReleaseAt, _releaseDuration,_startReleaseAt+_releaseDuration);
  }
  
}