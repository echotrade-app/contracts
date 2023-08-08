// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./SafeMath.sol";
import "./iterable-mapping.sol";

contract Basket {
  using SafeMath for uint256;

  enum status {pending, active, closed }

  address public _owner;
  status private _status;
  uint256 public _ownerFund;
  uint64 private _iteration;
  address public _baseToken;
  address payable public _admin;
  
  uint256 private _lockedFunds;

  uint256 public _totalLiquidity;
  uint256 public _availableLiquidity;


  IterableMapping.Map private _funds;
  IterableMapping.Map private _queuedFunds;

  mapping (address => uint256) _profits;

  constructor(address _owner,address _admin, address _baseToken, uint256 _ownerFund) {
    _owner = _owner;
    _admin = _admin;
    _baseToken = _baseToken;
    _ownerFund = _ownerFund;
  }

  // returns total liquidity of the contract
  function totalLiquidity() public view returns (uint256) {}

  // returns the amount of available Liquidity of the contract
  function availbaleLiquidity() public view returns (uint256) {}
 
  // returns the sum of the main funds.
  function baseLiquidity() external view returns (uint256) {}

  // returns the sum of the queued funds.
  function queuedLiquidity() external view returns (uint256) {}

  // close the basket
  function close() public returns (bool) {}

  // the owner should approve _owner_fund to this contract, to be accivated, one the basket closes, this ammount will return back to the owner. 
  function active() public returns (bool) {}

  // the owner or admin can call this function to specify the amount of profit
  // todo add hash of Positions to this function
  function profitShare(uint256 _amount) public _onlyOwner() returns (bool) {}

  // the owner or admin can call this function to specify the amount of loss
  // todo add hash of Positions to this function
  function burn(uint256 _amount) public _onlyOwner() returns (bool) {}

  
  // ─── Modifiers ───────────────────────────────────────────────────────

  modifier _isActive() {
    require(_status == status.active, "Basket is not active yet");
    _;
  }
  
  modifier _onlyOwner() {
    require(msg.sender == _owner || msg.sender == _admin, "Only owner is allowed to call this method");
    _;
  }

  modifier _onlyAdmin() {
    require(msg.sender == _admin, "Only admin is allowed to call this method");
    _;
  }


}