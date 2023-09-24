import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";
import { ContractTransactionResponse } from "ethers";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";

describe("Basket", async ()=> {
  let Trader:HardhatEthersSigner, Inv1:HardhatEthersSigner, Inv2:HardhatEthersSigner, Inv3:HardhatEthersSigner, Inv4 :HardhatEthersSigner;

  it("Scenario 1 - Investment with Profit and loss",async ()=> {
    [Trader, Inv1, Inv2, Inv3, Inv4] = await ethers.getSigners();
    let now = Math.floor(Date.now()/1000);
    let USDT = await CreateUSDT();
    let Basket = await CreateBasket(await USDT.getAddress(),Trader);

    async function _invest(Investor: any, amount: number) {
      await expect(USDT.connect(Investor).approve(await Basket.getAddress(), amount)).not.to.be.reverted;
      let msg = await Basket.invest_signatureData(Investor,amount,Math.floor((await time.latest())/300));
      let sig  = await Trader.signMessage(ethers.getBytes(msg));
      await expect(Basket.connect(Investor).invest(amount, sig)).not.to.be.reverted;
    }
    await expect(Basket.connect(Trader).active()).not.to.be.reverted;
    await _invest(Inv1, 100);
    await _invest(Inv2, 500);
    await _invest(Inv3, 1000);
    expect(await Basket.totalQueuedFunds()).to.equal(1600);

    // ─── Profit Share 0 ──────────────────────────────────────────
    await expect(Basket.connect(Trader).profitShare(0, ethers.encodeBytes32String(""), ethers.encodeBytes32String(""))).to.be.reverted; //since startTime is not acchived yet.
    // @ start Time
    await time.increaseTo(now+3*3600);
    await expect(Basket.connect(Trader).profitShare(0, ethers.encodeBytes32String(""), ethers.encodeBytes32String(""))).not.to.be.reverted;

    await expect(await Basket.contractLockedLiquidity()).to.equal(1600);
    await expect(await Basket.exchangeLockedLiquidity()).to.equal(0);
    await expect(await Basket.totalQueuedFunds()).to.equal(0);
    await expect(await Basket.totalWithdrawRequests()).to.equal(0);
    await expect(await Basket.requirdLiquidity()).to.equal(0);

    await expect(await Basket.lockedFunds(Inv1)).to.equal(100);
    await expect(await Basket.lockedFunds(Inv2)).to.equal(500);
    await expect(await Basket.lockedFunds(Inv3)).to.equal(1000);
    await expect(await Basket.totalLockedFunds()).to.equal(1600);

    // withdraw request 300
    await expect(await Basket.connect(Inv3).unlockFundRequest(300));

    // invest 200
    await _invest(Inv4, 200);

    await expect(await Basket.contractLockedLiquidity()).to.equal(1600); // total liquidity
    await expect(await Basket.exchangeLockedLiquidity()).to.equal(0); // no profit or balance share
    await expect(await Basket.totalQueuedFunds()).to.equal(200); // Inv4 invested 200
    await expect(await Basket.totalWithdrawRequests()).to.equal(300); // Inv3 requested 300
    await expect(await Basket.requirdLiquidity()).to.equal(200); // for paying the queued funds

    // ─── Profit Share 1 ──────────────────────────────────────────
    await expect(Basket.connect(Trader).profitShare(100, ethers.encodeBytes32String(""), ethers.encodeBytes32String(""))).not.to.be.reverted;

    await expect(await Basket.contractLockedLiquidity()).to.equal(1600 - 300 + 200 - 100);
    await expect(await Basket.exchangeLockedLiquidity()).to.equal(100);
    // total liquidity 1700
    await expect(await Basket.totalQueuedFunds()).to.equal(0);
    await expect(await Basket.totalWithdrawRequests()).to.equal(0);
    await expect(await Basket.requirdLiquidity()).to.equal(400);

    await expect(await Basket.lockedFunds(Inv1)).to.equal(100);
    await expect(await Basket.lockedFunds(Inv2)).to.equal(500);
    await expect(await Basket.lockedFunds(Inv3)).to.equal(700);
    await expect(await Basket.lockedFunds(Inv4)).to.equal(200);
    await expect(await Basket.totalLockedFunds()).to.equal(1500);

    await expect(await Basket.profits(Inv1)).to.equal(Math.floor((100 / 1600) * (100*0.8)));
    await expect(await Basket.profits(Inv2)).to.equal(Math.floor((500 / 1600) * (100*0.8)));
    await expect(await Basket.profits(Inv3)).to.equal(Math.floor((1000 / 1600) * (100*0.8)));
    await expect(await Basket.profits(Inv4)).to.equal(0);

    await expect(Basket.connect(Inv3)["withdrawFund(uint256)"](300)).not.to.be.reverted;
    await expect(Basket.connect(Inv3)["withdrawProfit(uint256)"](Math.floor((1000 / 1600) * (100*0.8)))).not.to.be.reverted;

    await expect(await Basket.requirdLiquidity()).to.equal(400 - 300 - Math.floor((1000 / 1600) * (100*0.8)));

    // ─── Profit Share 2 ──────────────────────────────────────────

    await expect(Basket.connect(Trader).profitShare(500, ethers.encodeBytes32String(""), ethers.encodeBytes32String(""))).not.to.be.reverted;
    // console.log(await Basket.connect(Trader).profitShare(500,ethers.encodeBytes32String(""),ethers.encodeBytes32String("")));

    await expect(await Basket.contractLockedLiquidity()).to.equal(1600 - 300 + 200 - 100 - 500);
    await expect(await Basket.exchangeLockedLiquidity()).to.equal(100 + 500);
    await expect(await Basket.totalQueuedFunds()).to.equal(0);
    await expect(await Basket.totalWithdrawRequests()).to.equal(0);
    await expect(await Basket.requirdLiquidity()).to.equal(400 - 300 - Math.floor((1000 / 1600) * (100*0.8)) + 500);

    await expect(await Basket.lockedFunds(Inv1)).to.equal(100);
    await expect(await Basket.lockedFunds(Inv2)).to.equal(500);
    await expect(await Basket.lockedFunds(Inv3)).to.equal(700);
    await expect(await Basket.lockedFunds(Inv4)).to.equal(200);
    await expect(await Basket.totalLockedFunds()).to.equal(1500);

    await expect(await Basket.profits(Inv1)).to.equal(Math.floor((100 * 100*0.8) / 1600) + Math.floor((100 * 500*0.8) / 1500));
    await expect(await Basket.profits(Inv2)).to.equal(Math.floor((500 * 100*0.8) / 1600) + Math.floor((500 * 500*0.8) / 1500));
    await expect(await Basket.profits(Inv3)).to.equal(Math.floor((700 * 500*0.8) / 1500));
    await expect(await Basket.profits(Inv4)).to.equal(Math.floor((200 * 500*0.8) / 1500));

    await expect(Basket.connect(Inv3).unlockFundRequest(500)).not.to.be.reverted;
    await expect(await Basket.totalWithdrawRequests()).to.equal(500);

    // ─── Profit Share 3 ──────────────────────────────────────────
    // console.log("requirdLiquidity",await Basket.requirdLiquidity());
    // console.log("_ContractFunds",await Basket.contractLockedLiquidity());
    // console.log("_ExchangeFunds",await Basket.exchangeLockedLiquidity());
    // console.log("_TotalFunds",await Basket.totalLockedFunds());
    // console.log("_TotalWidrawRequestFunds",await Basket.totalWithdrawRequests());
    // console.log("totalQueuedFunds",await Basket.totalQueuedFunds());

    let RequiredFunds = await Basket.profitShareRequiredFund(500);
    console.log("\n\nrequired Fund:", RequiredFunds);

    await expect(Basket.connect(Trader).profitShare(500, ethers.encodeBytes32String(""), ethers.encodeBytes32String(""))).to.be.reverted;
    await expect(Basket.connect(Trader).profitShare(500000, ethers.encodeBytes32String(""), ethers.encodeBytes32String(""))).to.be.reverted;

    await expect(USDT.connect(Trader).transfer(await Basket.getAddress(), RequiredFunds)).not.to.be.reverted;
    await expect(Basket.connect(Trader).profitShare(500, ethers.encodeBytes32String(""), ethers.encodeBytes32String(""))).not.to.be.reverted;

    await expect(await Basket.contractLockedLiquidity()).to.equal(1600 - 300 + 200 - 100 - 500 - 500 - 500 + Number(RequiredFunds));
    await expect(await Basket.exchangeLockedLiquidity()).to.equal(100 + 500 + 500 - Number(RequiredFunds));
    await expect(await Basket.totalQueuedFunds()).to.equal(0);
    await expect(await Basket.totalWithdrawRequests()).to.equal(0);
    await expect(await Basket.requirdLiquidity()).to.equal(400 - 300 - Math.floor((1000 / 1600) * (100*0.8)) + 500 + 500 + 500);

    await expect(await Basket.lockedFunds(Inv1)).to.equal(100);
    await expect(await Basket.lockedFunds(Inv2)).to.equal(500);
    await expect(await Basket.lockedFunds(Inv3)).to.equal(200);
    await expect(await Basket.lockedFunds(Inv4)).to.equal(200);
    await expect(await Basket.totalLockedFunds()).to.equal(1000);

    await expect(await Basket.profits(Inv1)).to.equal(Math.floor((100 * (100*0.8)) / 1600) + Math.floor((100 * (500*0.8)) / 1500) + Math.floor((100 * (500*0.8)) / 1500));
    await expect(await Basket.profits(Inv2)).to.equal(Math.floor((500 * (100*0.8)) / 1600) + Math.floor((500 * (500*0.8)) / 1500) + Math.floor((500 * (500*0.8)) / 1500));
    await expect(await Basket.profits(Inv3)).to.equal(Math.floor((700 * (500*0.8)) / 1500) + Math.floor((700 * (500*0.8)) / 1500));
    await expect(await Basket.profits(Inv4)).to.equal(Math.floor((200 * (500*0.8)) / 1500) + Math.floor((200 * (500*0.8)) / 1500));

    // ─── Profit Share 4 ──────────────────────────────────────────

    await expect(Basket.connect(Trader).profitShare(700, ethers.encodeBytes32String(""), ethers.encodeBytes32String(""))).to.be.reverted;
    await expect(Basket.connect(Trader).profitShare(1000, ethers.encodeBytes32String(""), ethers.encodeBytes32String(""))).to.be.reverted;
    let RequiredFunds2 = await Basket.profitShareRequiredFund(700);
    console.log("\n\nrequired Fund:", RequiredFunds2);

    await expect(USDT.connect(Trader).transfer(await Basket.getAddress(), RequiredFunds2)).not.to.be.reverted;
    await expect(Basket.connect(Trader).profitShare(700, ethers.encodeBytes32String(""), ethers.encodeBytes32String(""))).not.to.be.reverted;

    console.log("requirdLiquidity", await Basket.requirdLiquidity());

    await expect(await Basket.contractLockedLiquidity()).to.equal(1600 - 300 + 200 - 100 - 500 - 500 - 500 + Number(RequiredFunds) - 700 + Number(RequiredFunds2));
    await expect(await Basket.exchangeLockedLiquidity()).to.equal(100 + 500 + 500 - Number(RequiredFunds) + 700 - Number(RequiredFunds2));
    await expect(await Basket.totalQueuedFunds()).to.equal(0);
    await expect(await Basket.totalWithdrawRequests()).to.equal(0);
    await expect(await Basket.requirdLiquidity()).to.equal(400 - 300 - Math.floor((1000 / 1600) * (100*0.8)) + 500 + 500 + 500 + 700);

    await expect(await Basket.lockedFunds(Inv1)).to.equal(100);
    await expect(await Basket.lockedFunds(Inv2)).to.equal(500);
    await expect(await Basket.lockedFunds(Inv3)).to.equal(200);
    await expect(await Basket.lockedFunds(Inv4)).to.equal(200);
    await expect(await Basket.totalLockedFunds()).to.equal(1000);

    await expect(await Basket.profits(Inv1)).to.equal(Math.floor((100 * (100*0.8)) / 1600) + Math.floor((100 * (500*0.8)) / 1500) + Math.floor((100 * (500*0.8)) / 1500) + Math.floor((100 * (700*0.8)) / 1000));
    await expect(await Basket.profits(Inv2)).to.equal(Math.floor((500 * (100*0.8)) / 1600) + Math.floor((500 * (500*0.8)) / 1500) + Math.floor((500 * (500*0.8)) / 1500) + Math.floor((500 * (700*0.8)) / 1000));
    await expect(await Basket.profits(Inv3)).to.equal(Math.floor((700 * (500*0.8)) / 1500) + Math.floor((700 * (500*0.8)) / 1500) + Math.floor((200 * (700*0.8)) / 1000));
    await expect(await Basket.profits(Inv4)).to.equal(Math.floor((200 * (500*0.8)) / 1500) + Math.floor((200 * (500*0.8)) / 1500) + Math.floor((200 * (700*0.8)) / 1000));

    await expect(Basket.connect(Inv3).unlockFundRequest(200)).not.to.be.reverted;

    // ─── Profit Share 5 ──────────────────────────────────────────

    await expect(Basket.connect(Trader).profitShare(0, ethers.encodeBytes32String(""), ethers.encodeBytes32String(""))).to.be.reverted;
    let RequiredFunds3 = await Basket.profitShareRequiredFund(0);
    console.log("\n\nrequired Fund:", RequiredFunds3);

    await expect(USDT.connect(Trader).transfer(await Basket.getAddress(), RequiredFunds3)).not.to.be.reverted;
    await expect(Basket.connect(Trader).profitShare(0, ethers.encodeBytes32String(""), ethers.encodeBytes32String(""))).not.to.be.reverted;

    await expect(await Basket.contractLockedLiquidity()).to.equal(1600 - 300 + 200 - 100 - 500 - 500 - 500 + Number(RequiredFunds) - 700 + Number(RequiredFunds2) - 200 + Number(RequiredFunds3));
    await expect(await Basket.exchangeLockedLiquidity()).to.equal(100 + 500 + 500 - Number(RequiredFunds) + 700 - Number(RequiredFunds2) - Number(RequiredFunds3));
    await expect(await Basket.totalQueuedFunds()).to.equal(0);
    await expect(await Basket.totalWithdrawRequests()).to.equal(0);
    await expect(await Basket.requirdLiquidity()).to.equal(400 - 300 - Math.floor((1000 / 1600) * (100*0.8)) + 500 + 500 + 500 + 700 + 200);

    await expect(await Basket.lockedFunds(Inv1)).to.equal(100);
    await expect(await Basket.lockedFunds(Inv2)).to.equal(500);
    await expect(await Basket.lockedFunds(Inv3)).to.equal(0);
    await expect(await Basket.lockedFunds(Inv4)).to.equal(200);
    await expect(await Basket.totalLockedFunds()).to.equal(800);

    await expect(await Basket.profits(Inv1)).to.equal(Math.floor((100 * (100*0.8)) / 1600) + Math.floor((100 * (500*0.8)) / 1500) + Math.floor((100 * (500*0.8)) / 1500) + Math.floor((100 * (700*0.8)) / 1000));
    await expect(await Basket.profits(Inv2)).to.equal(Math.floor((500 * (100*0.8)) / 1600) + Math.floor((500 * (500*0.8)) / 1500) + Math.floor((500 * (500*0.8)) / 1500) + Math.floor((500 * (700*0.8)) / 1000));
    await expect(await Basket.profits(Inv3)).to.equal(Math.floor((700 * (500*0.8)) / 1500) + Math.floor((700 * (500*0.8)) / 1500) + Math.floor((200 * (700*0.8)) / 1000));
    await expect(await Basket.profits(Inv4)).to.equal(Math.floor((200 * (500*0.8)) / 1500) + Math.floor((200 * (500*0.8)) / 1500) + Math.floor((200 * (700*0.8)) / 1000));

    await expect(Basket.connect(Inv3)["withdrawFund(uint256)"](300)).not.to.be.reverted;
    
        
    // ─── Profit Share 6 ──────────────────────────────────────────
    // lost 100
    await expect(Basket.connect(Trader).profitShare(-100, ethers.encodeBytes32String(""), ethers.encodeBytes32String(""))).not.to.be.reverted;

    await expect(await Basket.contractLockedLiquidity()).to.equal(1600 - 300 + 200 - 100 - 500 - 500 - 500 + Number(RequiredFunds) - 700 + Number(RequiredFunds2) - 200 + Number(RequiredFunds3));
    await expect(await Basket.exchangeLockedLiquidity()).to.equal(100 + 500 + 500 - Number(RequiredFunds) + 700 - Number(RequiredFunds2) - Number(RequiredFunds3)-100);
    await expect(await Basket.totalQueuedFunds()).to.equal(0);
    await expect(await Basket.totalWithdrawRequests()).to.equal(0);
    await expect(await Basket.requirdLiquidity()).to.equal(400 - 300 - Math.floor((1000 / 1600) * (100*0.8)) + 500 + 500 + 500 + 700 + 200-300);

    await expect(await Basket.lockedFunds(Inv1)).to.equal(100-Math.floor((100*100)/800));
    await expect(await Basket.lockedFunds(Inv2)).to.equal(500-Math.floor((500*100)/800));
    await expect(await Basket.lockedFunds(Inv3)).to.equal(0);
    await expect(await Basket.lockedFunds(Inv4)).to.equal(200-Math.floor((200*100)/800));
    await expect(await Basket.totalLockedFunds()).to.equal(800-100);

    await expect(await Basket.profits(Inv1)).to.equal(Math.floor((100 * (100*0.8)) / 1600) + Math.floor((100 * (500*0.8)) / 1500) + Math.floor((100 * (500*0.8)) / 1500) + Math.floor((100 * (700*0.8)) / 1000));
    await expect(await Basket.profits(Inv2)).to.equal(Math.floor((500 * (100*0.8)) / 1600) + Math.floor((500 * (500*0.8)) / 1500) + Math.floor((500 * (500*0.8)) / 1500) + Math.floor((500 * (700*0.8)) / 1000));
    await expect(await Basket.profits(Inv3)).to.equal(Math.floor((700 * (500*0.8)) / 1500) + Math.floor((700 * (500*0.8)) / 1500) + Math.floor((200 * (700*0.8)) / 1000));
    await expect(await Basket.profits(Inv4)).to.equal(Math.floor((200 * (500*0.8)) / 1500) + Math.floor((200 * (500*0.8)) / 1500) + Math.floor((200 * (700*0.8)) / 1000));

    // Inv2 withdraw all of his money
    await expect(Basket.connect(Inv2).unlockFundRequest(500-Math.floor((500*100)/800))).not.to.be.reverted;

    console.log("requirdLiquidity", await Basket.requirdLiquidity());
    console.log("_ContractFunds", await Basket.contractLockedLiquidity());
    console.log("_ExchangeFunds", await Basket.exchangeLockedLiquidity());
    console.log("_TotalFunds", await Basket.totalLockedFunds());
    console.log("_TotalWithdrawRequestFunds", await Basket.totalWithdrawRequests());
    console.log("totalQueuedFunds", await Basket.totalQueuedFunds());
    console.log("Inv-1 Profit:", await Basket.profits(Inv1), "\t Fund:", await Basket.lockedFunds(Inv1));
    console.log("Inv-2 Profit:", await Basket.profits(Inv2), "\t Fund:", await Basket.lockedFunds(Inv2));
    console.log("Inv-3 Profit:", await Basket.profits(Inv3), "\t Fund:", await Basket.lockedFunds(Inv3));
    console.log("Inv-4 Profit:", await Basket.profits(Inv4), "\t Fund:", await Basket.lockedFunds(Inv4));

    // console.log("total ex funds",await Basket.exchangeLockedLiquidity());
    // requirdLiquidity = 2138
    // _ContractFunds = 0
    // exchangeLockedLiquidity = 700
    // _TotalFunds  = 700
    // _TotalWithdrawRequestFunds = 438
    // totalQueuedFunds = 0
    //  Inv-1     Fund: 88n     Profit: 142n
    //  Inv-2     Fund: 438n    Profit: 713n
    //  Inv-3     Fund: 0n      Profit: 606n
    //  Inv-4     Fund: 175n    Profit: 272n

    // ─── Profit Share 7 ──────────────────────────────────────────

    let RequiredFunds4 = await Basket.profitShareRequiredFund(-200);
    console.log("\n\nrequired Fund 7:", RequiredFunds4);

    await expect(Basket.connect(Trader).profitShare(-200, ethers.encodeBytes32String(""), ethers.encodeBytes32String(""))).to.be.reverted;

    await expect(USDT.connect(Trader).transfer(await Basket.getAddress(), RequiredFunds4)).not.to.be.reverted;
    await expect(Basket.connect(Trader).profitShare(-200, ethers.encodeBytes32String(""), ethers.encodeBytes32String(""))).not.to.be.reverted;


    await expect(await Basket.contractLockedLiquidity()).to.equal(Number(RequiredFunds4) -438 + Math.floor((438*200)/700) ); // 438 withdraw request of user 2
    await expect(await Basket.exchangeLockedLiquidity()).to.equal(700 - 200 - Number(RequiredFunds4) ); // 200 loss
    await expect(await Basket.totalQueuedFunds()).to.equal(0);
    await expect(await Basket.totalWithdrawRequests()).to.equal(0);
    await expect(await Basket.requirdLiquidity()).to.equal(2150 + 438 - Math.floor((438*200)/700) ); // 2150 previous required liquidation

    await expect(await Basket.lockedFunds(Inv1)).to.equal(100-Math.floor((100*100)/800) - Math.floor(((100-Math.floor((100*100)/800))*200)/700));
    await expect(await Basket.lockedFunds(Inv2)).to.equal(0);
    await expect(await Basket.lockedFunds(Inv3)).to.equal(0);
    await expect(await Basket.lockedFunds(Inv4)).to.equal(200-Math.floor((200*100)/800) - Math.floor(((200-Math.floor((200*100)/800))*200)/700));
    await expect(await Basket.totalLockedFunds()).to.equal(800-100-438 + Math.floor((438*200)/700)-200);

    await expect(await Basket.profits(Inv1)).to.equal(Math.floor((100 * (100*0.8)) / 1600) + Math.floor((100 * (500*0.8)) / 1500) + Math.floor((100 * (500*0.8)) / 1500) + Math.floor((100 * (700*0.8)) / 1000));
    await expect(await Basket.profits(Inv2)).to.equal(Math.floor((500 * (100*0.8)) / 1600) + Math.floor((500 * (500*0.8)) / 1500) + Math.floor((500 * (500*0.8)) / 1500) + Math.floor((500 * (700*0.8)) / 1000));
    await expect(await Basket.profits(Inv3)).to.equal(Math.floor((700 * (500*0.8)) / 1500) + Math.floor((700 * (500*0.8)) / 1500) + Math.floor((200 * (700*0.8)) / 1000));
    await expect(await Basket.profits(Inv4)).to.equal(Math.floor((200 * (500*0.8)) / 1500) + Math.floor((200 * (500*0.8)) / 1500) + Math.floor((200 * (700*0.8)) / 1000));

    // should fails if end time passed
    await time.increaseTo(now+48*3600);
    await expect(USDT.connect(Inv1).approve(await Basket.getAddress(),100)).not.to.be.reverted;
    await expect(Basket.connect(Inv1).invest(100, ethers.encodeBytes32String(""))).to.be.reverted;


    console.log(await Basket._profitShares(0));
    console.log(await Basket._profitShares(1));
    console.log(await Basket._profitShares(2));
    console.log(await Basket._profitShares(3));
    console.log(await Basket._profitShares(4));
    console.log(await Basket._profitShares(5));
    console.log(await Basket._profitShares(6));
    console.log(await Basket._profitShares(7));
    // shared profits:
    // - 0
    // - 100
    // - 500
    // - 500
    // - 700
    // - 0
    // - -100
    // - -200
    // total profit : 1800
    // total loss : -300
    // trader fee : 1800*0.15 = 270
    // admin fee : 1800*0.05 = 90
    await expect(await Basket.adminShare()).to.equal(90);
    await expect(await Basket.profits(Trader)).to.equal(270);
  });

  it ("Scenario 2 - close Basket and AdminProfitShares",async ()=>{
    let Assistant:HardhatEthersSigner;
    [Trader,Assistant, Inv1, Inv2, Inv3, Inv4] = await ethers.getSigners();
    let basket = await ethers.getContractFactory("Basket");
    let now = Math.floor(Date.now()/1000);
    let USDT = await CreateUSDT();
    now = now+50*3600
    let Basket = await basket.deploy(100, USDT, Trader,Assistant, 0, 100000, 0, 1500, 500,now,now+100*3600 );
    time.increaseTo(now);
    await time.increaseTo(now);
    async function _invest(Investor: any, amount: number) {
      await expect(USDT.connect(Investor).approve(await Basket.getAddress(), amount)).not.to.be.reverted;
      let msg = await Basket.invest_signatureData(Investor,amount,Math.floor((await time.latest())/300));
      let sig  = await Trader.signMessage(ethers.getBytes(msg));
      await expect(Basket.connect(Investor).invest(amount, sig)).not.to.be.reverted;
    }
    await expect(Basket.connect(Trader).active()).not.to.be.reverted;
    await expect(USDT.connect(Trader).transfer(Assistant,10000)).not.to.be.reverted;
    await _invest(Inv1, 100);
    await _invest(Inv2, 500);
    await _invest(Inv3, 1000);
    expect(await Basket.totalQueuedFunds()).to.equal(1600);

    // ─── Profit Share 0 ──────────────────────────────────────────
    // @ start Time
    await time.increaseTo(now+3*3600);
    await expect(Basket.connect(Trader).profitShare(0, ethers.encodeBytes32String(""), ethers.encodeBytes32String(""))).not.to.be.reverted;

    await expect(await Basket.contractLockedLiquidity()).to.equal(1600);
    await expect(await Basket.exchangeLockedLiquidity()).to.equal(0);
    await expect(await Basket.totalQueuedFunds()).to.equal(0);
    await expect(await Basket.totalWithdrawRequests()).to.equal(0);
    await expect(await Basket.requirdLiquidity()).to.equal(0);

    await expect(await Basket.lockedFunds(Inv1)).to.equal(100);
    await expect(await Basket.lockedFunds(Inv2)).to.equal(500);
    await expect(await Basket.lockedFunds(Inv3)).to.equal(1000);
    await expect(await Basket.totalLockedFunds()).to.equal(1600);

    // withdraw request 300
    await expect(await Basket.connect(Inv3).unlockFundRequest(300));

    // invest 200
    await _invest(Inv4, 200);

    await expect(await Basket.contractLockedLiquidity()).to.equal(1600); // total liquidity
    await expect(await Basket.exchangeLockedLiquidity()).to.equal(0); // no profit or balance share
    await expect(await Basket.totalQueuedFunds()).to.equal(200); // Inv4 invested 200
    await expect(await Basket.totalWithdrawRequests()).to.equal(300); // Inv3 requested 300
    await expect(await Basket.requirdLiquidity()).to.equal(200); // for paying the queued funds

    // ─── Profit Share 1 ──────────────────────────────────────────
    await expect(Basket.connect(Trader).profitShare(100, ethers.encodeBytes32String(""), ethers.encodeBytes32String(""))).not.to.be.reverted;

    await expect(await Basket.contractLockedLiquidity()).to.equal(1600 - 300 + 200 - 100);
    await expect(await Basket.exchangeLockedLiquidity()).to.equal(100);
    // total liquidity 1700
    await expect(await Basket.totalQueuedFunds()).to.equal(0);
    await expect(await Basket.totalWithdrawRequests()).to.equal(0);
    await expect(await Basket.requirdLiquidity()).to.equal(400);

    await expect(await Basket.lockedFunds(Inv1)).to.equal(100);
    await expect(await Basket.lockedFunds(Inv2)).to.equal(500);
    await expect(await Basket.lockedFunds(Inv3)).to.equal(700);
    await expect(await Basket.lockedFunds(Inv4)).to.equal(200);
    await expect(await Basket.totalLockedFunds()).to.equal(1500);

    await expect(await Basket.profits(Inv1)).to.equal(Math.floor((100 / 1600) * (100*0.8)));
    await expect(await Basket.profits(Inv2)).to.equal(Math.floor((500 / 1600) * (100*0.8)));
    await expect(await Basket.profits(Inv3)).to.equal(Math.floor((1000 / 1600) * (100*0.8)));
    await expect(await Basket.profits(Inv4)).to.equal(0);

    await expect(Basket.connect(Inv3)["withdrawFund(uint256)"](300)).not.to.be.reverted;
    await expect(Basket.connect(Inv3)["withdrawProfit(uint256)"](Math.floor((1000 / 1600) * (100*0.8)))).not.to.be.reverted;

    await expect(await Basket.requirdLiquidity()).to.equal(400 - 300 - Math.floor((1000 / 1600) * (100*0.8)));

    // Transfer Fund
    await expect(Basket.connect(Trader).transferFundToExchange(Assistant,400)).not.to.be.reverted;
    await expect(await Basket.contractLockedLiquidity()).to.equal(1000);
    await expect(await Basket.exchangeLockedLiquidity()).to.equal(500);
    
    await expect(USDT.connect(Assistant).transfer(await Basket.getAddress(),500)).not.to.be.reverted;
    await expect(Basket.connect(Trader).transferFundFromExchange(500)).not.to.be.reverted;

    await expect(await Basket.contractLockedLiquidity()).to.equal(1500);
    await expect(await Basket.exchangeLockedLiquidity()).to.equal(0);
    
    let oldBalance = await USDT.balanceOf(await Basket.admin());
    await expect(await Basket.connect(Assistant).adminShareProfit()).not.to.be.reverted;
    await expect(await USDT.balanceOf(await Basket.admin()) - oldBalance).to.equal(5);

    console.log("Inv-1 Profit:", await Basket.profits(Inv1), "\t Fund:", await Basket.lockedFunds(Inv1));
    console.log("Inv-2 Profit:", await Basket.profits(Inv2), "\t Fund:", await Basket.lockedFunds(Inv2));
    console.log("Inv-3 Profit:", await Basket.profits(Inv3), "\t Fund:", await Basket.lockedFunds(Inv3));
    console.log("Inv-4 Profit:", await Basket.profits(Inv4), "\t Fund:", await Basket.lockedFunds(Inv4));
    
    await _invest(Inv2,200);
    await _invest(Inv3,300);

    await expect(Basket.connect(Trader).close()).not.to.be.reverted;
    
    await expect(await Basket.lockedFunds(Inv1)).to.equal(0);
    await expect(await Basket.lockedFunds(Inv2)).to.equal(0);
    await expect(await Basket.lockedFunds(Inv3)).to.equal(0);
    await expect(await Basket.lockedFunds(Inv4)).to.equal(0);
    await expect(await Basket.totalLockedFunds()).to.equal(0);
    await expect(await Basket.totalQueuedFunds()).to.equal(0);
    
    await expect(await Basket.releasedFunds(Inv1)).to.equal(100);
    await expect(await Basket.releasedFunds(Inv2)).to.equal(500+200);
    await expect(await Basket.releasedFunds(Inv3)).to.equal(700+300);
    await expect(await Basket.releasedFunds(Inv4)).to.equal(200);

    // try withdraw reminders funds.
    await expect(USDT.connect(Inv4).transfer(await Basket.getAddress(),1000)).not.to.be.reverted;
    await expect(Basket.connect(Assistant).withdrawReminders(await USDT.getAddress())).not.to.be.reverted;

    await expect(Basket.connect(Inv1)["withdrawFund(uint256)"](100)).not.to.be.reverted;
    await expect(Basket.connect(Inv2)["withdrawFund(uint256)"](700)).not.to.be.reverted;
    await expect(Basket.connect(Inv3)["withdrawFund(uint256)"](1000)).not.to.be.reverted;
    await expect(Basket.connect(Inv4)["withdrawFund(uint256)"](200)).not.to.be.reverted;
    
    await expect(Basket.connect(Trader)["withdrawProfit(uint256)"](await Basket.profits(Trader))).not.to.be.reverted;
    await expect(Basket.connect(Inv1)["withdrawProfit(uint256)"](await Basket.profits(Inv1))).not.to.be.reverted;
    await expect(Basket.connect(Inv2)["withdrawProfit(uint256)"](await Basket.profits(Inv2))).not.to.be.reverted;
    await expect(Basket.connect(Inv3)["withdrawProfit(uint256)"](await Basket.profits(Inv3))).not.to.be.reverted;
    await expect(Basket.connect(Inv4)["withdrawProfit(uint256)"](await Basket.profits(Inv4))).not.to.be.reverted;


    console.log("requirdLiquidity" ,await Basket.requirdLiquidity());
    console.log("basketBalance" ,await USDT.balanceOf(await Basket.getAddress()));
    console.log("contractLockedLiquidity" ,await Basket.contractLockedLiquidity());
    console.log("exchangeLockedLiquidity" ,await Basket.exchangeLockedLiquidity());
    console.log("adminShare" ,await Basket.adminShare());

  });

  it("Scenario 3 - NonZero Trader Fund", async () => {
    [Trader, Inv1, Inv2, Inv3, Inv4] = await ethers.getSigners();
    let basket = await ethers.getContractFactory("Basket");
    let now = Math.floor(Date.now()/1000);
    let USDT = await CreateUSDT();
    let Basket = await basket.connect(Trader).deploy(100, USDT, Trader,Trader, 1000, 100000, 250, 1500, 500,now+1*3600,now+100*3600 );
    time.increaseTo(now+50*3600);

    async function _invest(Investor: any, amount: number) {
      await expect(USDT.connect(Investor).approve(await Basket.getAddress(), amount)).not.to.be.reverted;
      let msg = await Basket.invest_signatureData(Investor,amount,Math.floor((await time.latest())/300));
      let sig  = await Trader.signMessage(ethers.getBytes(msg));
      await expect(Basket.connect(Investor).invest(amount, sig)).not.to.be.reverted;
    }
    
    await expect(Basket.connect(Trader).active()).to.be.reverted;
    await expect(USDT.connect(Inv1).approve(await Basket.getAddress(), 100)).not.to.be.reverted;
    await expect(Basket.connect(Inv1).invest(100, ethers.encodeBytes32String(""))).to.be.reverted; // since basket is not active yet
    
    
    await expect(USDT.connect(Trader).transfer(await Basket.getAddress(), 1000)).not.to.be.reverted;
    await expect(Basket.connect(Trader).active()).not.to.be.reverted;
    
    await _invest(Inv1,2000);
    expect(await Basket.totalQueuedFunds()).to.equal(2000);
    expect(await Basket.totalLockedFunds()).to.equal(1000);
    expect(await Basket.lockedFunds(Trader)).to.equal(1000);
    
    await expect(Basket.connect(Trader)["withdrawFund(uint256)"](100)).to.be.reverted;

  });

  it("Scenario 4 - StartTime,EndTime,Active Status of Basket ", async () => {
    let Assistant:HardhatEthersSigner;
    [Trader,Assistant, Inv1, Inv2, Inv3, Inv4] = await ethers.getSigners();
    let basket = await ethers.getContractFactory("Basket");
    let now = Math.floor(Date.now()/1000);
    let USDT = await CreateUSDT();
    let Basket = await basket.deploy(100, USDT, Trader,Assistant, 1000, 100000, 250, 1500, 500,now+1*3600,now+100*3600 );
    time.increaseTo(now+50*3600);

    async function _invest(Investor: any, amount: number) {
      await expect(USDT.connect(Investor).approve(await Basket.getAddress(), amount)).not.to.be.reverted;
      let msg = await Basket.invest_signatureData(Investor,amount,Math.floor((await time.latest())/300));
      let sig  = await Trader.signMessage(ethers.getBytes(msg));
      await expect(Basket.connect(Investor).invest(amount, sig)).not.to.be.reverted;
    }
    
    await expect(USDT.connect(Trader).transfer(await Basket.getAddress(), 1000)).not.to.be.reverted;
    await expect(Basket.connect(Trader).active()).not.to.be.reverted;

    await _invest(Inv1,2000);
    
    expect(await Basket.totalLockedFunds()).to.equal(1000);
    expect(await Basket.contractLockedLiquidity()).to.equal(1000);
    expect(await Basket.exchangeLockedLiquidity()).to.equal(0);
    expect(await Basket.requirdLiquidity()).to.equal(2000);
    
    await expect(Basket.connect(Assistant).transferFundToExchange(Assistant,400)).not.to.be.reverted;
    
    expect(await Basket.totalLockedFunds()).to.equal(1000);
    expect(await Basket.contractLockedLiquidity()).to.equal(600);
    expect(await Basket.exchangeLockedLiquidity()).to.equal(400);
    expect(await Basket.requirdLiquidity()).to.equal(2000);

    expect(await Basket.totalQueuedFunds()).to.equal(2000);

    await expect(USDT.connect(Assistant).transfer(await Basket.getAddress(), 400)).not.to.be.reverted;
    await expect(Basket.connect(Assistant).transferFundFromExchange(400)).not.to.be.reverted;

    expect(await Basket.totalLockedFunds()).to.equal(1000);
    expect(await Basket.contractLockedLiquidity()).to.equal(1000);
    expect(await Basket.exchangeLockedLiquidity()).to.equal(0);
    expect(await Basket.requirdLiquidity()).to.equal(2000);

    expect(await Basket.totalQueuedFunds()).to.equal(2000);

    
  });

  

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
    let Basket = basket.connect(Trader).deploy(100, baseToken, Trader, Trader, 0, 100000, 250, 1500, 500,now+1*3600,now+24*3600 );
    return Basket;
  }
  

});