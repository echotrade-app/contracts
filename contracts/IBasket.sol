
// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

enum Status {pending, active, closed }

interface IBasket {
    // baseToken: returns the basket BaseToken
    function baseToken() external view returns(address);

    // admin: returns the administrator address of the basket. the admin address must be equal to ECTA contract address.
    function admin() external view returns(address);

    // trader: returns the trader address of the basket.
    function trader() external view returns(address);
    
    // represent the status of the basket
    // enum Status {pending, active, closed }
    function status() external view returns(Status);
    
    // adminShareProfit: fetch the admin(ECTA) share of the basket. the found must be transfered to the admin account.
    function adminShareProfit() external returns(uint256);

    // setAssitatnt: the Maintainer of ECTA can set diffrent assitants for each basket, so the basket will be manage by assistance only.
    function setAssitatnt(address assitant) external returns(uint256);
}
