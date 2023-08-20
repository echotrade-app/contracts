// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./lib/SafeMath.sol";
import "./lib/IterableMapping.sol";
import "hardhat/console.sol";

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
  uint256 public _requirdLiquidity;
  uint256 public _exchangeLockedLiquidity; // _totalLiquidity = _availableLiquidity + _exchangeLockedLiquidity + totalProfits
  uint256 public _inContractLockedLiquidity; // _totalLockedFunds = _exchangeLockedLiquidity + _inContractLockedLiquidity

  uint256 private _totalLockedFunds;
  uint256 public _totalWithdrawRequests;
  uint256 public _totalQueuedFunds;

  IterableMapping.Map private _withdrawRequests;

  IterableMapping.Map private _lockedFunds;
  IterableMapping.Map private _queuedFunds;
  mapping (address => uint256) public _releasedFunds;
  mapping (address => uint256) public _profits;

  bytes4 private _transferFromSelector;
  bytes4 private _transferSelector;
  bytes4 private _balanceOfSelector;

  
  // totalLiquidity = availbaleLiquidity + lockedFunds; 
  // totalLiquidity = queuedFunds + _releasedFunds + _profits + _lockedFunds
  // withdrawableFunds = queuedFunds + _releasedFunds
  // availableLiquidity >= _releasedFunds + _profits + _queuedFunds
  //
  // --QueuedFunds-->|---->>>----|--ReleasedFunds-->
  //                 |LockedFunds|--Profits-->
  //                 |----<<<----|

