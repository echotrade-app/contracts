import { USDT } from './../typechain-types/USDT';
import { expect } from 'chai';
import { Contract, ContractFactory, Signer } from 'ethers';
import { ethers } from 'hardhat';
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import { MultiSigWallet, USDT__factory } from '../typechain-types';
import { time } from '@nomicfoundation/hardhat-toolbox/network-helpers';


describe("MultiSigWallet", async ()=>{
    const NUM_CONFIRMATIONS_REQUIRED = 2
    let Inv1:HardhatEthersSigner, Inv2:HardhatEthersSigner, Company:HardhatEthersSigner, Treasury:HardhatEthersSigner, Team :HardhatEthersSigner,Liquidity :HardhatEthersSigner,Capital :HardhatEthersSigner;
    let Other:HardhatEthersSigner;
    let contract: MultiSigWallet;
    let usdt: USDT__factory;
    let USDT: USDT;
    let owners: Promise<string>[];
    
    beforeEach(async () => {
        [Inv1, Company, Treasury, Team, Liquidity, Capital] = await ethers.getSigners();
        owners = [Inv1.getAddress(), Company.getAddress(), Treasury.getAddress(), Team.getAddress(), Liquidity.getAddress(), Capital.getAddress()];
        let token = await ethers.getContractFactory("MultiSigWallet");
        contract = await token.connect(Inv1).deploy(
            owners,
            NUM_CONFIRMATIONS_REQUIRED,
         );

        usdt = await ethers.getContractFactory("USDT");
        USDT = await usdt.deploy("USDT", "USDT", 2,await time.latest()-100,1);
      });



    describe("submitTransaction, correct flow", () => {
        it("should be executed", async function () {
            const to = owners[0];
            const value = 0;
            const data = "0x0";
            const contract_address = Inv1.getAddress();

            await contract.waitForDeployment()

            await expect(USDT.connect(Inv2).transfer(Inv1, 10000)).not.to.be.reverted;

            await contract.submitTransaction(contract_address, to, value, data);
            await contract.confirmTransaction(0, {from: owners[0]});
            await contract.confirmTransaction(0, {from: owners[1]});
            let resp = await contract.executeTransaction(0, {from: owners[0]});

            expect(resp).to.be.not.undefined;
            expect(resp).to.be.not.null;
            expect(resp).to.be.not.NaN;
            expect(resp).not.to.be.reverted;

            let trx = await contract.getTransaction(0);
            expect(trx.executed).equal(true);
        });
    });

    describe("submitTransaction, confirmers less than required", () => {
        it("should be rejected", async function () {
            const to = owners[0];
            const value = 0;
            const data = "0x0";
            const contract_address = Inv1.getAddress();

            await contract.waitForDeployment()

            await expect(USDT.connect(Inv2).transfer(Inv1, 10000)).not.to.be.reverted;

            await contract.connect(Inv1).submitTransaction(contract_address, to, value, data);
            await contract.confirmTransaction(0, {from: owners[0]});
            // confirmers are less than required
            const resp = await contract.executeTransaction(0, {from: owners[0]});

            expect(resp).to.be.not.undefined;
            expect(resp).to.be.not.null;
            expect(resp).to.be.not.NaN;
            expect(resp).not.to.be.reverted;

            let trx = await contract.getTransaction(0);
            expect(trx.executed).equal(false);
        });
    });

    describe("submitTransaction", () => {
        it("should be rejected", async function () {
            const to = owners[0];
            const value = 0;
            const data = "0x0";
            const contract_address = Inv1.getAddress();

            await contract.waitForDeployment()

            await expect(USDT.connect(Inv2).transfer(Inv1, 10000)).not.to.be.reverted;

            await contract.connect(Inv1).submitTransaction(contract_address, to, value, data);
            await contract.confirmTransaction(0, {from: owners[0]});
            await contract.confirmTransaction(0, {from: owners[1]});
            await contract.revokeConfirmation(0, {from: owners[1]});

            // confirmers are less than required
            const resp = await contract.executeTransaction(0, {from: owners[0]});

            expect(resp).to.be.not.undefined;
            expect(resp).to.be.not.null;
            expect(resp).to.be.not.NaN;
            expect(resp).not.to.be.reverted;

            let trx = await contract.getTransaction(0);
            expect(trx.executed).equal(false);
        });
    });
      
    describe("executeTransaction", () => {
        it("should executeTransaction", async function () {
            await contract.waitForDeployment()

            // Submit a transaction
            const resp = await contract.executeTransaction(10000012300);

            expect(resp).to.be.not.undefined;
            expect(resp).to.be.not.null;
            expect(resp).to.be.not.NaN;
            expect(resp).not.to.be.reverted;
        });
    });

      describe("revokeConfirmation", () => {
        it("should revokeConfirmation", async function () {
            await contract.waitForDeployment()

            // Submit a transaction
            const resp = await contract.revokeConfirmation(10000012300);

            expect(resp).to.be.not.undefined;
            expect(resp).to.be.not.null;
            expect(resp).to.be.not.NaN;
            expect(resp).not.to.be.reverted;
        });
    });
      
      describe("getOwners", () => {
        it("should getOwners", async function () {
            await contract.waitForDeployment()

            // Submit a transaction
            const resp = await contract.getOwners();

            expect(resp).to.be.not.undefined;
            expect(resp).to.be.not.null;
            expect(resp).to.be.not.NaN;
            expect(resp).not.to.be.reverted;
        });
    });  
      
      describe("getTransactionCount", () => {
        it("should getTransactionCount", async function () {
            await contract.waitForDeployment()
            // Submit a transaction
            const resp = await contract.getTransactionCount();

            expect(resp).to.be.not.undefined;
            expect(resp).to.be.not.null;
            expect(resp).to.be.not.NaN;
            expect(resp).not.to.be.reverted;
        });
    });


      describe("getTransaction", () => {
        it("should getTransaction", async function () {
            await contract.waitForDeployment()

            // Submit a transaction
            const resp = await contract.getTransaction(10000012300);

            expect(resp).to.be.not.undefined;
            expect(resp).to.be.not.null;
            expect(resp).to.be.not.NaN;
            expect(resp).not.to.be.reverted;
        });
    });

});

