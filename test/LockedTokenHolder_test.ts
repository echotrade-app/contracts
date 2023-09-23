import {loadFixture,} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import {expect} from "chai";
import {ethers} from "hardhat";

describe("LockedTokenHolder", function () {

    async function deployWithRandomOwner() {

        // Contracts are deployed using the first signer/account by default
        const [owner, otherAccount] = await ethers.getSigners();

        const LockedTokenHolder = await ethers.getContractFactory("LockedTokenHolder");
        const lockedTokenHolder = await LockedTokenHolder.deploy(owner);

        return {lockedTokenHolder, owner, otherAccount};
    }

    describe("Deployment", function () {

        it("Should set the right owner", async function () {
            const {lockedTokenHolder, owner} = await loadFixture(deployWithRandomOwner);

            expect(await lockedTokenHolder.getOwner()).to.equal(owner.address);
        });
        it("Should failed if owner is invalid", async function () {
            const LockedTokenHolder = await ethers.getContractFactory("LockedTokenHolder");
            await expect(LockedTokenHolder.deploy(ethers.constants.AddressZero).to.be.revertedWith(
                "owner required"
            ));
        });

    });

    describe("ChangeOwner", function () {
        describe("Validations", function () {

            it("Should fail if call change owner address to empty address", async function () {

                const {lockedTokenHolder} = await loadFixture(deployWithRandomOwner);

                await expect(lockedTokenHolder.changeOwner(ethers.constants.AddressZero).to.be.revertedWith(
                    "invalid owner"
                ));
            });
            it("Should fail if call change owner address to current owner address", async function () {

                const {lockedTokenHolder, owner} = await loadFixture(deployWithRandomOwner);

                await expect(lockedTokenHolder.changeOwner(owner.address).to.be.revertedWith(
                    "same owner"
                ));
            });
            it("Should fail if not owner person call change owner", async function () {

                const {lockedTokenHolder, otherAccount} = await loadFixture(deployWithRandomOwner);

                await expect(lockedTokenHolder.connect(otherAccount).changeOwner(otherAccount.address).to.be.revertedWith(
                    "not owner"
                ));
            });
            it("Should get owner function return new owner address in success case", async function () {

                const {lockedTokenHolder, otherAccount} = await loadFixture(deployWithRandomOwner);
                lockedTokenHolder.changeOwner(otherAccount.address);
                await expect(lockedTokenHolder.getOwner().to.equal(
                    otherAccount.address
                ));
            });
        });
        describe("Events", function () {
            it("Should emit an event on change owner", async function () {
                const {lockedTokenHolder, owner, otherAccount} = await loadFixture(deployWithRandomOwner);

                await expect(lockedTokenHolder.changeOwner(otherAccount.address))
                    .to.emit(lockedTokenHolder, "ChangeOwner")
                    .withArgs(owner.address, otherAccount.address);
            });
        });
    })
    describe("submitTransaction", function () {
        describe("Transfer", function () {

            describe("Validations", function () {

                it("Should fail if call change owner address to empty address", async function () {

                });
                it("Should fail if call change owner address to current owner address", async function () {

                });
                it("Should fail if not owner person call change owner", async function () {

                });
                it("Should get owner function return new owner address in success case", async function () {

                });
            });
            describe("Events", function () {
                it("Should emit an event on change owner", async function () {
                });
            });
        })
        describe("Stake", function () {

        })
        describe("UnStake", function () {

        })
    })
});