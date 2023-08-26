import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";
import { ContractTransactionResponse } from "ethers";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";

describe("Token",async ()=>{

    it("SuperAdmin",async ()=>{
      let SA:HardhatEthersSigner, Owner1:HardhatEthersSigner, Owner2:HardhatEthersSigner, Owner3:HardhatEthersSigner, Owner4 :HardhatEthersSigner;
      [SA, Owner1, Owner2, Owner3, Owner4] = await ethers.getSigners();
      let token = await ethers.getContractFactory("Token");
      let ECTO = await token.connect(SA).deploy("ECTA", "ECTA", 2,2);
      expect(ECTO.connect(SA).transfer(Owner1, 10000)).not.to.be.reverted;
      expect(ECTO.connect(SA).transfer(Owner2, 10000)).not.to.be.reverted;
      expect(ECTO.connect(SA).transfer(Owner3, 10000)).not.to.be.reverted;
      expect(ECTO.connect(SA).transfer(Owner4, 10000)).not.to.be.reverted;

      expect(await ECTO._superAdmin()).to.equal(SA.address);

    });
});