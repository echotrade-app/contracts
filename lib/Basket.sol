// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./SafeMath.sol";
import "./iterable-mapping.sol";

contract Basket {
  using SafeMath for uint256;
  using IterableMapping for IterableMapping.Map;
  
  enum status {pending, active, closed }

  address public _owner;
  status private _status;
  uint256 public _ownerFund;
  uint64 private _iteration;
  uint64 public _maximumFund;
  address public _baseToken;
  address public _admin;
  

  uint256 public _totalLiquidity;
  uint256 public _availableLiquidity;
  uint256 public _totalLockedFunds;
  uint256 private _totalWithdrawRequests;
  uint256 private _totalQueuedFunds;

  IterableMapping.Map private _withdrawRequests;

  IterableMapping.Map private _lockedFunds;
  IterableMapping.Map private _queuedFunds;
  mapping (address => uint256) public _releasedFunds;
  mapping (address => uint256) public _profits;

  bytes4 private _transferFromSelector;
  bytes4 private _transferSelector;
  bytes4 private _balanceOf;

  
  // totalLiquidity = availbaleLiquidity + lockedFunds; 
  // totalLiquidity = queuedFunds + _releasedFunds + _profits + _lockedFunds
  // withdrawableFunds = queuedFunds + _releasedFunds
  // availableLiquidity >= _releasedFunds + _profits + _queuedFunds
  //
  // --QueuedFunds-->|---->>>----|--ReleasedFunds-->
  //                 |LockedFunds|--Profits-->
  //                 |----<<<----|

  constructor(address owner,address admin, address baseToken, uint256 ownerFund) {
    _owner = owner;
    _admin = admin;
    _baseToken = baseToken;
    _ownerFund = ownerFund;

    _transferFromSelector = bytes4(keccak256("transferFrom(address,address,uint256)"));
    _transferSelector = bytes4(keccak256("transfer(address,uint256)"));
    _balanceOf = bytes4(keccak256("balanceOf(address)"));
  }

  // returns total liquidity of the contract
  function totalLiquidity() public returns (uint256) {
    return availableLiquidity().add(_totalLockedFunds);
  }

  // returns the amount of available Liquidity of the contract
  function availableLiquidity() public returns (uint256) {
    (bool _success,bytes memory _data ) = _baseToken.call(abi.encodeWithSelector(_balanceOf,address(this)));
    require(_success,"Fetching balance failed");
    return uint256(bytes32(_data));
  }
 
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
  function profitShare(uint256 _amount,bytes memory _signature) public _onlyOwner() returns (bool) {}

  // the owner or admin can call this function to specify the amount of loss
  // todo add hash of Positions to this function
  function burn(uint256 _amount,bytes memory _signature) public _onlyOwner() returns (bool) {}

  // ─── Withdraw ────────────────────────────────────────────────────────

  // returns the withdrawable profit for the account.
  function withdrawableProfit(address _account) public view returns (uint256) {
    return _profits[_account];
  }

  // return the total withdrawable funds for this account in this basket
  function withdrawableFund(address _account) public view returns (uint256) {
    return _releasedFunds[_account].add(IterableMapping.get(_queuedFunds, _account));
  }

  // return the queued funds for this account in this basket
  function queuedFund(address _account) public view returns (uint256) {
    return IterableMapping.get(_queuedFunds, _account);
  }

  function withdrawProfit(uint256 _amount) public returns (bool) {
    return _withdrawProfit(_amount, msg.sender);
  }

  // withdrawProfit allows the admin to do a withdraw for the _account.
  // the founds will trasfer from the Contract to the account.
  function withdrawProfit(uint256 _amount, address _account) public returns (bool) {
    return _withdrawProfit(_amount, _account);
  }

  function withdrawFund(uint256 _amount) public returns (bool) {
    return _withdrawFund(_amount, msg.sender);
  }

  function withdrawFund(uint256 _amount, address _account) public returns (bool) {
    return _withdrawFund(_amount, _account);
  }

  function _withdrawProfit(uint256 _amount,address _account) internal returns (bool) {
    _profits[_account] = _profits[_account].sub(_amount);
    return __transfer(_amount, _account);
  }

  function _withdrawFund(uint256 _amount,address _account) internal returns (bool) {
    _queuedFunds.set(_account, _releasedFunds[_account].add(_queuedFunds.get(_account)).sub(_amount));
    _releasedFunds[_account] = 0;
    return __transfer(_amount, _account);
  }

  function __transfer(uint256 _amount,address _account) internal returns (bool) {
    (bool success,) =_baseToken.call(abi.encodeWithSelector(_transferSelector, _account, _amount));
    require(success,"Transfering from contract failed");
    _availableLiquidity = _availableLiquidity.sub(_amount);
    return true;
  }

  // ─── Investing ───────────────────────────────────────────────────────

  function invest(uint256 _amount, bytes memory _signature) public
    _isActive() 
    _isAcceptable(_amount) 
    _mustBeAllowedToInvest(_amount,msg.sender,_signature) 
    _mustBeTransferred(_amount,msg.sender,address(this)) 
    returns (bool) {
    _queuedFunds.set(msg.sender, _queuedFunds.get(msg.sender).add(_amount));
    _totalQueuedFunds = _totalQueuedFunds.add(_amount);
  }
  
  // reinvest from the Profit gained
  function reinvestFromProfit(uint256 _amount) public returns (bool) {
    return _reinvestFromProfit(_amount, msg.sender);
  }

  // reivest on the behalf of the owner by the admin 
  function reinvestFromProfit(uint256 _amount, address _from) _onlyAdmin() public returns (bool) {
    return _reinvestFromProfit(_amount, _from);
  }

  function _reinvestFromProfit(uint256 _amount, address _from) _isAcceptable(_amount) internal returns (bool) {
    _profits[_from] = _profits[_from].sub(_amount);
    _queuedFunds.set(_from, _queuedFunds.get(_from).add(_amount));
    return true;
  }
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

  modifier _mustBeTransferred(uint256 _amount, address _from,address _to) {
    (bool _success, ) = _baseToken.call(abi.encodeWithSelector(_transferFromSelector,_from, _to, _amount));
    require(_success,"Transfering from _contract failed");
    _availableLiquidity = _availableLiquidity.add(_amount);
    _;
  }

  modifier _mustBeAllowedToInvest(uint256 _amount, address _from, bytes memory _signature) {
    // todo invest signature {amount(uint256),from(address),expiration(blockHeight)}
    _;
  }

  modifier _isAcceptable(uint256 _amount) {
    require(_totalQueuedFunds.add(_totalLockedFunds).add(_amount).sub(_totalWithdrawRequests) <= _maximumFund,"the Basket is full");
    _;
  }

}