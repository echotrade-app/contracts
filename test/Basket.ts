import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("Basket",async ()=>{
  const [Trader,Inv1,Inv2,Inv3,Inv4] = await ethers.getSigners();
  async function CreateUSDT() {
    let usdt = await ethers.getContractFactory("Token");
    let USDT = await usdt.deploy("USDT","USDT",2);
    expect( USDT.connect(Trader).transfer(Inv1,10000)).not.to.be.reverted;
    expect( USDT.connect(Trader).transfer(Inv2,10000)).not.to.be.reverted;
    expect( USDT.connect(Trader).transfer(Inv3,10000)).not.to.be.reverted;
    expect( USDT.connect(Trader).transfer(Inv4,10000)).not.to.be.reverted;
    return USDT;
  }
  async function CreateBasket(baseToken:any) {
    let basket = await ethers.getContractFactory("Basket");
    let Basket = basket.deploy(baseToken,0);
    return Basket;
  }
  async function _invest(Investor:any,amount:number) {
    await expect(USDT.connect(Investor).approve(await Basket.getAddress(),amount)).not.to.be.reverted;
    await expect(Basket.connect(Investor).invest(amount,ethers.encodeBytes32String(""))).not.to.be.reverted;
  }
  var USDT = await CreateUSDT();
  var Basket = await CreateBasket(await USDT.getAddress());
  console.log(await USDT.getAddress());
  console.log(await Basket.getAddress());
  
  describe("Loop-0",async function () {
   
    await expect(Basket.connect(Trader).active()).not.to.be.reverted;
    await _invest(Inv1,100);
    await _invest(Inv2,500);
    await _invest(Inv3,1000);
    expect(await Basket._totalQueuedFunds()).to.equal(1600);

    // ─── Profit Share 0 ──────────────────────────────────────────
    await expect(await Basket.connect(Trader).profitShare(0,ethers.encodeBytes32String(""),ethers.encodeBytes32String(""))).not.to.be.reverted;   
  
    await expect(await Basket._inContractLockedLiquidity()).to.equal(1600);
    await expect(await Basket._exchangeLockedLiquidity()).to.equal(0);
    await expect(await Basket._totalQueuedFunds()).to.equal(0);
    await expect(await Basket._totalWithdrawRequests()).to.equal(0);
    await expect(await Basket._requirdLiquidity()).to.equal(0);
    
    await expect(await Basket.lockedFunds(Inv1)).to.equal(100);
    await expect(await Basket.lockedFunds(Inv2)).to.equal(500);
    await expect(await Basket.lockedFunds(Inv3)).to.equal(1000);
    await expect(await Basket.totalLockedFunds()).to.equal(1600);

    // withdraw request 300
    await expect(await Basket.connect(Inv3).withdrawFundRequest(300));

    // invest 200
    await _invest(Inv4,200);
    
    await expect(await Basket._inContractLockedLiquidity()).to.equal(1600); // total liquidity
    await expect(await Basket._exchangeLockedLiquidity()).to.equal(0); // no profit or balance share
    await expect(await Basket._totalQueuedFunds()).to.equal(200);// Inv4 invested 200
    await expect(await Basket._totalWithdrawRequests()).to.equal(300); // Inv3 requested 300
    await expect(await Basket._requirdLiquidity()).to.equal(200); // for paying the queued funds

    // ─── Profit Share 1 ──────────────────────────────────────────
    await expect(await Basket.connect(Trader).profitShare(100,ethers.encodeBytes32String(""),ethers.encodeBytes32String(""))).not.to.be.reverted;

    await expect(await Basket._inContractLockedLiquidity()).to.equal(1600-300+200-100);
    await expect(await Basket._exchangeLockedLiquidity()).to.equal(100);
    // total liquidity 1700
    await expect(await Basket._totalQueuedFunds()).to.equal(0);
    await expect(await Basket._totalWithdrawRequests()).to.equal(0);
    await expect(await Basket._requirdLiquidity()).to.equal(400);
    
    await expect(await Basket.lockedFunds(Inv1)).to.equal(100);
    await expect(await Basket.lockedFunds(Inv2)).to.equal(500);
    await expect(await Basket.lockedFunds(Inv3)).to.equal(700);
    await expect(await Basket.lockedFunds(Inv4)).to.equal(200);
    await expect(await Basket.totalLockedFunds()).to.equal(1500);

    await expect(await Basket._profits(Inv1)).to.equal(Math.floor((100/1600)*100));
    await expect(await Basket._profits(Inv2)).to.equal(Math.floor((500/1600)*100));
    await expect(await Basket._profits(Inv3)).to.equal(Math.floor((1000/1600)*100));
    await expect(await Basket._profits(Inv4)).to.equal(0);
    
    await expect(await Basket.connect(Inv3)["withdrawFund(uint256)"](300)).not.to.be.reverted;
    await expect(await Basket.connect(Inv3)["withdrawProfit(uint256)"](Math.floor((1000/1600)*100))).not.to.be.reverted;
    
    await expect(await Basket._requirdLiquidity()).to.equal(400-300-Math.floor((1000/1600)*100));

    // ─── Profit Share 2 ──────────────────────────────────────────
    
    await expect(await Basket.connect(Trader).profitShare(500,ethers.encodeBytes32String(""),ethers.encodeBytes32String(""))).not.to.be.reverted;
    // console.log(await Basket.connect(Trader).profitShare(500,ethers.encodeBytes32String(""),ethers.encodeBytes32String("")));

    await expect(await Basket._inContractLockedLiquidity()).to.equal(1600-300+200-100-500);
    await expect(await Basket._exchangeLockedLiquidity()).to.equal(100+500);
    await expect(await Basket._totalQueuedFunds()).to.equal(0);
    await expect(await Basket._totalWithdrawRequests()).to.equal(0);
    await expect(await Basket._requirdLiquidity()).to.equal(400-300-Math.floor((1000/1600)*100)+500);
    
    await expect(await Basket.lockedFunds(Inv1)).to.equal(100);
    await expect(await Basket.lockedFunds(Inv2)).to.equal(500);
    await expect(await Basket.lockedFunds(Inv3)).to.equal(700);
    await expect(await Basket.lockedFunds(Inv4)).to.equal(200);
    await expect(await Basket.totalLockedFunds()).to.equal(1500);

    await expect(await Basket._profits(Inv1)).to.equal(Math.floor((100*100)/1600)+Math.floor((100*500)/1500));
    await expect(await Basket._profits(Inv2)).to.equal(Math.floor((500*100)/1600)+Math.floor((500*500)/1500));
    await expect(await Basket._profits(Inv3)).to.equal(Math.floor((700*500)/1500));
    await expect(await Basket._profits(Inv4)).to.equal(Math.floor((200*500)/1500));

    await expect(Basket.connect(Inv3).withdrawFundRequest(500)).not.to.be.reverted;
    await expect(await Basket._totalWithdrawRequests()).to.equal(500);

    // ─── Profit Share 3 ──────────────────────────────────────────
    // console.log("_requirdLiquidity",await Basket._requirdLiquidity());
    // console.log("_ContractFunds",await Basket._inContractLockedLiquidity());
    // console.log("_ExchangeFunds",await Basket._exchangeLockedLiquidity());
    // console.log("_TotalFunds",await Basket.totalLockedFunds());
    // console.log("_TotalWidrawRequestFunds",await Basket._totalWithdrawRequests());
    // console.log("_TotalQueuedFunds",await Basket._totalQueuedFunds());

    let RequiredFunds = await Basket.profitShareRequiredFund(500);
    console.log("\n\nrequired Fund:",RequiredFunds);

    await expect(Basket.connect(Trader).profitShare(500,ethers.encodeBytes32String(""),ethers.encodeBytes32String(""))).to.be.reverted;
    await expect(Basket.connect(Trader).profitShare(500000,ethers.encodeBytes32String(""),ethers.encodeBytes32String(""))).to.be.reverted;

    await expect(USDT.connect(Trader).transfer(await Basket.getAddress(),RequiredFunds)).not.to.be.reverted;
    await expect(Basket.connect(Trader).profitShare(500,ethers.encodeBytes32String(""),ethers.encodeBytes32String(""))).not.to.be.reverted;
    
    await expect(await Basket._inContractLockedLiquidity()).to.equal(1600-300+200-100-500-500-500+Number(RequiredFunds));
    await expect(await Basket._exchangeLockedLiquidity()).to.equal(100+500+500-Number(RequiredFunds));
    await expect(await Basket._totalQueuedFunds()).to.equal(0);
    await expect(await Basket._totalWithdrawRequests()).to.equal(0);
    await expect(await Basket._requirdLiquidity()).to.equal(400-300-Math.floor((1000/1600)*100)+500+500+500);
    
    await expect(await Basket.lockedFunds(Inv1)).to.equal(100);
    await expect(await Basket.lockedFunds(Inv2)).to.equal(500);
    await expect(await Basket.lockedFunds(Inv3)).to.equal(200);
    await expect(await Basket.lockedFunds(Inv4)).to.equal(200);
    await expect(await Basket.totalLockedFunds()).to.equal(1000);

    await expect(await Basket._profits(Inv1)).to.equal(Math.floor((100*100)/1600)+Math.floor((100*500)/1500)+Math.floor((100*500)/1500));
    await expect(await Basket._profits(Inv2)).to.equal(Math.floor((500*100)/1600)+Math.floor((500*500)/1500)+Math.floor((500*500)/1500));
    await expect(await Basket._profits(Inv3)).to.equal(Math.floor((700*500)/1500)+Math.floor((700*500)/1500));
    await expect(await Basket._profits(Inv4)).to.equal(Math.floor((200*500)/1500)+Math.floor((200*500)/1500));

    // ─── Profit Share 4 ──────────────────────────────────────────

    await expect(Basket.connect(Trader).profitShare(700,ethers.encodeBytes32String(""),ethers.encodeBytes32String(""))).to.be.reverted;
    await expect(Basket.connect(Trader).profitShare(1000,ethers.encodeBytes32String(""),ethers.encodeBytes32String(""))).to.be.reverted;
    let RequiredFunds2 = await Basket.profitShareRequiredFund(700);
    console.log("\n\nrequired Fund:",RequiredFunds2);

    await expect(USDT.connect(Trader).transfer(await Basket.getAddress(),RequiredFunds2)).not.to.be.reverted;
    await expect(Basket.connect(Trader).profitShare(700,ethers.encodeBytes32String(""),ethers.encodeBytes32String(""))).not.to.be.reverted;
    
    console.log("_requirdLiquidity",await Basket._requirdLiquidity());

    await expect(await Basket._inContractLockedLiquidity()).to.equal(1600-300+200-100-500-500-500+Number(RequiredFunds)-700+Number(RequiredFunds2));
    await expect(await Basket._exchangeLockedLiquidity()).to.equal(100+500+500-Number(RequiredFunds)+700-Number(RequiredFunds2));
    await expect(await Basket._totalQueuedFunds()).to.equal(0);
    await expect(await Basket._totalWithdrawRequests()).to.equal(0);
    await expect(await Basket._requirdLiquidity()).to.equal(400-300-Math.floor((1000/1600)*100)+500+500+500+700);
    
    await expect(await Basket.lockedFunds(Inv1)).to.equal(100);
    await expect(await Basket.lockedFunds(Inv2)).to.equal(500);
    await expect(await Basket.lockedFunds(Inv3)).to.equal(200);
    await expect(await Basket.lockedFunds(Inv4)).to.equal(200);
    await expect(await Basket.totalLockedFunds()).to.equal(1000);

    await expect(await Basket._profits(Inv1)).to.equal(Math.floor((100*100)/1600)+Math.floor((100*500)/1500)+Math.floor((100*500)/1500)+Math.floor((100*700)/1000));
    await expect(await Basket._profits(Inv2)).to.equal(Math.floor((500*100)/1600)+Math.floor((500*500)/1500)+Math.floor((500*500)/1500)+Math.floor((500*700)/1000));
    await expect(await Basket._profits(Inv3)).to.equal(Math.floor((700*500)/1500)+Math.floor((700*500)/1500)+Math.floor((200*700)/1000));
    await expect(await Basket._profits(Inv4)).to.equal(Math.floor((200*500)/1500)+Math.floor((200*500)/1500)+Math.floor((200*700)/1000));

    await expect(Basket.connect(Inv3).withdrawFundRequest(200)).not.to.be.reverted;

    // ─── Profit Share 5 ──────────────────────────────────────────

    await expect(Basket.connect(Trader).profitShare(0,ethers.encodeBytes32String(""),ethers.encodeBytes32String(""))).to.be.reverted;
    let RequiredFunds3 = await Basket.profitShareRequiredFund(0);
    console.log("\n\nrequired Fund:",RequiredFunds3);

    await expect(USDT.connect(Trader).transfer(await Basket.getAddress(),RequiredFunds3)).not.to.be.reverted;
    await expect(Basket.connect(Trader).profitShare(0,ethers.encodeBytes32String(""),ethers.encodeBytes32String(""))).not.to.be.reverted;
    
    await expect(await Basket._inContractLockedLiquidity()).to.equal(1600-300+200-100-500-500-500+Number(RequiredFunds)-700+Number(RequiredFunds2)-200+Number(RequiredFunds3));
    await expect(await Basket._exchangeLockedLiquidity()).to.equal(100+500+500-Number(RequiredFunds)+700-Number(RequiredFunds2)-Number(RequiredFunds3));
    await expect(await Basket._totalQueuedFunds()).to.equal(0);
    await expect(await Basket._totalWithdrawRequests()).to.equal(0);
    await expect(await Basket._requirdLiquidity()).to.equal(400-300-Math.floor((1000/1600)*100)+500+500+500+700+200);
    
    await expect(await Basket.lockedFunds(Inv1)).to.equal(100);
    await expect(await Basket.lockedFunds(Inv2)).to.equal(500);
    await expect(await Basket.lockedFunds(Inv3)).to.equal(0);
    await expect(await Basket.lockedFunds(Inv4)).to.equal(200);
    await expect(await Basket.totalLockedFunds()).to.equal(800);

    await expect(await Basket._profits(Inv1)).to.equal(Math.floor((100*100)/1600)+Math.floor((100*500)/1500)+Math.floor((100*500)/1500)+Math.floor((100*700)/1000));
    await expect(await Basket._profits(Inv2)).to.equal(Math.floor((500*100)/1600)+Math.floor((500*500)/1500)+Math.floor((500*500)/1500)+Math.floor((500*700)/1000));
    await expect(await Basket._profits(Inv3)).to.equal(Math.floor((700*500)/1500)+Math.floor((700*500)/1500)+Math.floor((200*700)/1000));
    await expect(await Basket._profits(Inv4)).to.equal(Math.floor((200*500)/1500)+Math.floor((200*500)/1500)+Math.floor((200*700)/1000));

    console.log("_requirdLiquidity",await Basket._requirdLiquidity());
    console.log("Inv-3",await Basket.withdrawableFund(Inv3));
    
    await expect(await Basket.connect(Inv3)["withdrawFund(uint256)"](300)).not.to.be.reverted;
    console.log("_requirdLiquidity",await Basket._requirdLiquidity());
    
    console.log("_ContractFunds",await Basket._inContractLockedLiquidity());
    console.log("_ExchangeFunds",await Basket._exchangeLockedLiquidity());
    console.log("_TotalFunds",await Basket.totalLockedFunds());
    console.log("_TotalWidrawRequestFunds",await Basket._totalWithdrawRequests());
    console.log("_TotalQueuedFunds",await Basket._totalQueuedFunds());
    console.log("Inv-1",await Basket._profits(Inv1));
    console.log("Inv-2",await Basket._profits(Inv2));
    console.log("Inv-3",await Basket._profits(Inv3));
    console.log("Inv-4",await Basket._profits(Inv4));

  });

});