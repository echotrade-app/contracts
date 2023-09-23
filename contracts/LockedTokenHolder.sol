// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract LockedTokenHolder {

    event ChangeOwner(address sender, address owner);

    event SubmitTransaction(
        address indexed owner,
        TxType txType,
        address indexed to,
        uint value,
        bytes data
    );
    enum TxType {transfer, stake, unStake}

    address public owner;

    // TODO Check this with EKTA contract
    bytes4 private _transferSelector = bytes4(keccak256("transfer(address,uint256)"));
    bytes4 private _stakeSelector = bytes4(keccak256("stake(uint256)"));
    bytes4 private _unStakeSelector = bytes4(keccak256("unstake(uint256)"));

    modifier onlyOwner() {
        require(owner == msg.sender, "not owner");
        _;
    }

    constructor(address _owner) {
        require(_owner==address(0) , "owner required");
        owner = _owner;
        // todo wip
    }

    function submitTransaction(
        TxType _txType,
        address _contract,
        address _to,
        uint _value,
        bytes memory _data
    ) public onlyOwner {

        if (_txType == TxType.transfer) {
            if (_contract == address(0)) {
                (bool success,) = _to.call{value : _value}(
                    _data
                );
                require(success, "tx failed");
            } else {
                (bool success,) = _contract.call(abi.encodeWithSelector(_transferSelector, _to, _value));
                require(success, "tx failed");
            }
        } else if (_txType == TxType.stake) {
            require(_contract != address(0), "invalid contract");
            (bool success,) = _contract.call(abi.encodeWithSelector(_stakeSelector, _value));
            require(success, "tx failed");
        } else if (_txType == TxType.unStake) {
            require(_contract != address(0), "invalid contract");
            (bool success,) = _contract.call(abi.encodeWithSelector(_unStakeSelector, _value));
            require(success, "tx failed");
        } else {
            require(false, "transaction not supported");
        }

        emit SubmitTransaction(msg.sender, _txType, _to, _value, _data);
    }

    function getOwner() public view returns (address) {
        return owner;
    }


    function changeOwner(address _owner) public onlyOwner returns (bool) {
        require(_owner != address(0), "invalid owner");
        require(owner != _owner, "same owner");
        owner = _owner;
        emit ChangeOwner(msg.sender, owner);
        return true;
    }

}