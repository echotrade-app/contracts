import { expect } from 'chai';
import { Contract, ContractFactory, Signer } from 'ethers';
import { ethers } from 'hardhat';

describe('MultiSigWallet', () => {
  let MultiSigWallet: ContractFactory;
  let multiSigWallet: Contract;
  let owners: Signer[];
  let numConfirmationsRequired: number;
  let transferSelector: string;

  beforeEach(async () => {
    [owners[0], owners[1], owners[2]] = await ethers.getSigners();
    numConfirmationsRequired = 2;
    transferSelector = '0x' + 'transfer(address,uint256)'.slice(0, 8);

    MultiSigWallet = await ethers.getContractFactory('MultiSigWallet');
    multiSigWallet = await MultiSigWallet.deploy([await owners[0].getAddress()], numConfirmationsRequired);
    await multiSigWallet.deployed();
  });

  it('should submit and execute a transaction', async () => {
    const to = await owners[1].getAddress();
    const value = ethers.utils.parseEther('1.0');
    const data = '0x';

    // Submit a transaction
    await multiSigWallet.connect(owners[0]).submitTransaction(to, value, data);

    const txIndex = 0;

    // Confirm the transaction
    await multiSigWallet.connect(owners[1]).confirmTransaction(txIndex);
    await multiSigWallet.connect(owners[2]).confirmTransaction(txIndex);

    // Execute the transaction
    const initialBalance = await ethers.provider.getBalance(to);
    await multiSigWallet.connect(owners[0]).executeTransaction(txIndex);

    const finalBalance = await ethers.provider.getBalance(to);
    const transaction = await multiSigWallet.transactions(txIndex);

    // Check that the transaction was executed
    expect(transaction.executed).to.equal(true);
    // Check that the recipient's balance increased by the transaction value
    expect(finalBalance.sub(initialBalance)).to.equal(value);
  });

  // Add more test cases as needed to cover other contract functionality
});
