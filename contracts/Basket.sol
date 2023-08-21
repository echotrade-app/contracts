// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./lib/SafeMath.sol";
import "./lib/IterableMapping.sol";
import "hardhat/console.sol";

contract Basket {
  using SafeMath for uint256;
  using IterableMapping for IterableMapping.Map;
  
  enum Status {pending, active, closed }

  address public trader;
  address public admin;

  address public baseToken;

  Status public status;
  uint256 public ownerFund;
  uint public xid;
  uint64 public iteration;
  uint64 public duration;
  uint public startTime;
  uint public endTime;
  uint256 public minFund;
  uint256 public maximumFund;

  uint256 public ownerSuccessFee;
  uint256 public adminSuccessFee;

  uint256 public _requirdLiquidity;
  uint256 public _exchangeLockedLiquidity; // _totalLiquidity = _requirdLiquidity + _exchangeLockedLiquidity + _contractLockedLiquidity
  uint256 public _inContractLockedLiquidity; // totalLockedFunds = _exchangeLockedLiquidity + _inContractLockedLiquidity

  uint256 public totalLockedFunds;
  uint256 public totalWithdrawRequests;
  uint256 public totalQueuedFunds;

  IterableMapping.Map private _withdrawRequests;

  IterableMapping.Map private _lockedFunds;
  IterableMapping.Map private _queuedFunds;
  mapping (address => uint256) public releasedFunds;
  mapping (address => uint256) public profits;

  bytes4 private _transferFromSelector;
  bytes4 private _transferSelector;
  bytes4 private _balanceOfSelector;

  
  // totalLiquidity = availbaleLiquidity + lockedFunds; 
  // totalLiquidity = queuedFunds + releasedFunds + profits + _lockedFunds
  // withdrawableFunds = queuedFunds + releasedFunds
  // availableLiquidity >= releasedFunds + profits + _queuedFunds
  //
  // --QueuedFunds-->|---->>>----|--ReleasedFunds-->
  //                 |LockedFunds|--Profits-->
  //                 |----<<<----|

//   constructor(address owner,address admin, address baseToken, uint256 ownerFund) {
  constructor( 
    uint _xid,
    address _baseToken,
    address _trader,
    uint256 _ownerFund,
    uint256 _maximumFund,
    uint256 _minFund,
    uint256 _ownerSuccessFee,
    uint256 _adminSuccessFee
    ) {
    trader = _trader;
    admin = msg.sender;

    baseToken = _baseToken;
    
    status = Status.pending;

    ownerFund = _ownerFund;
    xid = _xid;
    maximumFund = _maximumFund;
    minFund = _minFund;
    
    ownerSuccessFee = _ownerSuccessFee;
    adminSuccessFee = _adminSuccessFee;

    _transferFromSelector = bytes4(keccak256("transferFrom(address,address,uint256)"));
    _transferSelector = bytes4(keccak256("transfer(address,uint256)"));
    _balanceOfSelector = bytes4(keccak256("balanceOf(address)"));
  }

  // close the basket
  function close() public _onlyOwner() returns (bool) {
    status = Status.closed;
    return true;
  }

  // the owner should approve _owner_fund to this contract, to be accivated, one the basket closes, this ammount will return back to the owner. 
  function active() public _onlyOwner() _ownerFundTransfered() returns (bool) {
      status = Status.active;
      // todo add Investment for the trader.
      return true;
  }

  // the owner or admin can call this function to specify the amount of profit
  function profitShare(int256 _amount,bytes memory _history,bytes memory _signature) public _onlyOwner() _profitShareCheck() returns (bool) {
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
    
    int256 _requiredTransfer = int256(_amount + totalWithdrawRequests ) - int256(totalQueuedFunds) - int256(_inContractLockedLiquidity);
    // the _requiredTransfer should be transfer from exchange to smart Contract.
    if (_requiredTransfer > 0) {
      _requirdLiquidity = _requirdLiquidity.add(uint256(_amount)).add(totalWithdrawRequests).sub(totalQueuedFunds);
      require(_mybalance(baseToken) >= _requirdLiquidity,"required more funds for profit sharing");
    
      _exchangeLockedLiquidity = _exchangeLockedLiquidity.add(totalQueuedFunds).add(_amount).sub(uint256(_requiredTransfer));
      _inContractLockedLiquidity = _inContractLockedLiquidity.add(uint256(_requiredTransfer)).sub(totalWithdrawRequests).sub(_amount);

    }else {

      _exchangeLockedLiquidity = _exchangeLockedLiquidity.add(_amount);
      _inContractLockedLiquidity = _inContractLockedLiquidity.add(totalQueuedFunds).sub(_amount).sub(totalWithdrawRequests);
      _requirdLiquidity = _requirdLiquidity + _amount + totalWithdrawRequests - totalQueuedFunds;
    }
    
    
    // ─── Share Profit And Loss ───────────────────────────────────
    __profit(_amount);
     totalLockedFunds= totalLockedFunds.add(totalQueuedFunds).sub(totalWithdrawRequests);
    // ─── Lock Queued Funds ───────────────────────────────────────
    __lockQueuedFunds();
    
    // ─── Release Requested Funds ─────────────────────────────────
    __releaseFund();
    
    return true;
  }

  function profitShareRequiredFund(int256 _amount) public view returns (int256) {
    return _amount >= 0 ? _amount + int256(__realTotalWithdrawRequests(_amount)) - int256(totalQueuedFunds) - int256(_inContractLockedLiquidity) : int256(__realTotalWithdrawRequests(_amount)) - int256(totalQueuedFunds) - int256(_inContractLockedLiquidity);
  }

  function _loss(uint256 _amount) internal returns (bool) {
    require(_amount <= _exchangeLockedLiquidity, "you can not loss more than requidity of your exchange");
    // Manage Liquidity
    // share profit/loss
    // luck queued funds
    // release requested funds

    // ─── Manage Liquidity ────────────────────────────────────────
    uint256 _rtotalWithdrawRequest = __realTotalWithdrawRequests(-int256(_amount));
    int256 _requiredTransfer = int256(_rtotalWithdrawRequest ) - int256(totalQueuedFunds) - int256(_inContractLockedLiquidity);
    if (_requiredTransfer > 0 ) {
      _requirdLiquidity = _requirdLiquidity.add(_rtotalWithdrawRequest).sub(totalQueuedFunds);
      require(_mybalance(baseToken) >= _requirdLiquidity,"required more funds for profit sharing");
      _exchangeLockedLiquidity = _exchangeLockedLiquidity.sub(_amount).sub(uint256(_requiredTransfer));
      _inContractLockedLiquidity = _inContractLockedLiquidity.add(uint256(_requiredTransfer)).add(totalQueuedFunds).sub(_rtotalWithdrawRequest);
    }else {
      _exchangeLockedLiquidity = _exchangeLockedLiquidity.sub(_amount);
      _inContractLockedLiquidity = _inContractLockedLiquidity.add(totalQueuedFunds).sub(_rtotalWithdrawRequest);
      _requirdLiquidity = _requirdLiquidity + _rtotalWithdrawRequest - totalQueuedFunds;
    }

    // ─── Share Profit And Loss ───────────────────────────────────
    __loss(_amount);
    totalLockedFunds = totalLockedFunds.add(totalQueuedFunds).sub(_rtotalWithdrawRequest).sub(_amount);

    // ─── Lock Queued Funds ───────────────────────────────────────
    __lockQueuedFunds();
    
    // ─── Release Requested Funds ─────────────────────────────────
    __releaseFund();

    return true;
  }

  function __loss(uint256 _amount) internal returns (bool) {
    for (uint i = _lockedFunds.size(); i > 0 ; --i) {
      address key = _lockedFunds.getKeyAtIndex(i-1);
      if (_lockedFunds.get(key) == 0) {
        _lockedFunds.remove(key);
        continue;
      }
      _lockedFunds.set(key,_lockedFunds.get(key).sub( SafeMath.div(SafeMath.mul(_lockedFunds.get(key) , _amount),totalLockedFunds)));
    }
    return true;
  }
  
  function __profit(uint256 _amount) internal  {
    for (uint i = _lockedFunds.size(); i > 0 ; --i) {
        address key = _lockedFunds.getKeyAtIndex(i-1);
        if (_lockedFunds.get(key) == 0) {
          continue;
        }
        profits[key] = profits[key].add(SafeMath.div(SafeMath.mul(_lockedFunds.get(key) , _amount),totalLockedFunds));
        // console.log("shareprofit",key,);
    }
  }

  function __lockQueuedFunds() internal {
    for (uint i = _queuedFunds.size(); i > 0 ; --i) {
      address key = _queuedFunds.getKeyAtIndex(i-1);
      _lockedFunds.set(key,_lockedFunds.get(key).add(_queuedFunds.get(key)));
      _queuedFunds.remove(key);
    }
    totalQueuedFunds = 0;
  }

  function __releaseFund() internal {
    for (uint i = _withdrawRequests.size(); i > 0 ; --i) {
        address key = IterableMapping.getKeyAtIndex(_withdrawRequests, i-1);
        if ( _withdrawRequests.get(key) < _lockedFunds.get(key) ) {
          // realease requested funds
          // release funds from the lucked amounts
          _lockedFunds.set(key,_lockedFunds.get(key).sub(_withdrawRequests.get(key)));
          // release the funds
          releasedFunds[key] = releasedFunds[key].add(_withdrawRequests.get(key));
          // reset the widthraw request
          _withdrawRequests.remove(key);
        }else {
          // release all funds of the key
          // the _amount is _lockedFunds.get(key)
          releasedFunds[key] = releasedFunds[key].add(_lockedFunds.get(key));
          // remove the funds from the lucked amounts
          _lockedFunds.remove(key);
          // reset the widthraw request
          _withdrawRequests.remove(key);
        }
        
    }
    totalWithdrawRequests = 0;
  }

  function __realTotalWithdrawRequests(int256 _amount) public view returns (uint256) {
    if (_amount > 0) {
      return totalWithdrawRequests;
    }else {
      return totalWithdrawRequests.sub(SafeMath.div(uint256(-_amount) * totalWithdrawRequests,totalLockedFunds));
    }
  }

  // ─── Funds ───────────────────────────────────────────────────────────

  function lockedFunds(address _account) external view returns (uint256) {
    return _lockedFunds.get(_account);
  }

  // return the queued funds for this account in this basket
  function queuedFund(address _account) public view returns (uint256) {
    return IterableMapping.get(_queuedFunds,_account);
  }

  // return the total withdrawable funds for this account in this basket
  function withdrawableFund(address _account) public view returns (uint256) {
    return releasedFunds[_account].add(_queuedFunds.get(_account));
  }

  // ─── Withdraw ────────────────────────────────────────────────────────

  function withdrawFundRequest(uint256 _amount) public returns (bool) {
    //todo add check for trader to not be able to withdraw the ownerFunds.
    return _withdrawFundRequest(_amount,msg.sender);
  }
  
  function withdrawFundRequestFrom(uint256 _amount,address _account) public _onlyAdmin() returns (bool) {
    return _withdrawFundRequest(_amount,_account);
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
    profits[_account] = profits[_account].sub(_amount);
    return __transfer(_amount, _account);
  }

  function _withdrawFund(uint256 _amount,address _account) internal returns (bool) {
    if (releasedFunds[_account] >= _amount) {
      releasedFunds[_account] = releasedFunds[_account].sub(_amount);
    } else {
      _queuedFunds.set(_account, releasedFunds[_account].add(_queuedFunds.get(_account)).sub(_amount));
      totalQueuedFunds = totalQueuedFunds.sub(_amount.sub(releasedFunds[_account]));
      releasedFunds[_account] = 0;
    }
    return __transfer(_amount, _account);
  }

  function _withdrawFundRequest(uint256 _amount,address _account) internal returns (bool) {
    require(_lockedFunds.get(_account) >= _withdrawRequests.get(_account).add(_amount),"you don't have that much funds");
    totalWithdrawRequests = totalWithdrawRequests.add(_amount);
    _withdrawRequests.set(_account,_withdrawRequests.get(_account).add(_amount));
    return true;
  }

  // __transfer is very private function to transfer baseToken from this contract account to _account. 
  function __transfer(uint256 _amount,address _account) internal returns (bool) {
    (bool success,) = baseToken.call(abi.encodeWithSelector(_transferSelector, _account, _amount));
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
    totalQueuedFunds = totalQueuedFunds.add(_amount);
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
    profits[_from] = profits[_from].sub(_amount);
    _queuedFunds.set(_from, _queuedFunds.get(_from).add(_amount));
    totalQueuedFunds = totalQueuedFunds + _amount;
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
    require(status == Status.active, "Basket is not active yet");
    _;
  }
  
  // only owners (trader or superadmin) can call the function
  modifier _onlyOwner() {
    require(msg.sender == trader || msg.sender == admin, "Only owner is allowed to call this method");
    _;
  }

  // only superadmin can call the function
  modifier _onlyAdmin() {
    require(msg.sender == admin, "Only admin is allowed to call this method");
    _;
  }

  // the _amount should be transfered from the _from account to the _to account.
  modifier _mustBeTransferred(uint256 _amount, address _from,address _to) {
    (bool _success, ) = baseToken.call(abi.encodeWithSelector(_transferFromSelector,_from, _to, _amount));
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
    require(totalQueuedFunds.add(totalLockedFunds).add(_amount).sub(totalWithdrawRequests) <= maximumFund,"the Basket is full");
    require(block.timestamp < endTime);
    _;
  }

  modifier _ownerFundTransfered() {
    //todo add condition
    _;
  }

  modifier _profitShareCheck() {
    require( (iteration > 0) || (iteration == 0 && totalQueuedFunds >= minFund),"funds is less than minFund");
    require( block.timestamp > startTime);
    _;
  }

}