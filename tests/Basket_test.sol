// SPDX-License-Identifier: GPL-3.0
        
pragma solidity >=0.7.0 <0.9.0;

// disbale linter
// This import is automatically injected by Remix
import "remix_tests.sol"; 

// This import is required to use custom transaction context
// Although it may fail compilation in 'Solidity Compiler' plugin
// But it will work fine in 'Solidity Unit Testing' plugin
import "remix_accounts.sol";
import "hardhat/console.sol";
import "./../contracts/Token.sol";
import "./../contracts/Basket.sol";
// <import file to test>

// File name has to end with '_test.sol', this file can contain more than one testSuite contracts
contract testSuite {
    Token USD;
    Basket public B1;
    address trader;
    
    address Inv1;
    address Inv2;
    address Inv3;
    address Inv4;

    /// 'beforeAll' runs before all other tests
    /// More special functions are: 'beforeEach', 'beforeAll', 'afterEach' & 'afterAll'
    /// #sender: account-0
    function beforeAll() public {
        USD = new Token("USDT","USDT",2);
        B1 = new Basket(address(USD),0);
        console.log("B1",address(B1));
        trader = msg.sender;
        
        Inv1 = TestsAccounts.getAccount(1);
        Inv2 = TestsAccounts.getAccount(2);
        Inv3 = TestsAccounts.getAccount(3);
        Inv4 = TestsAccounts.getAccount(4);

        USD.transfer(Inv1, 10000);
        USD.transfer(Inv2, 10000);
        USD.transfer(Inv3, 10000);
        USD.transfer(Inv4, 10000);
    }

    /// #sender: account-0
    function testActive() public {
        // This will pass
        try B1.active() returns (bool s) {
            Assert.equal(s, true, 'expected false');
        } catch Error(string memory /*reason*/) {
            // This is executed in case
            // revert was called inside getData
            // and a reason string was provided.
            Assert.ok(false, 'failed with reason');
        } catch (bytes memory /*lowLevelData*/) {
            // This is executed in case revert() was used
            // or there was a failing assertion, division
            // by zero, etc. inside getData.
            Assert.ok(false, 'failed unexpected');
        }
    }
    
    /// #sender: account-3
    function invest3() public {
        _invest(1000);
        
    }
    
    /// #sender: account-1
    function invest1() public {
        _invest(500);
    }

    /// #sender: account-2
    function invest2() public {
        _invest(100);
    }

    /// #sender: account-0
    function checkStatus() public {
        Assert.equal(B1.queuedFund(Inv1),uint(500),"Account 1 queued Funds fails");
        Assert.equal(B1.queuedFund(Inv2),uint(100),"Account 2 queued Funds fails");
        Assert.equal(B1.queuedFund(Inv3),uint(1000),"Account 3 queued Funds fails");

        Assert.equal(uint(B1._totalQueuedFunds()),uint(1600),"total Queued Funds fails");
        Assert.equal(uint(B1._totalWithdrawRequests()),uint(0),"total Queued Funds fails");
        Assert.equal(uint(B1._exchangeLockedLiquidity()),uint(0),"exchangeLiquidity fails");
        Assert.equal(uint(B1._inContractLockedLiquidity()),uint(0),"inContractLiquidity fails");
    }
    
    /// #sender: account-0
    function profit0() public {
        try B1.profitShare(0, '', '') returns (bool success) {
            Assert.ok(success,"profit0 failed");
        }catch {
            Assert.ok(false,"profit0 failed");
        }
        logstage();
        Assert.equal(uint(B1.lockedFunds(Inv1)),uint(500),"Account 1 Locked Funds fails");
        Assert.equal(uint(B1.lockedFunds(Inv2)),uint(100),"Account 2 Locked Funds fails");
        Assert.equal(uint(B1.lockedFunds(Inv3)),uint(1000),"Account 0 Locked Funds fails");

        Assert.equal(uint(B1._totalQueuedFunds()),uint(0),"total Queued Funds fails");
        Assert.equal(uint(B1._totalWithdrawRequests()),uint(0),"total Queued Funds fails");
        Assert.equal(uint(B1._exchangeLockedLiquidity()),uint(0),"exchangeLiquidity fails");
        Assert.equal(uint(B1._inContractLockedLiquidity()),uint(1600),"inContractLiquidity fails");

    }

    function checkStatus2() public {
        

    }
    
    //** UTILS
    function _invest(uint256 _amount) private {
        try USD.approve(address(B1), _amount) returns (bool success) {
            Assert.ok(success,"it failed");
        }catch  Error(string memory reason) {
             Assert.ok(false, reason);
        }catch (bytes memory /*lowLevelData*/) {
            Assert.ok(false, 'failed unexpected');
        }
        
        try B1.invest(_amount,'') returns (bool success) {
            Assert.ok(success,"it failed");
        }catch  Error(string memory reason) {
             Assert.ok(false, reason);
        }catch (bytes memory /*lowLevelData*/) {
            Assert.ok(false, 'failed unexpected');
        }
    }

    function logstage() private {
        console.log("_requirdLiquidity:");
        console.log(uint2str(B1._requirdLiquidity()));
        
        console.log("_totalLockedFunds:");
        console.log(uint2str(B1.totalLockedFunds()));

        console.log("_exchangeLockedLiquidity:");
        console.log(uint2str(B1._exchangeLockedLiquidity()));
        
        console.log("_inContractLockedLiquidity:");
        console.log(uint2str(B1._inContractLockedLiquidity()));
        
        console.log("_totalWithdrawRequests:");
        console.log(uint2str(B1._totalWithdrawRequests()));
        
        console.log("_totalQueuedFunds:");
        console.log(uint2str(B1._totalQueuedFunds()));
        
    }

    function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}
    