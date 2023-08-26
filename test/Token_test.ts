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
      let now = await time.latest();
      console.log(now);
      let ECTO = await token.connect(SA).deploy("ECTA", "ECTA", 2,now+1*3600,3600);
      
      await expect(ECTO.connect(SA).transfer(Owner1, 10000)).to.be.reverted;
      
      time.increaseTo(now+1.01*3600);
      // release started
      // this amount is not released yet
      await expect(ECTO.connect(SA).transfer(Owner1, 10000)).to.be.reverted;

      // but this amount is
      // console.log(await ECTO.whenWillRelease(100000,await))
      await expect(ECTO.connect(SA).transfer(Owner1, 1)).not.to.be.reverted;
      
      time.increaseTo(now+1.51*3600);
      console.log("transfering reminder",Math.floor(Number(await ECTO.balanceOf(SA))/2));
      await expect(ECTO.connect(SA).transfer(Owner1,  Math.floor(Number(await ECTO.balanceOf(SA))/2))).not.to.be.reverted;
      await expect(ECTO.connect(SA).transfer(Owner1,  Math.floor(Number(await ECTO.balanceOf(SA))/2))).to.be.reverted;
      
      time.increaseTo(now+2.1*3600);
      console.log("transfering reminder",await ECTO.balanceOf(SA));
      await expect(ECTO.connect(SA).transfer(Owner1,  Number(await ECTO.balanceOf(SA)))).not.to.be.reverted;

      

      await expect(await ECTO._superAdmin()).to.equal(SA.address);

    });
});