// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./SafeMath.sol";
import "./IterableMapping.sol";
import "./signature.sol";

contract Basket {
  using SafeMath for uint256;
  using IterableMapping for IterableMapping.Map;
  
  enum Status {pending, active, closed }
  struct ProfitShareRecord {
    uint64 id;
    int256 amount;
    bytes32 cid;
  }

  address public trader;
  address public admin;
  address public adminAssistant;

  address public baseToken;

  Status public status;
  uint256 public traderFund;
  uint public xid;
  uint64 public iteration;
  uint64 public duration;
  uint public startTime;
  uint public endTime;
  uint256 public minFund;
  uint256 public maximumFund;

  uint256 public traderSuccessFee;
  uint256 public adminSuccessFee;

  uint256 public requirdLiquidity;
  uint256 public exchangeLockedLiquidity; // _totalLiquidity = requirdLiquidity + exchangeLockedLiquidity + _contractLockedLiquidity
  uint256 public contractLockedLiquidity; // totalLockedFunds = exchangeLockedLiquidity + contractLockedLiquidity

  uint256 public totalLockedFunds;
  uint256 public totalWithdrawRequests;
  uint256 public totalQueuedFunds;
  uint256 public adminShare;

  uint256 private signatureExpiration = 300 seconds; // 600s /2  = 300

  IterableMapping.Map private _withdrawRequests;

  IterableMapping.Map private _lockedFunds;
  IterableMapping.Map private _queuedFunds;
  mapping (address => uint256) public releasedFunds;
  mapping (address => uint256) public profits;

  ProfitShareRecord[] public _profitShares;

  bytes4 private constant TRANSFER_FROM_SELECTOR = bytes4(keccak256("transferFrom(address,address,uint256)"));
  bytes4 private constant TRANSFER_SELECTOR = bytes4(keccak256("transfer(address,uint256)"));
  bytes4 private constant BALANCE_OF_SELECTOR = bytes4(keccak256("balanceOf(address)"));

  string constant private SIGPREFIX = "\x19Ethereum Signed Message:\n32"; 

  event Invest(address _account, uint256 _amount);
  event WithdrawProfit(address _account, uint256 _amount);
  event UnlockFundRequest(address _account, uint256 _amount);
  event WithdrawFund(address _account, uint256 _amount);
  event ProfitShare(int256 _amount);
  event ReinvestFromProfit(address _account, uint256 _amount);
  event Active();
  event Close();
  event TransferFundToExchange(address _account,uint256 _amount);
  event TransferFundFromExchange(uint256 _amount);

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
    address _admin,
    uint256 _traderFund,
    uint256 _maximumFund,
    uint256 _minFund,
    uint256 _traderSuccessFee,
    uint256 _adminSuccessFee,
    uint256 _startTime,
    uint256 _endTime
    ) {
    trader = _trader;
    admin = _admin;
    adminAssistant = msg.sender;

    baseToken = _baseToken;
    
    status = Status.pending;

    traderFund = _traderFund;
    xid = _xid;
    maximumFund = _maximumFund;
    minFund = _minFund;
    
    startTime = _startTime;
    endTime = _endTime;

    traderSuccessFee = _traderSuccessFee;
    adminSuccessFee = _adminSuccessFee;

  }

  // ─── Administoration ─────────────────────────────────────────────────

  // close the basket
  function close() public _onlyOwner() returns (bool) {
    status = Status.closed;
    // inExchangeLiquidity = 0
    require(exchangeLockedLiquidity == 0, "requires all funds to be transfered to the Basket");
    require(_mybalance(baseToken) >= totalLockedFunds + requirdLiquidity, "isufficent liquidity to close the Basket");
    // release all Lockedfunds & queued funds and remove all unlockedFunds Requests
    // TraderFunds will be released in __releaseAllFunds too.
    __releaseAllFunds();

    contractLockedLiquidity = 0;

    emit Close();
    return true;
  }

  // the owner should approve _owner_fund to this contract, to be accivated, one the basket closes, this ammount will return back to the owner. 
  function active() public _onlyOwner() _ownerFundTransfered() returns (bool) {
      status = Status.active;
      contractLockedLiquidity = contractLockedLiquidity.add(traderFund);
      _lockedFunds.set(trader, traderFund);
      totalLockedFunds = totalLockedFunds.add(traderFund);
      emit Active();
      return true;
  }

  function setAssistant(address _account) public _onlyAdmin() returns (bool) {
    adminAssistant = _account;
    return true;
  }

  function transferFundToExchange(address _account,uint256 _amount) public _onlyAdminOrAssitant() returns (bool) {
    contractLockedLiquidity = contractLockedLiquidity.sub(_amount);
    exchangeLockedLiquidity = exchangeLockedLiquidity.add(_amount);
    (bool success,) = baseToken.call(abi.encodeWithSelector(TRANSFER_SELECTOR, _account, _amount));
    require(success,"Transfering from contract failed");
    emit TransferFundToExchange(_account, _amount);
    return true;
  }

  function transferFundFromExchange(uint256 _amount) public _onlyAdminOrAssitant() returns (bool) {
    require(_mybalance(baseToken) >= requirdLiquidity+_amount,"requires more funds for transferring from the exchange");
    contractLockedLiquidity = contractLockedLiquidity.add(_amount);
    exchangeLockedLiquidity = exchangeLockedLiquidity.sub(_amount);
    emit TransferFundFromExchange(_amount);
    return true;
  }

  function adminShareProfit() public _onlyAdminOrAssitant() returns (uint256) {
    bool success =  __transfer(adminShare,admin);
    require(success,"transferFund failed");
    uint256 _amount = adminShare;
    adminShare = 0;
    return _amount;
  }

  function withdrawReminders(address _contract) public _onlyAdminOrAssitant() returns (bool) {
    require(status==Status.closed,"Basket must be closed to call this method");
    uint256 amount = _mybalance(_contract);
    if (_contract == baseToken) {
      amount = amount.sub(requirdLiquidity);
    }
    (bool success, ) = _contract.call(abi.encodeWithSelector(TRANSFER_SELECTOR,msg.sender,amount));
    require(success,"transfering from contract failed");
    return true;
  }

  // ─── Profit Sharing ──────────────────────────────────────────────────

  // the owner or admin can call this function to specify the amount of profit
  function profitShare(int256 _amount,bytes32 _history,bytes memory _signature) public _onlyOwner() _profitShareCheck() returns (bool success) {
    if (_amount >= 0) {
      success = _profitShare(uint256(_amount));
    }else {
      success = _loss(uint256(-_amount));
    }
    
    _profitShares.push(ProfitShareRecord(++iteration, _amount ,_history));
    emit ProfitShare(_amount);
    return success;
  }
  
  function profitShare_signatureData(uint256 _index, uint256 _amount, bytes32 _history, uint256 _exp) public pure returns (bytes32) {
    return keccak256(abi.encodePacked(_index, _amount, _history, _exp));
  }

  function _profitShare(uint256 _amount) internal returns (bool)  {

    // Manage Liquidity
    // share profit/loss
    // luck queued funds
    // release requested funds

    uint256 _adminShare = SafeMath.div(SafeMath.mul(_amount, adminSuccessFee), 10000); // 2 flouting number presision for percents 2.5% => 250
    uint256 traderShare = SafeMath.div(SafeMath.mul(_amount, traderSuccessFee), 10000); // 2 flouting number presision for percents 15% => 1500
    // ─── Manage Liquidity ────────────────────────────────────────
    
    int256 _requiredTransfer = int256(_amount + totalWithdrawRequests ) - int256(totalQueuedFunds) - int256(contractLockedLiquidity);
    // the _requiredTransfer should be transfer from exchange to smart Contract.
    if (_requiredTransfer > 0) {
      requirdLiquidity = requirdLiquidity.add(uint256(_amount)).add(totalWithdrawRequests).sub(totalQueuedFunds);
      require(_mybalance(baseToken) >= requirdLiquidity,"required more funds for profit sharing");
      emit TransferFundFromExchange(uint256(_requiredTransfer));
      exchangeLockedLiquidity = exchangeLockedLiquidity.add(totalQueuedFunds).add(_amount).sub(uint256(_requiredTransfer));
      contractLockedLiquidity = contractLockedLiquidity.add(uint256(_requiredTransfer)).sub(totalWithdrawRequests).sub(_amount);
    }else {

      exchangeLockedLiquidity = exchangeLockedLiquidity.add(_amount);
      contractLockedLiquidity = contractLockedLiquidity.add(totalQueuedFunds).sub(_amount).sub(totalWithdrawRequests);
      requirdLiquidity = requirdLiquidity + _amount + totalWithdrawRequests - totalQueuedFunds;
    }
    
    uint256 shareAmount = _amount.sub(_adminShare).sub(traderShare);
    // ─── Share Profit And Loss ───────────────────────────────────
    __profit(shareAmount);
     totalLockedFunds= totalLockedFunds.add(totalQueuedFunds).sub(totalWithdrawRequests);
    // ─── Lock Queued Funds ───────────────────────────────────────
    __lockQueuedFunds();
    
    // ─── Release Requested Funds ─────────────────────────────────
    __releaseFund();

    // add the trader successFee
    profits[trader] = profits[trader].add(traderShare);
    adminShare = adminShare.add(_adminShare);
    
    return true;
  }

  function _loss(uint256 _amount) internal returns (bool) {
    require(_amount <= exchangeLockedLiquidity, "you can not loss more than requidity of your exchange");
    // Manage Liquidity
    // share profit/loss
    // luck queued funds
    // release requested funds

    // ─── Manage Liquidity ────────────────────────────────────────
    uint256 _rtotalWithdrawRequest = __realTotalWithdrawRequests(-int256(_amount));
    int256 _requiredTransfer = int256(_rtotalWithdrawRequest ) - int256(totalQueuedFunds) - int256(contractLockedLiquidity);
    if (_requiredTransfer > 0 ) {
      requirdLiquidity = requirdLiquidity.add(_rtotalWithdrawRequest).sub(totalQueuedFunds);
      require(_mybalance(baseToken) >= requirdLiquidity,"required more funds for profit sharing");
      emit TransferFundFromExchange(uint256(_requiredTransfer));
      exchangeLockedLiquidity = exchangeLockedLiquidity.sub(_amount).sub(uint256(_requiredTransfer));
      contractLockedLiquidity = contractLockedLiquidity.add(uint256(_requiredTransfer)).add(totalQueuedFunds).sub(_rtotalWithdrawRequest);
    }else {
      exchangeLockedLiquidity = exchangeLockedLiquidity.sub(_amount);
      contractLockedLiquidity = contractLockedLiquidity.add(totalQueuedFunds).sub(_rtotalWithdrawRequest);
      requirdLiquidity = requirdLiquidity + _rtotalWithdrawRequest - totalQueuedFunds;
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

  function __releaseAllFunds() internal {
    totalQueuedFunds = 0;
    totalWithdrawRequests = 0;
    totalLockedFunds = 0;
    for (uint i = _lockedFunds.size(); i > 0 ; --i) {
      address key = _lockedFunds.getKeyAtIndex(i-1);
      requirdLiquidity = requirdLiquidity.add(_lockedFunds.get(key));
      releasedFunds[key] = releasedFunds[key].add(_lockedFunds.get(key)).add(_queuedFunds.get(key));
      _lockedFunds.remove(key);
      _queuedFunds.remove(key);
    }
    for (uint i = _queuedFunds.size(); i > 0 ; --i) {
      address key = _queuedFunds.getKeyAtIndex(i-1);
      releasedFunds[key] = releasedFunds[key].add(_queuedFunds.get(key));
      _queuedFunds.remove(key);
    }
    for (uint i = _withdrawRequests.size(); i > 0 ; --i) {
      address key = _withdrawRequests.getKeyAtIndex(i-1);
      _withdrawRequests.remove(key);
    }

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

  function profitShareRequiredFund(int256 _amount) public view returns (int256) {
    return _amount >= 0 ? _amount + int256(__realTotalWithdrawRequests(_amount)) - int256(totalQueuedFunds) - int256(contractLockedLiquidity) : int256(__realTotalWithdrawRequests(_amount)) - int256(totalQueuedFunds) - int256(contractLockedLiquidity);
  }

  function __realTotalWithdrawRequests(int256 _amount) internal view returns (uint256) {
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

  function unlockFundRequest(uint256 _amount) public _unlockFundRequestAllowed(_amount,msg.sender) returns (bool) {
    return _unlockFundRequest(_amount,msg.sender);
  }
  
  // TODO TO be covered by unit tests
  function unlockFundRequestFrom(uint256 _amount,address _account) public _unlockFundRequestAllowed(_amount,_account) _onlyAdminOrAssitant() returns (bool) {
    return _unlockFundRequest(_amount,_account);
  }

  function withdrawProfit(uint256 _amount) public returns (bool) {
    return _withdrawProfit(_amount, msg.sender);
  }

  // withdrawProfit allows the admin to do a withdraw for the _account.
  // the founds will trasfer from the Contract to the account.
  function withdrawProfit(uint256 _amount, address _account) public returns (bool) {
    return _withdrawProfit(_amount, _account);
  }

  // TODO TO be covered by unit tests
  function withdrawFund(uint256 _amount) public returns (bool) {
    return _withdrawFund(_amount, msg.sender);
  }

  function withdrawFund(uint256 _amount, address _account) public returns (bool) {
    return _withdrawFund(_amount, _account);
  }

  function _withdrawProfit(uint256 _amount,address _account) internal returns (bool) {
    profits[_account] = profits[_account].sub(_amount);
    emit WithdrawProfit(_account, _amount);
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
    emit WithdrawFund(_account, _amount);
    return __transfer(_amount, _account);
  }

  function _unlockFundRequest(uint256 _amount,address _account) internal returns (bool) {
    require(_lockedFunds.get(_account) >= _withdrawRequests.get(_account).add(_amount),"you don't have that much funds");
    totalWithdrawRequests = totalWithdrawRequests.add(_amount);
    _withdrawRequests.set(_account,_withdrawRequests.get(_account).add(_amount));
    emit UnlockFundRequest(_account, _amount);
    return true;
  }

  // __transfer is very private function to transfer baseToken from this contract account to _account. 
  function __transfer(uint256 _amount,address _account) internal returns (bool) {
    (bool success,) = baseToken.call(abi.encodeWithSelector(TRANSFER_SELECTOR, _account, _amount));
    require(success,"Transfering from contract failed");
    requirdLiquidity = requirdLiquidity.sub(_amount);
    return true;
  }

  // ─── Investing ───────────────────────────────────────────────────────

  function invest(uint256 _amount, bytes memory _signature) public
    _mustBeAllowedToInvest(_amount,msg.sender,_signature) 
    _mustBeTransferred(_amount,msg.sender,address(this)) 
    returns (bool) {
    _queuedFunds.set(msg.sender, _queuedFunds.get(msg.sender).add(_amount));
    totalQueuedFunds = totalQueuedFunds.add(_amount);
    emit Invest(msg.sender, _amount);
    return true;
  }

  // TODO TO be covered by unit tests
  function invest_signatureData(address _from, uint256 _amount, uint256 _exp) public view returns (bytes32) {
    return keccak256(abi.encodePacked(address(this),_from, _amount, _exp));
  }
  
  function _mybalance(address _contract) internal returns (uint256) {
    (bool _success,bytes memory _data ) = _contract.call(abi.encodeWithSelector(BALANCE_OF_SELECTOR,address(this)));
    require(_success,"Fetching balance failed");
    return uint256(bytes32(_data));
  }

  // ─── Modifiers ───────────────────────────────────────────────────────
  
  // only owners (trader or superadmin) can call the function
  modifier _onlyOwner() {
    require(msg.sender == trader || msg.sender == adminAssistant || msg.sender == admin, "only owner is allowed to call this method");
    _;
  }

  // only superadmin can call the function
  // TODO TO be covered by unit tests
  modifier _onlyAdmin() {
    require(msg.sender == admin, "only admin is allowed to call this method");
    _;
  }
  // only superadmin or it's assitant can call the function
  modifier _onlyAdminOrAssitant() {
    require( msg.sender == adminAssistant || msg.sender == admin, "only admin or adminAssitant is allowed to call this method");
    _;
  }

  // the _amount should be transfered from the _from account to the _to account.
  modifier _mustBeTransferred(uint256 _amount, address _from,address _to) {
    (bool _success, ) = baseToken.call(abi.encodeWithSelector(TRANSFER_FROM_SELECTOR,_from, _to, _amount));
    require(_success,"Transfering from _contract failed");
    requirdLiquidity = requirdLiquidity.add(_amount);
    _;
  }

  // check the signature of allowance of investing which is granted by the superadmin.
  modifier _mustBeAllowedToInvest(uint256 _amount, address _from, bytes memory _signature) {
    require(status == Status.active, "Basket is not active yet");
    require(totalQueuedFunds.add(totalLockedFunds).add(_amount).sub(totalWithdrawRequests) <= maximumFund,"the Basket is full");
    require(block.timestamp < endTime,"investing time is ended");
    bytes32 SigHash0 = keccak256(abi.encodePacked(SIGPREFIX,invest_signatureData(_from,_amount,block.timestamp/signatureExpiration)));
    // bytes32 SigHash1 = keccak256(abi.encodePacked(SIGPREFIX,invest_signatureData(_from,_amount,ptop-1)));
    require( 
      Sig.recoverSigner(SigHash0,_signature) == adminAssistant,
      // Sig.recoverSigner(SigHash0,_signature) == adminAssistant ||
      // Sig.recoverSigner(SigHash1,_signature) == adminAssistant,
      "Invalid signature");
    _;
  }
  
  modifier _ownerFundTransfered() {
    require(_mybalance(baseToken)>= traderFund,"the Trader Funds is not transfered yet");
    _;
  }

  modifier _profitShareCheck() {
    require( (iteration > 0) || (iteration == 0 && totalQueuedFunds >= minFund),"funds is less than minFund");
    require( block.timestamp > startTime,"start time is not passed");
    _;
  }

  modifier _unlockFundRequestAllowed(uint256 _amount,address _account) {
    if (_account == trader) {
      // TODO TO be covered by unit tests
      require(_lockedFunds.get(_account).sub(_amount) >= traderFund,"you are not allowed to withdraw the funds");
    }
    _;
  }

}