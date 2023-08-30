// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./Token.sol";
import "./ITRC20.sol";
import "./Basket.sol";
import "./SafeMath.sol";
import "./IterableMapping.sol";
import "./SuperAdmin.sol";
import "./Vesting.sol";
contract ECTA is Token {
  using SafeMath for uint256;
  using IterableMapping for IterableMapping.Map;

  bytes4 private _transferFromSelector;
  bytes4 private _transferSelector;
  bytes4 private _balanceOfSelector;

  struct Investor {
    address _address;
    uint256 _share;
  }

  mapping (address => mapping (address => uint256)) private _profits;

  // total locked funds from diffrents contracts.
  // address is the contract address
  // uint256 is the total Commitment to pay amount
  mapping (address => uint256) private _lockedFunds;

  mapping (address => uint256) private _stakings;

  constructor(
    string memory name,
    string memory symbol,
    uint8 decimals,
    uint256 startReleaseAt,
    uint releaseDuration,
    Investor[] memory _investors,
    address _company,
    address _treasury,
    address _team,
    address _liquidity,
    address _capital
    ) Token(name,symbol,decimals) {

    _transferFromSelector = bytes4(keccak256("transferFrom(address,address,uint256)"));
    _transferSelector = bytes4(keccak256("transfer(address,uint256)"));
    _balanceOfSelector = bytes4(keccak256("balanceOf(address)"));
    uint256 decimalFactor = 10**decimals;
    uint256 __totalSupply = 100_000_000*decimalFactor;
    uint256 _InvSum;
    
    for (uint256 i = 0; i < _investors.length; i++) {
    Investor memory Inv = _investors[i];  
    _InvSum += Inv._share*decimalFactor;
    _mint(Inv._address, Inv._share*decimalFactor, startReleaseAt, releaseDuration);
    }
    require(_InvSum == 27_000_000*decimalFactor);
    _mint(_company, 18_000_000*decimalFactor,startReleaseAt,releaseDuration);
    _mint(_treasury, 18_000_000*decimalFactor,startReleaseAt,releaseDuration);
    _mint(_liquidity, 10_000_000*decimalFactor,startReleaseAt,releaseDuration);
    _mint(_team, 14_000_000*decimalFactor,startReleaseAt,releaseDuration);
    _mint(_capital, 13_000_000*decimalFactor);

    require(__totalSupply == totalSupply());
  }

  modifier _mustBeTransferred(address _contract, uint256 _amount, address _from,address _to) {
    (bool _success, ) = _contract.call(abi.encodeWithSelector(_transferFromSelector,_from, _to, _amount));
    require(_success,"Transfering from _contract failed");
    _;
  }

  modifier _haveSufficientFund(address _contract, uint256 _amount) {
    // require to not LocledAssets + Amount >= BalanceOf(this) at that contract
    require(_lockedFunds[_contract].add(_amount) <= mybalance(_contract),"Insufficient funds for sharing this amount");
    _;
  }
  
  modifier _haveSufficientWithdrawProfit(address _contract, address _to) {
    require(_profits[_to][_contract] > 0,"no withdrawable profit");
    _;
  }
  
  // ─── Profit Share ────────────────────────────────────────────────────

  function profitShareBalance(address _contract, uint256 _amount) public _haveSufficientFund(_contract,_amount) returns (bool) {
    return _profitShare(_contract, _amount);
  }

  /**
    * @dev profitShare(address, amount) 
    * sender is already approved the amount in the _contract address 
    */
  function profitShareApproved(address payable _contract, uint256 _amount) public _mustBeTransferred(_contract,_amount,msg.sender,address(this)) returns (bool) {
    return _profitShare(_contract,_amount);
  }
  
  function profitShareApproved(address payable _contract, uint256 _amount, address _from) public _mustBeTransferred(_contract,_amount,_from,address(this)) returns (bool) {
    return _profitShare(_contract,_amount);
  }

  function _profitShare(address _contract, uint256 _amount) internal returns (bool) {
    _lockedFunds[_contract] = _lockedFunds[_contract].add(_amount);
    for (uint i = 0; i < _balances.size(); ++i) {
        address key = _balances.getKeyAtIndex(i);
        _profits[key][_contract] = _profits[key][_contract].add(SafeMath.div(SafeMath.mul(_balances.get(key),_amount), _totalSupply));
    }
  }

  // ─── Withdraw ─────────────────────────────────────────────────────────

  function withdrawProfit(address _contract) public _haveSufficientWithdrawProfit(_contract,msg.sender) returns (bool) {
    return _withrawProfit(_contract,msg.sender);
  }

  function withdrawProfit(address _contract,address _to) public _haveSufficientWithdrawProfit(_contract,_to) returns (bool) {
    return _withrawProfit(_contract,_to);
  }
  
  function _withrawProfit(address _contract, address _to) internal returns (bool) {
    (bool _success,) = _contract.call(abi.encodeWithSelector(_transferSelector,_to, _profits[_to][_contract]));
    require(_success,"Transfering token fials");
    _lockedFunds[_contract] = _lockedFunds[_contract].sub(_profits[_to][_contract]);
    _profits[_to][_contract] = 0;
    return true;
  }

  function withdrawableProfit(address _account, address _contract ) public view returns (uint256) {
    return _profits[_account][_contract];
  }

  function lockedFunds(address _contract) public view returns (uint256) {
    return _lockedFunds[_contract];
  }

  // ─── Utils ───────────────────────────────────────────────────────────

  function mybalance(address _contract) internal returns (uint256) {
    (bool _success,bytes memory _data ) = _contract.call(abi.encodeWithSelector(_balanceOfSelector,address(this)));
    require(_success,"Fetching balance failed");
    return uint256(bytes32(_data));
  }

  // ─── Modifiers ───────────────────────────────────────────────────────

  

  
}