// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./Token.sol";
import "./SafeMath.sol";
import "./IterableMapping.sol";
import "./Vesting.sol";
import "./IBasket.sol";

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
    uint256 public lockDuration = 14 days;

    IterableMapping.Map private stakedBalances;

    uint256 public totalStaked;

    /**
        * @dev Private mapping that stores unlock or unstaked requests for each address.
        * @dev The address key represents the account address, and the UnlockRequest[] value contains the requests.
        */
    mapping (address => UnlockRequest[] ) private _requests;

    // TODO : speicify exactly what is the locked?
    mapping (address => uint256) public locked;
    
    /**
        * @dev Private mapping from accounts to contract addresses and the corresponding amount of profit for each contract.
        */
    mapping (address => mapping (address => uint256)) private _profits;

    /**
        * @dev Private mapping that tracks the total locked funds from different contracts.
        * @dev The address key represents the contract address, and the uint256 value represents the total commitment-to-pay amount.
        */
    mapping (address => uint256) private _lockedFunds;
    
    /**
        * @dev Public array representing the list of Baskets within the ECTA.
        */
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

    /**
        * @dev Ensures that the specified `_amount` is transferred from `_contract` of `_from` address to `_to` address.
        * @param _contract The address of the contract from which the transfer should occur.
        * @param _amount The amount to be transferred.
        * @param _from The address from which the amount should be transferred.
        * @param _to The address to which the amount should be transferred.
        */
    // TODO TO be covered by unit tests
    modifier mustBeTransferred(address _contract, uint256 _amount, address _from,address _to) {
        (bool _success, ) = _contract.call(abi.encodeWithSelector(TRANSFER_FROM_SELECTOR,_from, _to, _amount));
        require(_success,"Transfering from _contract failed");
        _;
    }

    /**
        * @dev Modifier: Checks that the contract has sufficient funds to cover the specified `_amount`. Used in profit-sharing functions.
        * @param _contract The address of the contract to check for sufficient funds.
        * @param _amount The amount to verify against available funds.
        * @notice Requires that `LockedAssets + _amount` is not greater than or equal to the balance of this contract.
        */
    modifier haveSufficientFund(address _contract, uint256 _amount) {
        // require to not LocledAssets + Amount >= BalanceOf(this) at that contract
        require(_lockedFunds[_contract].add(_amount) <= myBalance(_contract),"Insufficient funds for sharing this amount");
        _;
    }
    
    /**
        * @dev Modifier: Checks that the specified `_account` has sufficient funds to cover the specified profit withdrawal.
        * @param _contract The address of the contract from which profit is being withdrawn.
        * @param _account The address of the account to check for sufficient funds.
        */
    modifier haveSufficientWithdrawProfit(address _contract, address _account) {
        require(_profits[_account][_contract] > 0,"No withdrawable profit");
        _;
    }

    /**
        * @dev Modifier: Checks if the specified `amount` is unstakable, ensuring that the remaining amount is either zero or greater than the minimumStakeValue.
        * @param account The address of the account making the staking operation.
        * @param amount The amount to stake, to be checked for unstakability.
        */
    // TODO TO be covered by unit tests
    modifier unstakable(address account, uint256 amount) {
        uint256 reminding = stakedBalances.get(account).sub(_getTotalUnlockRequests(account)).sub(amount);
        require(reminding == 0 || reminding >= minimumStakeValue,"Iinvalid unstake value");
        _;
    }

    /**
        * @dev Modifier: Checks if the specified `amount` is stakable, ensuring that the cumulative amount is greater than or equal to the minimumStakeValue.
        * @param account The address of the account making the staking operation.
        * @param amount The amount to stake, to be checked for stackability.
        */
    modifier stakable(address account, uint256 amount) {
        require(stakedBalances.get(account).add(amount) >= minimumStakeValue,"Invalid stake value");
        _;
    }

    /**
        * @dev Checks if the specified `amount` is available for transferring.
        * @param account The address of the account from which the transfer or burn is initiated.
        * @param amount The amount to check for availability.
        */
    modifier isAvailable(address account, uint256 amount) {
        require( _balances[account] >= amount + locked[account],"Insufficient balance");
        _;
    }

    // ─── Staking ─────────────────────────────────────────────────────────

    /**
        * @dev External function to stake a specified `amount`. Staking locks the amount to receive rewards and a share from the platform, traders, and investors.
        * @param amount The amount to stake.
        * @return A boolean indicating the success of the staking operation.
        */
    function stake(uint256 amount) external returns (bool) {
        return _stake(msg.sender, amount);
    }

    /**
        * @dev Internal function to stake a specified `amount` for the `account`. Staking locks the amount to receive rewards and a share from the platform.
        * @param account The address of the account staking the amount.
        * @param amount The amount to stake.
        * @return A boolean indicating the success of the staking operation.
        */
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

    /**
        * @dev Internal function that returns the total amount of unlocked requests for the specified `account`.
        * @param account The address of the account to query unlock requests for.
        * @return The total amount of unlocked requests for the account.
        */
    // TODO TO be covered by unit tests
    function _getTotalUnlockRequests(address account) internal view returns (uint256) {
        uint256 sum;
        for (uint256 i = 0; i < _requests[account].length; i++) {
            sum += _requests[account][i].amount;
        }
        return sum;
    }

    /**
        * @dev External function that returns the total number of unlocked requests for a specified `account`'s staked amount.
        * @param account The address of the account to query unlock requests for.
        * @return The total number of unlocked requests for the staked amount.
        */
    function getTotalUnlockedRequests(address account) external view returns (uint256) {
        return _getTotalUnlockRequests(account);
    }

    // ─── Widthraw Profit ─────────────────────────────────────────────────
    
    /**
        * @dev Allows the `msg.sender` to withdraw their profit from the specified `_contract`.
        * @param _contract The address of the contract from which profit is being withdrawn.
        * @return A boolean indicating the success of the profit withdrawal.
        */
    function withdrawProfit(address _contract) public haveSufficientWithdrawProfit(_contract,msg.sender) returns (bool) {
        return _withrawProfit(_contract,msg.sender);
    }

    /**
        * @dev Allows the `_to` address to withdraw profit from the specified `_contract`. The profit is transferred to the `_to` address, not msg.sender.
        * @param _contract The address of the contract from which profit is being withdrawn.
        * @param _to The address to which the profit is transferred.
        * @return A boolean indicating the success of the profit withdrawal.
        */
    // TODO TO be covered by unit tests
    function withdrawProfit(address _contract,address _to) public haveSufficientWithdrawProfit(_contract,_to) returns (bool) {
        return _withrawProfit(_contract,_to);
    }
    
    /**
        * @dev Internal function for withdrawing profit of the `_to` address. The profit is transferred to the `_to` address, not msg.sender.
        * @param _contract The address of the contract from which profit is being withdrawn.
        * @param _to The address to which the profit is transferred.
        * @return A boolean indicating the success of the profit withdrawal.
        */
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

    /**
        * @dev Adds the Basket to the ECTA once it has been created. Only accessible by super admins. Requires that the Basket Admin address is equal to this contract's address.
        * @param _basket The address of the Basket to add.
        * @return A boolean indicating the success of the addition operation.
        */ 
    function addBasket(address _basket) external _onlySuperAdmin() returns (bool) {
        IBasket basket = IBasket(_basket);
        require(basket.admin() == address(this),"Invalid Basket Admin");

        baskets.push(basket);
        return true;
    }

    /**
        * @dev Removes the Basket at the specified index from the list once it has been closed.
        * @param index The index of the Basket to remove.
        * @return A boolean indicating the success of the removal operation.
        */
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

    /**
        * @dev Sets the assistant for the superadmin in the Basket at the specified index and calls the set assistant function of the Basket.
        * @param index The index of the Basket.
        * @param _assistant The address of the assistant to set.
        * @return A boolean indicating the success of the operation.
        */
    function setAssitant(uint index,address _assistant) external _onlySuperAdmin() returns (bool) {
        // TODO
        // call the set assitant function of the Basket
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

    /**
        * @dev Public function for sharing profits from a transferred amount with the stakers after ensuring that the fund has already been transferred.
        * @param _contract The address of the contract with the transferred funds.
        * @param _amount The transferred amount to share as profit.
        * @return A boolean indicating the success of the profit-sharing operation.
        */
    function profitShareBalance(address _contract, uint256 _amount) public haveSufficientFund(_contract,_amount) returns (bool) {
        return _profitShare(_contract, _amount);
    }

    /**
        * @dev Public function for sharing approved profits from `_contract` to this contract and then distributing them to stakers based on their share.
        * @param _contract The address of the contract with approved profit.
        * @param _amount The approved amount to be transferred and shared.
        * @return A boolean indicating the success of the profit-sharing operation.
        */
    // TODO TO be covered by unit tests
    function profitShareApproved(address payable _contract, uint256 _amount) public mustBeTransferred(_contract,_amount,msg.sender,address(this)) returns (bool) {
        return _profitShare(_contract,_amount);
    }
    
    /**
        * @dev Transfers the approved `_amount` from `_contract` to this contract and then shares the profit.
        * @param _contract The address of the contract with approved profit.
        * @param _amount The approved amount to be transferred and shared.
        * @param _from The address initiating the profit share.
        * @return A boolean indicating the success of the profit-sharing operation.
        */
    // TODO TO be covered by unit tests
    function profitShareApproved(address payable _contract, uint256 _amount, address _from) public mustBeTransferred(_contract,_amount,_from,address(this)) returns (bool) {
        return _profitShare(_contract,_amount);
    }

    /**
        * @dev Internal function for sharing profits gained with stakers based on their share. The reward will be withdrawable.
        * @param _contract The address of the contract where the profit was gained.
        * @param _amount The amount of profit to share.
        * @return A boolean indicating the success of the profit-sharing operation.
        */   
    function _profitShare(address _contract, uint256 _amount) internal returns (bool) {
        _lockedFunds[_contract] = _lockedFunds[_contract].add(_amount);
        for (uint i = 0; i < stakedBalances.size(); ++i) {
            address key = stakedBalances.getKeyAtIndex(i);
            _profits[key][_contract] = _profits[key][_contract].add(SafeMath.div(SafeMath.mul(stakedBalances.get(key),_amount), totalStaked));
        }
        return true;
    }

    /**
        * @dev This function, burn(uint256 amount), is designed for potential future migration. It destroys `amount` tokens from the calling account, and the same `amount` is deducted from the total supply.
        * @param amount The amount of tokens to be burned.
        */
    function burn(uint256 amount) external onlyReleased(msg.sender,_balances[msg.sender].sub(amount)) isAvailable(msg.sender,amount) {
        _burn(msg.sender, amount);
    }

    /**
        * @dev This function, burnFrom(address account, uint256 amount), is designed for potential future migration and should not be used in the current context. It destroys `amount` tokens from the calling account, and the same `amount` is deducted from the total supply.
        * @param account The address from which tokens are to be burned.
        * @param amount The amount of tokens to be burned.
        */
    function burnFrom(address account,uint256 amount) external onlyReleased(account,_balances[account].sub(amount)) isAvailable(account,amount) {
        _burnFrom(account, amount);
    }

    // ─── Utils ───────────────────────────────────────────────────────────

    /**
        * @dev Returns the ECTA balance of the specified contract.
        * @param _contract The address of the contract to query.
        * @return The ECTA balance of the contract.
        */
    function myBalance(address _contract) internal returns (uint256) {
        (bool _success,bytes memory _data ) = _contract.call(abi.encodeWithSelector(BALANCE_OF_SELECTOR,address(this)));
        require(_success,"Fetching balance failed");
        return uint256(bytes32(_data));
    }
    
    /**
        * @dev Overrides the token transfer function to prevent transfers of staked amounts.
        * @param sender The address initiating the transfer.
        * @param recipient The address receiving the tokens.
        * @param amount The amount of tokens to transfer.
        */
    function _transfer(address sender, address recipient, uint256 amount) internal isAvailable(sender,amount) override {
        Token._transfer(sender, recipient, amount);
    }

}   