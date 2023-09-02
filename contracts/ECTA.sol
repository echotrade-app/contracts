// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./Token.sol";
import "./SafeMath.sol";
import "./IterableMapping.sol";
import "./Vesting.sol";
import "./IBasket.sol";
import "hardhat/console.sol";


contract ECTA is Token {
    using SafeMath for uint256;
    using IterableMapping for IterableMapping.Map;
   
    bytes4 private constant TRANSFER_FROM_SELECTOR = bytes4(keccak256("transferFrom(address,address,uint256)"));
    bytes4 private constant TRANSFER_SELECTOR = bytes4(keccak256("transfer(address,uint256)"));
    bytes4 private constant BALANCE_OF_SELECTOR = bytes4(keccak256("balanceOf(address)"));

    struct UnlockRequest {
        uint256 amount;
        uint256 releaseAt;
    }
    struct Investor {
        address _address;
        uint256 _share;
    }

    uint256 public minimumStakeValue;
    uint256 public lockDuration;

    IterableMapping.Map private stakedBalances;

    uint256 public totalStaked;

    mapping (address => UnlockRequest[] ) private _requests;
    mapping (address => uint256) public locked;

    mapping (address => mapping (address => uint256)) private _profits;

    // total locked funds from diffrents contracts.
    // address is the contract address
    // uint256 is the total Commitment to pay amount
    mapping (address => uint256) private _lockedFunds;
    
    IBasket[] public baskets;
    
    constructor(
        uint256 startReleaseAt,
        uint releaseDuration,
        Investor[] memory _investors,
        address _company,
        address _treasury,
        address _team,
        address _liquidity,
        address _capital
        ) Token("ECTA","ECTA",6) {
        
        uint256 decimalFactor = 10**6;
        uint256 __totalSupply = 100_000_000*decimalFactor;
        uint256 _InvSum;
        minimumStakeValue = 100_000*decimalFactor;
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

    // ─── Modifiers ───────────────────────────────────────────────────────
    // TODO TO be covered by unit tests
    modifier mustBeTransferred(address _contract, uint256 _amount, address _from,address _to) {
        (bool _success, ) = _contract.call(abi.encodeWithSelector(TRANSFER_FROM_SELECTOR,_from, _to, _amount));
        require(_success,"Transfering from _contract failed");
        _;
    }

    modifier haveSufficientFund(address _contract, uint256 _amount) {
        // require to not LocledAssets + Amount >= BalanceOf(this) at that contract
        require(_lockedFunds[_contract].add(_amount) <= mybalance(_contract),"Insufficient funds for sharing this amount");
        _;
    }
    
    modifier haveSufficientWithdrawProfit(address _contract, address _to) {
        require(_profits[_to][_contract] > 0,"No withdrawable profit");
        _;
    }

    // TODO TO be covered by unit tests
    modifier unstakable(address account, uint256 amount) {
        uint256 reminding = stakedBalances.get(account).sub(_getTotalUnlockRequests(account)).sub(amount);
        require(reminding == 0 || reminding >= minimumStakeValue,"Iinvalid unstake value");
        _;
    }

    modifier stakable(address account, uint256 amount) {
        require(stakedBalances.get(account).add(amount) >= minimumStakeValue,"Invalid stake value");
        _;
    }

    modifier isAvailable(address account, uint256 amount) {
        require( _balances[account] >= amount + locked[account],"Insufficient balance");
        _;
        
    }

    // ─── Staking ─────────────────────────────────────────────────────────

    function stake(uint256 amount) external returns (bool) {
        return _stake(msg.sender, amount);
    }

    function _stake(address account, uint256 amount) internal stakable(account, amount) returns (bool) {
        stakedBalances.set(account, stakedBalances.get(account) + amount);
        locked[account] = locked[account] + amount;
        totalStaked += amount;
        return true;
    }

    // TODO TO be covered by unit tests
    function unstake(uint256 amount) external returns (bool) {
        return _stake(msg.sender, amount);
    }

    // TODO TO be covered by unit tests
    function _unstake(address account, uint256 amount) internal unstakable(account, amount) returns (bool) {
        uint256 newStakedBalance = stakedBalances.get(account).sub(amount);
        if (newStakedBalance == 0) {
            stakedBalances.remove(account);
        } else {
            stakedBalances.set(account, newStakedBalance);
        }
        _requests[account].push(UnlockRequest(amount, block.timestamp + lockDuration));
        totalStaked -= amount;
        return true;
    }

    // TODO TO be covered by unit tests
    function widthrawReleased(address account) public returns (bool) {
        require(_requests[account].length > 0, "No request to withdraw staked");
        require(_requests[account][0].releaseAt <= block.timestamp, "Funds are not released yet");
        uint256 sum;
        while (_requests[account].length > 0 && _requests[account][0].releaseAt <= block.timestamp) {
            sum += _requests[account][0].amount;
            _shiftRequests(account, 0);
        }
        locked[account] -= sum;
        return true;
    }

    // TODO TO be covered by unit tests
    function widthrawReleased() public returns (bool) {
        return widthrawReleased(msg.sender);
    }

    // TODO TO be covered by unit tests
    function _shiftRequests(address account, uint256 index) private {
        require(index < _requests[account].length, "Index out of bounds");

        for (uint256 i = index; i < _requests[account].length - 1; i++) {
            _requests[account][i] = _requests[account][i + 1];
        }
        _requests[account].pop();
    }

    // TODO TO be covered by unit tests
    function _getTotalUnlockRequests(address account) internal view returns (uint256 sum) {
        for (uint256 i = 0; i < _requests[account].length; i++) {
            sum += _requests[account][i].amount;
        }
        return sum;
    }

    function getTotalUnlockedRequests(address account) external view returns (uint256 sum) {
        return _getTotalUnlockRequests(account);
    }

    // ─── Widthraw Profit ─────────────────────────────────────────────────
    
    function withdrawProfit(address _contract) public haveSufficientWithdrawProfit(_contract,msg.sender) returns (bool) {
        return _withrawProfit(_contract,msg.sender);
    }

    // TODO TO be covered by unit tests
    function withdrawProfit(address _contract,address _to) public haveSufficientWithdrawProfit(_contract,_to) returns (bool) {
        return _withrawProfit(_contract,_to);
    }
    
    function _withrawProfit(address _contract, address _to) internal returns (bool) {
        (bool _success,) = _contract.call(abi.encodeWithSelector(TRANSFER_SELECTOR,_to, _profits[_to][_contract]));
        require(_success,"Transfering token fials");
        _lockedFunds[_contract] = _lockedFunds[_contract].sub(_profits[_to][_contract]);
        _profits[_to][_contract] = 0;
        return true;
    }

    function withdrawableProfit(address _account, address _contract ) public view returns (uint256) {
        return _profits[_account][_contract];
    }

    // TODO TO be covered by unit tests
    function lockedFunds(address _contract) public view returns (uint256) {
        return _lockedFunds[_contract];
    }
    
    // ─── Basket Managment ────────────────────────────────────────────────

    function addBasket(address _basket) external _onlySuperAdmin() returns (bool) {
        IBasket basket = IBasket(_basket);
        require(basket.admin() == address(this),"Invalid Basket Admin");

        baskets.push(basket);
        return true;
    }

    function removeBasket(uint index) external returns (bool) {
        require(baskets[index].status() == Status.closed,"Basket must be closed");
        bool success = _gatherProfits(index);
        require(success,"gathering profits failed");

        // shift baskets
        require(index < baskets.length, "Index out of bounds");

        for (uint256 i = index; i < baskets.length - 1; i++) {
            baskets[i] = baskets[i + 1];
        }
        baskets.pop();
        return false;
    }

    function gatherProfits(uint[] memory indexes) external returns (bool) {
        return _gatherProfits(indexes);
    }

    function _gatherProfits(uint index) internal returns (bool) {
        address baseToken = baskets[index].baseToken();
        uint256 amount = baskets[index].adminShareProfit();
        return profitShareBalance(baseToken, amount);
    }

    function _gatherProfits(uint[] memory indexs) internal returns (bool) {
        require(indexs.length > 0 , "at least one basket is required");
        address baseToken = baskets[indexs[0]].baseToken();
        uint256 amount = baskets[indexs[0]].adminShareProfit();

        // fetch basekt base token,
        // fetch admin share,
        for (uint256 index = 1; index < indexs.length; index++) {
            // TODO TO be covered by unit tests
            require(baseToken == baskets[index].baseToken(),"required uniformed baseTokens");
            amount += baskets[index].adminShareProfit();
        }
        console.log("gathered",amount,"as profit","");
        return profitShareBalance(baseToken, amount);
        // share alongs with the stackers
    }




    // ─── Profit Sharing ──────────────────────────────────────────────────

    function profitShareBalance(address _contract, uint256 _amount) public haveSufficientFund(_contract,_amount) returns (bool) {
        return _profitShare(_contract, _amount);
    }

    /**
        * @dev profitShare(address, amount) 
        * sender is already approved the amount in the _contract address 
        */
    // TODO TO be covered by unit tests
    function profitShareApproved(address payable _contract, uint256 _amount) public mustBeTransferred(_contract,_amount,msg.sender,address(this)) returns (bool) {
        return _profitShare(_contract,_amount);
    }
    
    // TODO TO be covered by unit tests
    function profitShareApproved(address payable _contract, uint256 _amount, address _from) public mustBeTransferred(_contract,_amount,_from,address(this)) returns (bool) {
        return _profitShare(_contract,_amount);
    }

    function _profitShare(address _contract, uint256 _amount) internal returns (bool) {
        _lockedFunds[_contract] = _lockedFunds[_contract].add(_amount);
        for (uint i = 0; i < stakedBalances.size(); ++i) {
            address key = stakedBalances.getKeyAtIndex(i);
            _profits[key][_contract] = _profits[key][_contract].add(SafeMath.div(SafeMath.mul(stakedBalances.get(key),_amount), totalStaked));
        }
        return true;
    }

    // ─── Utils ───────────────────────────────────────────────────────────

    function mybalance(address _contract) internal returns (uint256) {
        (bool _success,bytes memory _data ) = _contract.call(abi.encodeWithSelector(BALANCE_OF_SELECTOR,address(this)));
        require(_success,"Fetching balance failed");
        return uint256(bytes32(_data));
    }
    
    function _transfer(address sender, address recipient, uint256 amount) internal isAvailable(sender,amount) override {
        Token._transfer(sender, recipient, amount);
    }

}   