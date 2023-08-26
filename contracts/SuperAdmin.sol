// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract SuperAdmin {
  address payable public _superAdmin;

  modifier _onlySuperAdmin() {
      require(msg.sender == _superAdmin,"you are not the super admin");
      _;
  }
  
  constructor(uint256 hi) {
    _superAdmin = payable(msg.sender);
  }
  
  /**
    * @dev surrogate the superadmin account to new account.
    * 
   */
  function surrogate(address payable _account) public _onlySuperAdmin() returns (bool) {
    _superAdmin = _account;
    return true;
  }
}