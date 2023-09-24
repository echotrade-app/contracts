// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./SafeMath.sol";
import "./IterableMapping.sol";
import "./SuperAdmin.sol";


contract ICO is SuperAdmin {
    using SafeMath for uint256;
    using IterableMapping for IterableMapping.Map;

    struct Price {
        uint256 amount;
        uint256 volume;
        uint256 comStartVol;
    }

    /**
        * @dev Represents the token that is sold during the ICO (Initial Coin Offering).
        */
    address public token;

    /**
        * @dev Represents the list of base tokens that are accepted for purchasing the `token` during the sale.
        */
    address[] public baseTokens;
    mapping(address => bool) private _mapedBaseTokens;

    uint256 public startTime;
    uint256 public endTime;
    
    /**
        * @dev Represents the prices of ECTA tokens.
        */
    Price[] public prices;

    /**
        * @dev Represents the total amount of ECTA tokens that have been sold out.
        */
    uint256 public filledAmount;
    
    /**
        * @dev Represents the minimum allowed amount of `token` required for a purchase.
        */
    uint256 public minAmount;

    /**
        * @dev Represents the decimal factor used in pricing calculations.
        */
    uint256 public decimal;
    

    bytes4 private _transferFromSelector = bytes4(keccak256("transferFrom(address,address,uint256)"));
    bytes4 private _transferSelector = bytes4(keccak256("transfer(address,uint256)"));
    bytes4 private _balanceOfSelector = bytes4(keccak256("balanceOf(address)"));

    /**
        * @dev The `_decimalFactor` variable is declared to handle small price adjustments.
        */
    uint256 private _decimalFactor;

    /**
        * @dev Emitted when an administrator or owner withdraws tokens.
        * @param _contract The address of the contract from which tokens are withdrawn.
        * @param _to The address to which tokens are transferred.
        * @param _amount The amount of tokens withdrawn.
        * @param _memo A string containing additional information or a memo for the withdrawal.
        */
    event Withdraw(address _contract,address _to, uint256 _amount,string _memo );

    /**
        * @dev Emitted when a user buys tokens.
        * @param buyer The address of the buyer.
        * @param _amount The amount of tokens bought.
        * @param _price The price at which the tokens were bought.
        */
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
            comVol = comVol + _prices[index].volume;
            prices.push(Price(_prices[index].amount,_prices[index].volume,comVol));
        }
        
        minAmount = _minAmount;
        decimal = _decimal;

        _decimalFactor = 10**decimal;

    }

    /**
        * @dev Modifier: Ensures that the specified `_amount` is transferred from `_contract` of `_from` address to `_to` address.
        * @param _contract The address of the contract from which the transfer should occur.
        * @param _amount The amount to be transferred.
        * @param _from The address from which the amount should be transferred.
        * @param _to The address to which the amount should be transferred.
        */
    modifier _mustBeTransferred(address _contract, uint256 _amount, address _from,address _to) {
        (bool _success, ) = _contract.call(abi.encodeWithSelector(_transferFromSelector,_from, _to, _amount));
        require(_success,"Transfering from _contract failed");
        _;
    }

    /**
        * @dev Modifier: Checks if this contract has sufficient tokens to cover the buy request for the specified `amount`.
        * @param amount The amount of tokens being bought and required for the transaction.
        */
    modifier _mustHaveSufficentFund(uint256 amount) {
        require(mybalance(token)>= amount);
        _;
    }

    /**
        * @dev Modifier: Performs verification of a request, including checks for start time, end time, and minimum amount.
        * @param amount The amount being verified in the request.
        */
    modifier _isValid(uint256 amount) {
        require(block.timestamp>= startTime,"ICO is not started yet");
        require(block.timestamp <= endTime,"ICO is ended");
        require(amount >= minAmount,"amount is less than minimum amount");
        _;
    }

    /**
        * @dev Modifier: Checks if the `_baseToken` is acceptable and if the `_price` is correct or has changed.
        * @param _baseToken The address of the base token being checked for acceptability.
        * @param _price The price being checked to ensure correctness or changes.
        */
    modifier _isAcceptable(address _baseToken,uint256 _price) {
        require(getActivePrice().amount == _price,"this price is not valid now, retry with the new price.");
        require(_mapedBaseTokens[_baseToken],"this token is not supported");
        _;
    }

    /**
        * @dev Allows the purchase of tokens using the specified `_baseToken`.
        * @param _baseToken The address of the base token used for the purchase.
        * @param amount The amount of tokens to purchase.
        * @param _price The price at which the tokens are bought.
        * @return A boolean indicating the success of the purchase.
        */
    function buy(address _baseToken,uint256 amount,uint256 _price) external _isAcceptable(_baseToken,_price) _isValid(amount) _mustHaveSufficentFund(amount) _mustBeTransferred(_baseToken,baseAmount(amount),msg.sender,address(this)) returns (bool) {
        require(amount > 0, "amount cannot be empty");
        emit Buy(msg.sender, amount, getActivePrice().amount);
        filledAmount += amount;
        return transfer(token, amount, msg.sender);
    }

    /**
        * @dev Allows the admin to withdraw tokens from the specified `_contract` and transfer them to `_to` with an optional `_memo`.
        * @param _contract The address of the contract from which tokens are withdrawn.
        * @param _to The address to which tokens are transferred.
        * @param _amount The amount of tokens to withdraw.
        * @param _memo An optional string providing additional information or a memo for the withdrawal.
        * @return A boolean indicating the success of the withdrawal.
        */
    function withdraw(address _contract, address _to, uint256 _amount,string memory _memo) external _onlySuperAdmin() returns (bool ) {
        emit Withdraw(_contract, _to, _amount, _memo);
        return transfer(_contract, _amount, _to);
    }

    /**
        * @dev Internal function to transfer a specified `amount` of tokens from the contract to the `_to` address.
        * @param _contract The address of the contract from which tokens are being transferred.
        * @param amount The amount of tokens to transfer.
        * @param _to The address to which tokens are transferred.
        * @return A boolean indicating the success of the token transfer.
        */
    function transfer(address _contract, uint256 amount, address _to) internal returns (bool) {
        (bool _success, ) = _contract.call(abi.encodeWithSelector(_transferSelector,_to,amount));
        require(_success,"transfering Token failed");
        return true;
    }

    // ─── Utils ───────────────────────────────────────────────────────────

    /**
        * @dev Internal function to retrieve the balance of the contract at the specified `_contract` address.
        * @param _contract The address of the contract for which the balance is retrieved.
        * @return The balance of the contract at the specified address.
        */
    function mybalance(address _contract) internal returns (uint256) {
        (bool _success,bytes memory _data ) = _contract.call(abi.encodeWithSelector(_balanceOfSelector,address(this)));
        require(_success,"fetching balance failed");
        return uint256(bytes32(_data));
    }

    /**
        * @dev Public function that returns the amount of the base token required to purchase a specified amount of ECTA.
        * @param amount The amount of ECTA tokens to be purchased.
        * @return The corresponding amount of the base token required for the purchase.
        */
    function baseAmount(uint256 amount) public view returns (uint256) {
        return SafeMath.div(amount*getActivePrice().amount, _decimalFactor);
    }

    /**
        * @dev Public function that returns the active price based on the filled amount and available prices.
        * @return The `Price` struct representing the active price.
        */
    function getActivePrice() public view returns (Price memory) {
        for (uint256 index = 0; index < prices.length; index++) {
            if (prices[index].comStartVol > filledAmount){
                return prices[index];
            }
        }
        return prices[prices.length-1];
    }


}