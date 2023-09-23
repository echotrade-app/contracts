import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";
import { ContractTransactionResponse } from "ethers";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import { Buffer } from "buffer";

describe("Basket", async ()=> {
  let Trader:HardhatEthersSigner, Inv1:HardhatEthersSigner, Inv2:HardhatEthersSigner, Inv3:HardhatEthersSigner, Inv4 :HardhatEthersSigner;

  it("Signature verification",async ()=> {
    [Trader, Inv1, Inv2, Inv3, Inv4] = await ethers.getSigners();
    let USDT = await CreateUSDT();
    let Basket = await CreateBasket(await USDT.getAddress(),Trader);
    
    
    async function _invest(Investor: any, amount: number) {
      await expect(USDT.connect(Investor).approve(await Basket.getAddress(), amount)).not.to.be.reverted;
      let msg = await Basket.invest_signatureData(Investor,amount,Math.floor((await time.latest())/300));
      let sig  = await Trader.signMessage(ethers.getBytes(msg));
      await expect(Basket.connect(Investor).invest(amount,sig)).not.to.be.reverted;
    }

    await expect(Basket.connect(Trader).active()).not.to.be.reverted;

    await _invest(Inv1,100);

  })

  async function CreateUSDT() {
    let usdt = await ethers.getContractFactory("USDT");
    let USDT = await usdt.deploy("USDT", "USDT", 2,await time.latest()-100,1);
    await expect(USDT.connect(Trader).transfer(Inv1, 10000)).not.to.be.reverted;
    await expect(USDT.connect(Trader).transfer(Inv2, 10000)).not.to.be.reverted;
    await expect(USDT.connect(Trader).transfer(Inv3, 10000)).not.to.be.reverted;
    await expect(USDT.connect(Trader).transfer(Inv4, 10000)).not.to.be.reverted;
    return USDT;
  }
  
  async function CreateBasket(baseToken: any,Trader:any) {
    let basket = await ethers.getContractFactory("Basket");
    let now = await time.latest();
    let Basket = basket.connect(Trader).deploy(100, baseToken, Trader, Trader, 0, 100000, 250, 1500, 500,now+1*3600,now+24*3600 );
    return Basket;
  }
});