//   constructor(address owner,address admin, address baseToken, uint256 ownerFund) {
  constructor( address baseToken, uint256 ownerFund) {
    // _owner = owner;
    _owner = msg.sender;
    // _admin = admin;
    _admin = msg.sender;
    _baseToken = baseToken;
    _ownerFund = ownerFund;
    
    _maximumFund = 10000;

    _transferFromSelector = bytes4(keccak256("transferFrom(address,address,uint256)"));
    _transferSelector = bytes4(keccak256("transfer(address,uint256)"));
    _balanceOfSelector = bytes4(keccak256("balanceOf(address)"));
  }

  // close the basket
  function close() public _onlyOwner() returns (bool) {
    _status = status.closed;
    return true;
  }
  
  function totalLockedFunds() external view returns(uint256) {
      return _totalLockedFunds;
  }
  
  function lockedFunds(address _account) external view returns (uint256) {
      return _lockedFunds.get(_account);
  }

  // the owner should approve _owner_fund to this contract, to be accivated, one the basket closes, this ammount will return back to the owner. 
  function active() public _onlyOwner() returns (bool) {
      _status = status.active;
      return true;
  }

  // the owner or admin can call this function to specify the amount of profit
  function profitShare(int256 _amount,bytes memory _history,bytes memory _signature) public _onlyOwner() returns (bool) {
    if (_amount >= 0) {
      return _profitShare(uint256(_amount));
    }else {
      return _loss(uint256(-_amount));
    }
    // todo push the records.
  }

  function _profitShare(uint256 _amount) internal returns (bool)  {

    // Manage Liquidity
    // share profit/loss
    // luck queued funds
    // release requested funds

    
   
    // ─── Manage Liquidity ────────────────────────────────────────
    
    int256 _requiredTransfer = int256(_amount + _totalWithdrawRequests ) - int256(_totalQueuedFunds) - int256(_inContractLockedLiquidity);
    // the _requiredTransfer should be transfer from exchange to smart Contract.
    if (_requiredTransfer > 0) {
      _requirdLiquidity = _requirdLiquidity.add(uint256(_amount)).add(_totalWithdrawRequests).sub(_totalQueuedFunds);
      require(_mybalance(_baseToken) >= _requirdLiquidity,"required more funds for profit sharing");
    
      _exchangeLockedLiquidity = _exchangeLockedLiquidity.add(_totalQueuedFunds).add(_amount).sub(uint256(_requiredTransfer));
      _inContractLockedLiquidity = _inContractLockedLiquidity.add(uint256(_requiredTransfer)).sub(_totalWithdrawRequests).sub(_amount);

    }else {

      _exchangeLockedLiquidity = _exchangeLockedLiquidity.add(_amount);
      _inContractLockedLiquidity = _inContractLockedLiquidity.add(_totalQueuedFunds).sub(_amount).sub(_totalWithdrawRequests);
      _requirdLiquidity = _requirdLiquidity + _amount + _totalWithdrawRequests - _totalQueuedFunds;
    }
    
    
    // ─── Share Profit And Loss ───────────────────────────────────
    __profit(_amount);
     _totalLockedFunds= _totalLockedFunds.add(_totalQueuedFunds).sub(_totalWithdrawRequests);
    // ─── Lock Queued Funds ───────────────────────────────────────
    __lockQueuedFunds();
    
    // ─── Release Requested Funds ─────────────────────────────────
    __releaseFund();
    
    return true;
  }

  function profitShareRequiredFund(uint256 _amount) public view returns (int256) {
    return int256(_amount + _totalWithdrawRequests ) - int256(_totalQueuedFunds) - int256(_inContractLockedLiquidity);
  }

  function _loss(uint256 _amount) internal returns (bool) {}
  function __loss(uint256 _amount) internal returns (bool) {
    for (uint i = 0; i < _lockedFunds.size(); ++i) {
      address key = _lockedFunds.getKeyAtIndex(i);
      if (_lockedFunds.get(key) == 0) {
        continue;
      }
      _lockedFunds.set(key,_lockedFunds.get(key).sub( SafeMath.div(SafeMath.mul(_lockedFunds.get(key) , _amount),_totalLockedFunds)));
    }
  }
  
  function __profit(uint256 _amount) internal  {
    for (uint i = _lockedFunds.size(); i > 0 ; --i) {
        address key = _lockedFunds.getKeyAtIndex(i-1);
        if (_lockedFunds.get(key) == 0) {
          continue;
        }
        _profits[key] = _profits[key].add(SafeMath.div(SafeMath.mul(_lockedFunds.get(key) , _amount),_totalLockedFunds));
        // console.log("shareprofit",key,);
    }
  }

  function __lockQueuedFunds() internal {
    for (uint i = _queuedFunds.size(); i > 0 ; --i) {
      address key = _queuedFunds.getKeyAtIndex(i-1);
      _lockedFunds.set(key,_lockedFunds.get(key).add(_queuedFunds.get(key)));
      _queuedFunds.remove(key);
    }
    _totalQueuedFunds = 0;
  }

  function __releaseFund() internal {
    for (uint i = _withdrawRequests.size(); i > 0 ; --i) {
        address key = IterableMapping.getKeyAtIndex(_withdrawRequests, i-1);
        if ( _withdrawRequests.get(key) < _lockedFunds.get(key) ) {
          // realease requested funds
          // release funds from the lucked amounts
          _lockedFunds.set(key,_lockedFunds.get(key).sub(_withdrawRequests.get(key)));
          // release the funds
          _releasedFunds[key] = _releasedFunds[key].add(_withdrawRequests.get(key));
          // reset the widthraw request
          _withdrawRequests.remove(key);
        }else {
          // release all funds of the key
          // the _amount is _lockedFunds.get(key)
          _releasedFunds[key] = _releasedFunds[key].add(_lockedFunds.get(key));
          // remove the funds from the lucked amounts
          _lockedFunds.remove(key);
          // reset the widthraw request
          _withdrawRequests.remove(key);
        }
        
    }
    _totalWithdrawRequests = 0;
  }

  function __realTotalWithdrawRequests(int256 _amount) internal returns (uint256) {
    if (_amount > 0) {
      return _totalWithdrawRequests;
    }else {
      return _totalWithdrawRequests.sub(SafeMath.div(uint256(-_amount) * _totalWithdrawRequests,_totalLockedFunds));
    }
  }

  // ─── Withdraw ────────────────────────────────────────────────────────

  function withdrawFundRequest(uint256 _amount) public returns (bool) {
    return _withdrawFundRequest(_amount,msg.sender);
  }
  
  function withdrawFundRequestFrom(uint256 _amount,address _account) public _onlyAdmin() returns (bool) {
    return _withdrawFundRequest(_amount,_account);
  }

  // return the total withdrawable funds for this account in this basket
  function withdrawableFund(address _account) public view returns (uint256) {
    return _releasedFunds[_account].add(_queuedFunds.get(_account));
  }

  // return the queued funds for this account in this basket
  function queuedFund(address _account) public view returns (uint256) {
    return IterableMapping.get(_queuedFunds,_account);
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
    if (_releasedFunds[_account] >= _amount) {
      _releasedFunds[_account] = _releasedFunds[_account].sub(_amount);
    } else {
      _queuedFunds.set(_account, _releasedFunds[_account].add(_queuedFunds.get(_account)).sub(_amount));
      _totalQueuedFunds = _totalQueuedFunds.sub(_amount.sub(_releasedFunds[_account]));
      _releasedFunds[_account] = 0;
    }
    return __transfer(_amount, _account);
  }

  function _withdrawFundRequest(uint256 _amount,address _account) internal returns (bool) {
    require(_lockedFunds.get(_account) >= _withdrawRequests.get(_account).add(_amount),"you don't have that much funds");
    _totalWithdrawRequests = _totalWithdrawRequests.add(_amount);
    _withdrawRequests.set(_account,_withdrawRequests.get(_account).add(_amount));
    return true;
  }

  // __transfer is very private function to transfer baseToken from this contract account to _account. 
  function __transfer(uint256 _amount,address _account) internal returns (bool) {
    (bool success,) =_baseToken.call(abi.encodeWithSelector(_transferSelector, _account, _amount));
    require(success,"Transfering from contract failed");
    _requirdLiquidity = _requirdLiquidity.sub(_amount);
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
    return true;
  }
  
  // reinvest from the Profit gained
  function reinvestFromProfit(uint256 _amount) public returns (bool) {
    return _reinvestFromProfit(_amount, msg.sender);
  }

  // reivest on the behalf of the owner by the admin 
  function reinvestFromProfit(uint256 _amount, address _from) _onlyAdmin() public returns (bool) {
    return _reinvestFromProfit(_amount, _from);
  }

  // _reinvestFromProfit 
  function _reinvestFromProfit(uint256 _amount, address _from) _isAcceptable(_amount) internal returns (bool) {
    _profits[_from] = _profits[_from].sub(_amount);
    _queuedFunds.set(_from, _queuedFunds.get(_from).add(_amount));
    _totalQueuedFunds = _totalQueuedFunds + _amount;
    return true;
  }


  function _mybalance(address _contract) internal returns (uint256) {
    (bool _success,bytes memory _data ) = _contract.call(abi.encodeWithSelector(_balanceOfSelector,address(this)));
    require(_success,"Fetching balance failed");
    return uint256(bytes32(_data));
  }

  // ─── Modifiers ───────────────────────────────────────────────────────


  // specify weather the basket is active or not.
  modifier _isActive() {
    require(_status == status.active, "Basket is not active yet");
    _;
  }
  
  // only owners (trader or superadmin) can call the function
  modifier _onlyOwner() {
    require(msg.sender == _owner || msg.sender == _admin, "Only owner is allowed to call this method");
    _;
  }

  // only superadmin can call the function
  modifier _onlyAdmin() {
    require(msg.sender == _admin, "Only admin is allowed to call this method");
    _;
  }

  // the _amount should be transfered from the _from account to the _to account.
  modifier _mustBeTransferred(uint256 _amount, address _from,address _to) {
    (bool _success, ) = _baseToken.call(abi.encodeWithSelector(_transferFromSelector,_from, _to, _amount));
    require(_success,"Transfering from _contract failed");
    // todo is this section should be here or not? since the _to account is not speicifed by address(this)
    _requirdLiquidity = _requirdLiquidity.add(_amount);
    _;
  }

  // check the signature of allowance of investing which is granted by the superadmin.
  modifier _mustBeAllowedToInvest(uint256 _amount, address _from, bytes memory _signature) {
    // todo invest signature {amount(uint256),from(address),expiration(blockHeight)}
    _;
  }

  // check that after investing this _amount the total funds is not exceeding the _maximum funds.
  modifier _isAcceptable(uint256 _amount) {
    require(_totalQueuedFunds.add(_totalLockedFunds).add(_amount).sub(_totalWithdrawRequests) <= _maximumFund,"the Basket is full");
    _;
  }

}