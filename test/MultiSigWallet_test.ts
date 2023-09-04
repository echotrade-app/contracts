import { expect } from 'chai';
import { Contract, ContractFactory, Signer } from 'ethers';
import { ethers } from 'hardhat';
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import { MultiSigWallet } from '../typechain-types';


describe("MultiSigWallet", async ()=>{
    let Inv1:HardhatEthersSigner, Inv2:HardhatEthersSigner, Company:HardhatEthersSigner, Treasury:HardhatEthersSigner, Team :HardhatEthersSigner,Liquidity :HardhatEthersSigner,Capital :HardhatEthersSigner;
    let Other:HardhatEthersSigner;
    let contract: MultiSigWallet;
    
    beforeEach(async () => {
        [Inv1, Inv2, Company, Treasury, Team, Liquidity, Capital,Other] = await ethers.getSigners();
        let token = await ethers.getContractFactory("MultiSigWallet");
        contract = await token.connect(Inv1).deploy(
            [Inv2.getAddress(), Inv1.getAddress(), Company.getAddress(), Treasury.getAddress(), Team.getAddress(), Liquidity.getAddress(), Capital.getAddress(), Capital.getAddress(), Other.getAddress()], 
            8,
         );
      });



    describe("submitTransaction", () => {
        it("should submitTransaction", async function () {
            await contract.waitForDeployment()

            // Submit a transaction
            const resp = await contract.submitTransaction(Inv1.getAddress(), Inv2.getAddress(), 1000, '0x');

            expect(resp).to.be.not.undefined;
            expect(resp).to.be.not.null;
            expect(resp).to.be.not.NaN;
            expect(resp).to.equal(5);
        });
    });

    describe("confirmTransaction", () => {
        it("should confirmTransaction", async function () {
            await contract.waitForDeployment()

            // Submit a transaction
            const resp = await contract.confirmTransaction(10000012300);

            expect(resp).to.be.not.undefined;
            expect(resp).to.be.not.null;
            expect(resp).to.be.not.NaN;
            expect(resp).to.equal(5);
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
            expect(resp).to.equal(5);
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
            expect(resp).to.equal(5);
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
            expect(resp).to.equal(5);
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
            expect(resp).to.equal(5);
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
            expect(resp).to.equal(5);
        });
    });

});

