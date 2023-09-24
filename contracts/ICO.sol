// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./IBEP20.sol";
import "./SafeMath.sol";
import "./IterableMapping.sol";
import "./SuperAdmin.sol";
import "./Vesting.sol";
import "./Token.sol";


contract ICO is SuperAdmin {
    using SafeMath for uint256;
    using IterableMapping for IterableMapping.Map;

    struct Price {
        uint256 amount;
        uint256 volume;
        uint256 comStartVol;
    }


    // Token is the token sell in ICO
    address public token;

    // baseTokens is the list of base tokens which we accept for seling the `token`.
    address[] public baseTokens;
    mapping(address => bool) private _mapedBaseTokens;

    uint256 public startTime;
    uint256 public endTime;
    
    // prices of ECTA
    Price[] public prices;

    // the total amount of ECTA which is soldout.
    uint256 public filledAmount;
    
    // minium allowed amount of `token` to buy.
    uint256 public minAmount;

    // decimal is the decimal factor of price.
    uint256 public decimal;
    
    IterableMapping.Map internal _balances;

    bytes4 private _transferFromSelector = bytes4(keccak256("transferFrom(address,address,uint256)"));
    bytes4 private _transferSelector = bytes4(keccak256("transfer(address,uint256)"));
    bytes4 private _balanceOfSelector = bytes4(keccak256("balanceOf(address)"));
    uint256 private _decimalFactor;

    event Withdraw(address _contract,address _to, uint256 _amount,string _memo );
    event NextPrice(Price _price);
    event Buy(address buyer, uint256 _amount, uint256 _price);

    constructor(
        address _token,
        address[] memory _baseToken,
        uint256 _startTime,
        uint256 _endTime,
        Price[] memory _prices,
        uint256 _minAmount,
        uint256 _decimal
        ) {
        token = _token;

        for (uint256 index = 0; index < _baseToken.length; index++) {
            baseTokens.push(_baseToken[index]);
            _mapedBaseTokens[_baseToken[index]]=true;
        }
        startTime = _startTime;
        endTime = _endTime;

        uint256 comVol;
        for (uint256 index = 0; index < _prices.length; index++) {
            prices.push(Price(_prices[index].amount,_prices[index].volume,comVol));
            comVol = comVol + _prices[index].volume;
        }
        
        minAmount = _minAmount;
        decimal = _decimal;

        _decimalFactor = 10**decimal;

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

    modifier _isAcceptable(address _baseToken) {
        require(_mapedBaseTokens[_baseToken],"this token is not supported");
        _;
    }

    function buy(address _baseToken,uint256 amount) external _isAcceptable(_baseToken) _isValid(amount) _mustHaveSufficentFund(amount) _mustBeTransferred(_baseToken,baseAmount(amount),msg.sender,address(this)) returns (bool success ) {
        require(amount > 0, "amount cannot be empty");
        emit Buy(msg.sender, amount, (baseAmount(amount)*_decimalFactor)/amount);
        filledAmount += amount;
        return transfer(token, amount, msg.sender);
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
        return SafeMath.div(amount*getActivePrice().amount, _decimalFactor);
    }

    function getActivePrice() public view returns (Price memory price) {
        for (uint256 index = 0; index < prices.length; index++) {
            if (prices[index].comStartVol <= filledAmount){
                return prices[index];
            }
        }
        return prices[prices.length-1];
    }


}