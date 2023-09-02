
// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

enum Status {pending, active, closed }

interface IBasket {
    function baseToken() external view returns(address);

    function admin() external view returns(address);
    function trader() external view returns(address);
    
    function status() external view returns(Status);
    
    function adminShareProfit() external returns(uint256);

    
}
