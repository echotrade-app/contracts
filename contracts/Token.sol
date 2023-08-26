// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./ITRC20.sol";
import "./Basket.sol";
import "./SafeMath.sol";
import "./IterableMapping.sol";
import "./SuperAdmin.sol";

contract Token is ITRC20,SuperAdmin {
  using SafeMath for uint256;
  using IterableMapping for IterableMapping.Map;
  
  string private _name;
  string private _symbol;
  uint8 private _decimals;


  bytes4 private _transferFromSelector;
  bytes4 private _transferSelector;
  bytes4 private _balanceOfSelector;

  Basket[] public _baskets;

  // Proposal.Surrogate public _proposal; 

  IterableMapping.Map private _balances;

  mapping (address => mapping (address => uint256)) private _allowances;

  /** @dev used for profit sharing
    */
  mapping (address => mapping (address => uint256)) private _profits;

  mapping (address => uint256) private _lockedFunds;

  uint256 private _totalSupply;
  
  constructor(string memory name, string memory symbol, uint8 decimals,uint256 hi) SuperAdmin(hi) payable {
    
    _name = name;
    _symbol = symbol;
    _decimals = decimals;

    _transferFromSelector = bytes4(keccak256("transferFrom(address,address,uint256)"));
    _transferSelector = bytes4(keccak256("transfer(address,uint256)"));
    _balanceOfSelector = bytes4(keccak256("balanceOf(address)"));
    
    

    _mint(msg.sender, 1000*10**_decimals);
    _mint(msg.sender, 1000*10**_decimals);
  }

  // ─── Details ─────────────────────────────────────────────────────────

  /**
    * @dev Returns the name of the token.
    */
  function name() public view returns (string memory) {
    return _name;
  }

  /**
    * @dev Returns the symbol of the token, usually a shorter version of the
    * name.
    */
  function symbol() public view returns (string memory) {
    return _symbol;
  }

  /**
    * @dev Returns the number of decimals used to get its user representation.
    * For example, if `decimals` equals `2`, a balance of `505` tokens should
    * be displayed to a user as `5,05` (`505 / 10 ** 2`).
    */
  function decimals() public view returns (uint8) {
    return _decimals;
  }

  // ─── TRC20 ───────────────────────────────────────────────────────────

  /**
    * @dev See {ITRC20-totalSupply}.
    */
  function totalSupply() public view returns (uint256) {
    return _totalSupply;
  }

  /**
    * @dev See {ITRC20-balanceOf}.
    */
  function balanceOf(address account) external view returns (uint256) {
    return IterableMapping.get(_balances, account);
  }

  /**
    * @dev See {ITRC20-transfer}.
    *
    * Requirements:
    *
    * - `recipient` cannot be the zero address.
    * - the caller must have a balance of at least `amount`.
    */
  function transfer(address recipient, uint256 amount) public returns (bool) {
      _transfer(msg.sender, recipient, amount);
      return true;
  }

  /**
    * @dev See {ITRC20-allowance}.
    */
  function allowance(address owner, address spender) public view returns (uint256) {
      return _allowances[owner][spender];
  }

  /**
    * @dev See {ITRC20-approve}.
    *
    * Requirements:
    *
    * - `spender` cannot be the zero address.
    */
  function approve(address spender, uint256 value) public returns (bool) {
      _approve(msg.sender, spender, value);
      return true;
  }

  /**
    * @dev See {ITRC20-transferFrom}.
    *
    * Emits an {Approval} event indicating the updated allowance. This is not
    * required by the EIP. See the note at the beginning of {TRC20};
    *
    * Requirements:
    * - `sender` and `recipient` cannot be the zero address.
    * - `sender` must have a balance of at least `value`.
    * - the caller must have allowance for `sender`'s tokens of at least
    * `amount`.
    */
  function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
      _transfer(sender, recipient, amount);
      _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount));
      return true;
  }

  /**
    * @dev Atomically increases the allowance granted to `spender` by the caller.
    *
    * This is an alternative to {approve} that can be used as a mitigation for
    * problems described in {ITRC20-approve}.
    *
    * Emits an {Approval} event indicating the updated allowance.
    *
    * Requirements:
    *
    * - `spender` cannot be the zero address.
    */
  function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
      _approve(msg.sender, spender, _allowances[msg.sender][spender].add(addedValue));
      return true;
  }

  /**
    * @dev Atomically decreases the allowance granted to `spender` by the caller.
    *
    * This is an alternative to {approve} that can be used as a mitigation for
    * problems described in {ITRC20-approve}.
    *
    * Emits an {Approval} event indicating the updated allowance.
    *
    * Requirements:
    *
    * - `spender` cannot be the zero address.
    * - `spender` must have allowance for the caller of at least
    * `subtractedValue`.
    */
  function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
      _approve(msg.sender, spender, _allowances[msg.sender][spender].sub(subtractedValue));
      return true;
  }

  /**
    * @dev Moves tokens `amount` from `sender` to `recipient`.
    *
    * This is internal function is equivalent to {transfer}, and can be used to
    * e.g. implement automatic token fees, slashing mechanisms, etc.
    *
    * Emits a {Transfer} event.
    *
    * Requirements:
    *
    * - `sender` cannot be the zero address.
    * - `recipient` cannot be the zero address.
    * - `sender` must have a balance of at least `amount`.
    */
  function _transfer(address sender, address recipient, uint256 amount) internal {
      require(sender != address(0), "TRC20: transfer from the zero address");
      require(recipient != address(0), "TRC20: transfer to the zero address");
      
      // _balances[sender] = _balances[sender].sub(amount);
      IterableMapping.set(_balances, sender, IterableMapping.get(_balances, sender).sub(amount));
      
      // _balances[recipient] = _balances[recipient].add(amount);
      IterableMapping.set(_balances, recipient, IterableMapping.get(_balances, recipient).add(amount));
      
      emit Transfer(sender, recipient, amount);
  }

  /** @dev Creates `amount` tokens and assigns them to `account`, increasing
    * the total supply.
    *
    * Emits a {Transfer} event with `from` set to the zero address.
    *
    * Requirements
    *
    * - `to` cannot be the zero address.
    */
  function _mint(address account, uint256 amount) internal {
      require(account != address(0), "TRC20: mint to the zero address");

      _totalSupply = _totalSupply.add(amount);

      // _balances[account] = _balances[account].add(amount);
      IterableMapping.set(_balances, account, IterableMapping.get(_balances, account).add(amount));
      
      emit Transfer(address(0), account, amount);
  }

  /**
    * @dev Destroys `amount` tokens from `account`, reducing the
    * total supply.
    *
    * Emits a {Transfer} event with `to` set to the zero address.
    *
    * Requirements
    *
    * - `account` cannot be the zero address.
    * - `account` must have at least `amount` tokens.
    */
  function _burn(address account, uint256 value) internal {
      require(account != address(0), "TRC20: burn from the zero address");

      _totalSupply = _totalSupply.sub(value);

      // _balances[account] = _balances[account].sub(value);
      IterableMapping.set(_balances, account, IterableMapping.get(_balances, account).sub(value));
      emit Transfer(account, address(0), value);
  }

  /**
    * @dev Sets `amount` as the allowance of `spender` over the `owner`s tokens.
    *
    * This is internal function is equivalent to `approve`, and can be used to
    * e.g. set automatic allowances for certain subsystems, etc.
    *
    * Emits an {Approval} event.
    *
    * Requirements:
    *
    * - `owner` cannot be the zero address.
    * - `spender` cannot be the zero address.
    */
  function _approve(address owner, address spender, uint256 value) internal {
      require(owner != address(0), "TRC20: approve from the zero address");
      require(spender != address(0), "TRC20: approve to the zero address");

      _allowances[owner][spender] = value;
      emit Approval(owner, spender, value);
  }

  /**
    * @dev Destoys `amount` tokens from `account`.`amount` is then deducted
    * from the caller's allowance.
    *
    * See {_burn} and {_approve}.
    */
  function _burnFrom(address account, uint256 amount) internal {
      _burn(account, amount);
      _approve(account, msg.sender, _allowances[account][msg.sender].sub(amount));
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
        address key = IterableMapping.getKeyAtIndex(_balances, i);
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

  // ─── Superadmin Functions ────────────────────────────────────────────

  

  // ─── Basket Functions ────────────────────────────────────────────────

  function createBasket(address _baseToken,uint256 _ownerFund) public returns (address) {
    // Basket basket = new Basket(msg.sender, address(this), _baseToken,_ownerFund);
    Basket basket;
    _baskets.push(basket);
    (bool _success, ) = _baseToken.call(abi.encodeWithSelector(_transferFromSelector,msg.sender, address(basket), _ownerFund));
    require(_success,"Transfering from _contract failed");
    return address(basket);
  }

  

  // ─── Utils ───────────────────────────────────────────────────────────

  function mybalance(address _contract) internal returns (uint256) {
    (bool _success,bytes memory _data ) = _contract.call(abi.encodeWithSelector(_balanceOfSelector,address(this)));
    require(_success,"Fetching balance failed");
    return uint256(bytes32(_data));
  }

  // ─── Modifiers ───────────────────────────────────────────────────────

  
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
  
}