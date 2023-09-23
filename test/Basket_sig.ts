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
    let now = Math.floor(Date.now()/1000);
    let USDT = await CreateUSDT();
    let Basket = await CreateBasket(await USDT.getAddress(),Trader);
    
    // let Buf = ethers.decodeBase64("X2oZz4NSGceiX0iSfxJxcVRczKGsO5aoqUavbGgHjM0z/IC04zV+5toaAfufKSh6+rNrSjeEjojmszMeEQ/0OgE=")
    // let hex = "0xebb19401714cd26302a86f4b0ef1230579de4db3f091ca39277d5b409abf12c45a13b4cda5982c0cef9cff08d711d7c965632775934250885b059bb8aca09bc01c";
    let hex = "0x0c76526e86b72985c279c2d48c819df7ae704dc124081093b8800c678772594b5bc581c510134c2b6b06bb4bd2b8bc6b672dac03119b41d10f76728e7bd6d4501b";

    async function _invest(Investor: any, amount: number) {
      await expect(USDT.connect(Investor).approve(await Basket.getAddress(), amount)).not.to.be.reverted;
      await expect(Basket.connect(Investor).invest(amount,hex)).not.to.be.reverted;
    }

    await expect(Basket.connect(Trader).active()).not.to.be.reverted;
    console.log(await Basket.getAddress());
    console.log(await Basket.invest_signatureData(Inv1,100,1700000000))

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
    let now = Math.floor(Date.now()/1000);
    let Basket = basket.deploy(100, baseToken, Trader, Trader, 0, 100000, 250, 1500, 500,now+1*3600,now+24*3600 );
    return Basket;
  }
});