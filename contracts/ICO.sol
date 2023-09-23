// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./IBEP20.sol";
import "./Basket.sol";
import "./SafeMath.sol";
import "./IterableMapping.sol";
import "./SuperAdmin.sol";
import "./Vesting.sol";
import "./Token.sol";


contract ICO is SuperAdmin {
    using SafeMath for uint256;
    using IterableMapping for IterableMapping.Map;

    address public token;
    address public baseToken;
    uint256 public startTime;
    uint256 public endTime;
    uint256 public price;
    uint256 public minAmount;
    uint256 public decimal;
    
    IterableMapping.Map internal _balances;

    bytes4 private _transferFromSelector;
    bytes4 private _transferSelector;
    bytes4 private _balanceOfSelector;
    uint256 private _decimalFactor;

    event Withdraw(address _contract,address _to, uint256 _amount,string _memo );
    event SetPrice(uint256 _newPrice);
    event Buy(address buyer, uint256 _amount, uint256 _price);
    constructor(
        address _token,
        address _baseToken,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _price,
        uint256 _minAmount,
        uint256 _decimal
        ) {
        token = _token;
        baseToken = _baseToken;
        startTime = _startTime;
        endTime = _endTime;
        price = _price;
        minAmount = _minAmount;
        decimal = _decimal;
        _decimalFactor = 10**decimal;

        _transferFromSelector = bytes4(keccak256("transferFrom(address,address,uint256)"));
        _transferSelector = bytes4(keccak256("transfer(address,uint256)"));
        _balanceOfSelector = bytes4(keccak256("balanceOf(address)"));

    }

    modifier _mustBeTransferred(address _contract, uint256 _amount, address _from,address _to) {
        (bool _success, ) = _contract.call(abi.encodeWithSelector(_transferFromSelector,_from, _to, _amount));
        require(_success,"Transfering from _contract failed");
        _;
    }

    modifier _mustHaveSufficentFund(uint256 amount) {
        require(mybalance(token)>= amount);
        _;
    }
    modifier _isValid(uint256 amount) {
        require(block.timestamp>= startTime,"ICO is not started yet");
        require(block.timestamp <= endTime,"ICO is ended");
        require(amount >= minAmount,"amount is less than minimum amount");
        _;
    }

    function buy(uint256 amount) external _isValid(amount) _mustHaveSufficentFund(amount) _mustBeTransferred(baseToken,baseAmount(amount),msg.sender,address(this)) returns (bool success ) {
        emit Buy(msg.sender, amount, price);
        return transfer(token, amount, msg.sender);
    }

    function setPrice(uint256 _price) external _onlySuperAdmin() returns (bool success) {
        price = _price;
        emit SetPrice(_price);
        return true;
    }

    function withdraw(address _contract, address _to, uint256 _amount,string memory _memo) external _onlySuperAdmin() returns (bool success) {
        emit Withdraw(_contract, _to, _amount, _memo);
        return transfer(_contract, _amount, _to);
    }

    function transfer(address _contract, uint256 amount, address _to) internal returns (bool) {
        (bool _success, ) = _contract.call(abi.encodeWithSelector(_transferSelector,_to,amount));
        require(_success,"transfering Token failed");
        return true;
    }

    // ─── Utils ───────────────────────────────────────────────────────────
    function mybalance(address _contract) internal returns (uint256) {
        (bool _success,bytes memory _data ) = _contract.call(abi.encodeWithSelector(_balanceOfSelector,address(this)));
        require(_success,"fetching balance failed");
        return uint256(bytes32(_data));
    }

    function baseAmount(uint256 amount) public view returns (uint256) {
        return SafeMath.div(amount*price, _decimalFactor);
    }


}