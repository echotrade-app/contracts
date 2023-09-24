// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./SuperAdmin.sol";

contract OwnableAccount is SuperAdmin {

    bytes4 private constant TRANSFER_SELECTOR = bytes4(keccak256("transfer(address,uint256)"));

    function transfer(address _contract,address _recipient, uint256 _amount) public _onlySuperAdmin() returns (bool) {
        if (_contract == address(0) ) {
            (bool success, ) = _recipient.call{value: _amount}("");
            require(success, "tx failed");
        }else {
            (bool success, ) = _contract.call(abi.encodeWithSelector(TRANSFER_SELECTOR, _recipient, _amount));
            require(success, "tx failed");
        }
      return true;
    }

    receive() external payable {}

    fallback() external payable {}

}