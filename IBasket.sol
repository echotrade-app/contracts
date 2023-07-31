// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

interface IBasket {

  function baseLiquidity() external view returns (uint256 amount);
  function queuedLiquidity() external view returns (uint256 amount);
  

  function withdrawAble() external view returns (uint256 amount);
  function withdrawAbleProfit() external view returns (uint256 amount);
  
  
  function deposit(uint256 amount, bytes32 sig) external returns(bool success);

  function withdrawRequest(uint256 amount) external returns(bool success);
  function withdraw(uint256 amount) external returns(bool success);
  function withdrawProfit(uint amount) external returns(bool success);

  // Only Admin
  function profitShare(uint256 amount) external returns(bool success);

  // burn in the case of lossing the assets
  function burn(uint256 amount) external returns(bool success);

}