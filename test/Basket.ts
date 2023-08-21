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

  it("Scenario-1",async ()=> {
    [Trader, Inv1, Inv2, Inv3, Inv4] = await ethers.getSigners();
    let USDT = await CreateUSDT();
    let Basket = await CreateBasket(await USDT.getAddress());
    console.log(await USDT.getAddress());
    console.log(await Basket.getAddress());

    async function _invest(Investor: any, amount: number) {
      await expect(USDT.connect(Investor).approve(await Basket.getAddress(), amount)).not.to.be.reverted;
      await expect(Basket.connect(Investor).invest(amount, ethers.encodeBytes32String(""))).not.to.be.reverted;
    }
    await expect(Basket.connect(Trader).active()).not.to.be.reverted;
    await _invest(Inv1, 100);
    await _invest(Inv2, 500);
    await _invest(Inv3, 1000);
    expect(await Basket._totalQueuedFunds()).to.equal(1600);

    // ─── Profit Share 0 ──────────────────────────────────────────
    await expect(await Basket.connect(Trader).profitShare(0, ethers.encodeBytes32String(""), ethers.encodeBytes32String(""))).not.to.be.reverted;

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
    await _invest(Inv4, 200);

    await expect(await Basket._inContractLockedLiquidity()).to.equal(1600); // total liquidity
    await expect(await Basket._exchangeLockedLiquidity()).to.equal(0); // no profit or balance share
    await expect(await Basket._totalQueuedFunds()).to.equal(200); // Inv4 invested 200
    await expect(await Basket._totalWithdrawRequests()).to.equal(300); // Inv3 requested 300
    await expect(await Basket._requirdLiquidity()).to.equal(200); // for paying the queued funds

    // ─── Profit Share 1 ──────────────────────────────────────────
    await expect(await Basket.connect(Trader).profitShare(100, ethers.encodeBytes32String(""), ethers.encodeBytes32String(""))).not.to.be.reverted;

    await expect(await Basket._inContractLockedLiquidity()).to.equal(1600 - 300 + 200 - 100);
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

    await expect(await Basket._profits(Inv1)).to.equal(Math.floor((100 / 1600) * 100));
    await expect(await Basket._profits(Inv2)).to.equal(Math.floor((500 / 1600) * 100));
    await expect(await Basket._profits(Inv3)).to.equal(Math.floor((1000 / 1600) * 100));
    await expect(await Basket._profits(Inv4)).to.equal(0);

    await expect(await Basket.connect(Inv3)["withdrawFund(uint256)"](300)).not.to.be.reverted;
    await expect(await Basket.connect(Inv3)["withdrawProfit(uint256)"](Math.floor((1000 / 1600) * 100))).not.to.be.reverted;

    await expect(await Basket._requirdLiquidity()).to.equal(400 - 300 - Math.floor((1000 / 1600) * 100));

    // ─── Profit Share 2 ──────────────────────────────────────────

    await expect(await Basket.connect(Trader).profitShare(500, ethers.encodeBytes32String(""), ethers.encodeBytes32String(""))).not.to.be.reverted;
    // console.log(await Basket.connect(Trader).profitShare(500,ethers.encodeBytes32String(""),ethers.encodeBytes32String("")));

    await expect(await Basket._inContractLockedLiquidity()).to.equal(1600 - 300 + 200 - 100 - 500);
    await expect(await Basket._exchangeLockedLiquidity()).to.equal(100 + 500);
    await expect(await Basket._totalQueuedFunds()).to.equal(0);
    await expect(await Basket._totalWithdrawRequests()).to.equal(0);
    await expect(await Basket._requirdLiquidity()).to.equal(400 - 300 - Math.floor((1000 / 1600) * 100) + 500);

    await expect(await Basket.lockedFunds(Inv1)).to.equal(100);
    await expect(await Basket.lockedFunds(Inv2)).to.equal(500);
    await expect(await Basket.lockedFunds(Inv3)).to.equal(700);
    await expect(await Basket.lockedFunds(Inv4)).to.equal(200);
    await expect(await Basket.totalLockedFunds()).to.equal(1500);

    await expect(await Basket._profits(Inv1)).to.equal(Math.floor((100 * 100) / 1600) + Math.floor((100 * 500) / 1500));
    await expect(await Basket._profits(Inv2)).to.equal(Math.floor((500 * 100) / 1600) + Math.floor((500 * 500) / 1500));
    await expect(await Basket._profits(Inv3)).to.equal(Math.floor((700 * 500) / 1500));
    await expect(await Basket._profits(Inv4)).to.equal(Math.floor((200 * 500) / 1500));

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
    console.log("\n\nrequired Fund:", RequiredFunds);

    await expect(Basket.connect(Trader).profitShare(500, ethers.encodeBytes32String(""), ethers.encodeBytes32String(""))).to.be.reverted;
    await expect(Basket.connect(Trader).profitShare(500000, ethers.encodeBytes32String(""), ethers.encodeBytes32String(""))).to.be.reverted;

    await expect(USDT.connect(Trader).transfer(await Basket.getAddress(), RequiredFunds)).not.to.be.reverted;
    await expect(Basket.connect(Trader).profitShare(500, ethers.encodeBytes32String(""), ethers.encodeBytes32String(""))).not.to.be.reverted;

    await expect(await Basket._inContractLockedLiquidity()).to.equal(1600 - 300 + 200 - 100 - 500 - 500 - 500 + Number(RequiredFunds));
    await expect(await Basket._exchangeLockedLiquidity()).to.equal(100 + 500 + 500 - Number(RequiredFunds));
    await expect(await Basket._totalQueuedFunds()).to.equal(0);
    await expect(await Basket._totalWithdrawRequests()).to.equal(0);
    await expect(await Basket._requirdLiquidity()).to.equal(400 - 300 - Math.floor((1000 / 1600) * 100) + 500 + 500 + 500);

    await expect(await Basket.lockedFunds(Inv1)).to.equal(100);
    await expect(await Basket.lockedFunds(Inv2)).to.equal(500);
    await expect(await Basket.lockedFunds(Inv3)).to.equal(200);
    await expect(await Basket.lockedFunds(Inv4)).to.equal(200);
    await expect(await Basket.totalLockedFunds()).to.equal(1000);

    await expect(await Basket._profits(Inv1)).to.equal(Math.floor((100 * 100) / 1600) + Math.floor((100 * 500) / 1500) + Math.floor((100 * 500) / 1500));
    await expect(await Basket._profits(Inv2)).to.equal(Math.floor((500 * 100) / 1600) + Math.floor((500 * 500) / 1500) + Math.floor((500 * 500) / 1500));
    await expect(await Basket._profits(Inv3)).to.equal(Math.floor((700 * 500) / 1500) + Math.floor((700 * 500) / 1500));
    await expect(await Basket._profits(Inv4)).to.equal(Math.floor((200 * 500) / 1500) + Math.floor((200 * 500) / 1500));

    // ─── Profit Share 4 ──────────────────────────────────────────

    await expect(Basket.connect(Trader).profitShare(700, ethers.encodeBytes32String(""), ethers.encodeBytes32String(""))).to.be.reverted;
    await expect(Basket.connect(Trader).profitShare(1000, ethers.encodeBytes32String(""), ethers.encodeBytes32String(""))).to.be.reverted;
    let RequiredFunds2 = await Basket.profitShareRequiredFund(700);
    console.log("\n\nrequired Fund:", RequiredFunds2);

    await expect(USDT.connect(Trader).transfer(await Basket.getAddress(), RequiredFunds2)).not.to.be.reverted;
    await expect(Basket.connect(Trader).profitShare(700, ethers.encodeBytes32String(""), ethers.encodeBytes32String(""))).not.to.be.reverted;

    console.log("_requirdLiquidity", await Basket._requirdLiquidity());

    await expect(await Basket._inContractLockedLiquidity()).to.equal(1600 - 300 + 200 - 100 - 500 - 500 - 500 + Number(RequiredFunds) - 700 + Number(RequiredFunds2));
    await expect(await Basket._exchangeLockedLiquidity()).to.equal(100 + 500 + 500 - Number(RequiredFunds) + 700 - Number(RequiredFunds2));
    await expect(await Basket._totalQueuedFunds()).to.equal(0);
    await expect(await Basket._totalWithdrawRequests()).to.equal(0);
    await expect(await Basket._requirdLiquidity()).to.equal(400 - 300 - Math.floor((1000 / 1600) * 100) + 500 + 500 + 500 + 700);

    await expect(await Basket.lockedFunds(Inv1)).to.equal(100);
    await expect(await Basket.lockedFunds(Inv2)).to.equal(500);
    await expect(await Basket.lockedFunds(Inv3)).to.equal(200);
    await expect(await Basket.lockedFunds(Inv4)).to.equal(200);
    await expect(await Basket.totalLockedFunds()).to.equal(1000);

    await expect(await Basket._profits(Inv1)).to.equal(Math.floor((100 * 100) / 1600) + Math.floor((100 * 500) / 1500) + Math.floor((100 * 500) / 1500) + Math.floor((100 * 700) / 1000));
    await expect(await Basket._profits(Inv2)).to.equal(Math.floor((500 * 100) / 1600) + Math.floor((500 * 500) / 1500) + Math.floor((500 * 500) / 1500) + Math.floor((500 * 700) / 1000));
    await expect(await Basket._profits(Inv3)).to.equal(Math.floor((700 * 500) / 1500) + Math.floor((700 * 500) / 1500) + Math.floor((200 * 700) / 1000));
    await expect(await Basket._profits(Inv4)).to.equal(Math.floor((200 * 500) / 1500) + Math.floor((200 * 500) / 1500) + Math.floor((200 * 700) / 1000));

    await expect(Basket.connect(Inv3).withdrawFundRequest(200)).not.to.be.reverted;

    // ─── Profit Share 5 ──────────────────────────────────────────

    await expect(Basket.connect(Trader).profitShare(0, ethers.encodeBytes32String(""), ethers.encodeBytes32String(""))).to.be.reverted;
    let RequiredFunds3 = await Basket.profitShareRequiredFund(0);
    console.log("\n\nrequired Fund:", RequiredFunds3);

    await expect(USDT.connect(Trader).transfer(await Basket.getAddress(), RequiredFunds3)).not.to.be.reverted;
    await expect(Basket.connect(Trader).profitShare(0, ethers.encodeBytes32String(""), ethers.encodeBytes32String(""))).not.to.be.reverted;

    await expect(await Basket._inContractLockedLiquidity()).to.equal(1600 - 300 + 200 - 100 - 500 - 500 - 500 + Number(RequiredFunds) - 700 + Number(RequiredFunds2) - 200 + Number(RequiredFunds3));
    await expect(await Basket._exchangeLockedLiquidity()).to.equal(100 + 500 + 500 - Number(RequiredFunds) + 700 - Number(RequiredFunds2) - Number(RequiredFunds3));
    await expect(await Basket._totalQueuedFunds()).to.equal(0);
    await expect(await Basket._totalWithdrawRequests()).to.equal(0);
    await expect(await Basket._requirdLiquidity()).to.equal(400 - 300 - Math.floor((1000 / 1600) * 100) + 500 + 500 + 500 + 700 + 200);

    await expect(await Basket.lockedFunds(Inv1)).to.equal(100);
    await expect(await Basket.lockedFunds(Inv2)).to.equal(500);
    await expect(await Basket.lockedFunds(Inv3)).to.equal(0);
    await expect(await Basket.lockedFunds(Inv4)).to.equal(200);
    await expect(await Basket.totalLockedFunds()).to.equal(800);

    await expect(await Basket._profits(Inv1)).to.equal(Math.floor((100 * 100) / 1600) + Math.floor((100 * 500) / 1500) + Math.floor((100 * 500) / 1500) + Math.floor((100 * 700) / 1000));
    await expect(await Basket._profits(Inv2)).to.equal(Math.floor((500 * 100) / 1600) + Math.floor((500 * 500) / 1500) + Math.floor((500 * 500) / 1500) + Math.floor((500 * 700) / 1000));
    await expect(await Basket._profits(Inv3)).to.equal(Math.floor((700 * 500) / 1500) + Math.floor((700 * 500) / 1500) + Math.floor((200 * 700) / 1000));
    await expect(await Basket._profits(Inv4)).to.equal(Math.floor((200 * 500) / 1500) + Math.floor((200 * 500) / 1500) + Math.floor((200 * 700) / 1000));

    await expect(await Basket.connect(Inv3)["withdrawFund(uint256)"](300)).not.to.be.reverted;
    
        
    // ─── Profit Share 6 ──────────────────────────────────────────
    // lost 100
    await expect(Basket.connect(Trader).profitShare(-100, ethers.encodeBytes32String(""), ethers.encodeBytes32String(""))).not.to.be.reverted;

    await expect(await Basket._inContractLockedLiquidity()).to.equal(1600 - 300 + 200 - 100 - 500 - 500 - 500 + Number(RequiredFunds) - 700 + Number(RequiredFunds2) - 200 + Number(RequiredFunds3));
    await expect(await Basket._exchangeLockedLiquidity()).to.equal(100 + 500 + 500 - Number(RequiredFunds) + 700 - Number(RequiredFunds2) - Number(RequiredFunds3)-100);
    await expect(await Basket._totalQueuedFunds()).to.equal(0);
    await expect(await Basket._totalWithdrawRequests()).to.equal(0);
    await expect(await Basket._requirdLiquidity()).to.equal(400 - 300 - Math.floor((1000 / 1600) * 100) + 500 + 500 + 500 + 700 + 200-300);

    await expect(await Basket.lockedFunds(Inv1)).to.equal(100-Math.floor((100*100)/800));
    await expect(await Basket.lockedFunds(Inv2)).to.equal(500-Math.floor((500*100)/800));
    await expect(await Basket.lockedFunds(Inv3)).to.equal(0);
    await expect(await Basket.lockedFunds(Inv4)).to.equal(200-Math.floor((200*100)/800));
    await expect(await Basket.totalLockedFunds()).to.equal(800-100);

    await expect(await Basket._profits(Inv1)).to.equal(Math.floor((100 * 100) / 1600) + Math.floor((100 * 500) / 1500) + Math.floor((100 * 500) / 1500) + Math.floor((100 * 700) / 1000));
    await expect(await Basket._profits(Inv2)).to.equal(Math.floor((500 * 100) / 1600) + Math.floor((500 * 500) / 1500) + Math.floor((500 * 500) / 1500) + Math.floor((500 * 700) / 1000));
    await expect(await Basket._profits(Inv3)).to.equal(Math.floor((700 * 500) / 1500) + Math.floor((700 * 500) / 1500) + Math.floor((200 * 700) / 1000));
    await expect(await Basket._profits(Inv4)).to.equal(Math.floor((200 * 500) / 1500) + Math.floor((200 * 500) / 1500) + Math.floor((200 * 700) / 1000));

    // Inv2 withdraw all of his money
    await expect(await Basket.connect(Inv2).withdrawFundRequest(500-Math.floor((500*100)/800))).not.to.be.reverted;

    console.log("_requirdLiquidity", await Basket._requirdLiquidity());
    console.log("_ContractFunds", await Basket._inContractLockedLiquidity());
    console.log("_ExchangeFunds", await Basket._exchangeLockedLiquidity());
    console.log("_TotalFunds", await Basket.totalLockedFunds());
    console.log("_TotalWithdrawRequestFunds", await Basket._totalWithdrawRequests());
    console.log("_TotalQueuedFunds", await Basket._totalQueuedFunds());
    console.log("Inv-1 Profit:", await Basket._profits(Inv1), "\t Fund:", await Basket.lockedFunds(Inv1));
    console.log("Inv-2 Profit:", await Basket._profits(Inv2), "\t Fund:", await Basket.lockedFunds(Inv2));
    console.log("Inv-3 Profit:", await Basket._profits(Inv3), "\t Fund:", await Basket.lockedFunds(Inv3));
    console.log("Inv-4 Profit:", await Basket._profits(Inv4), "\t Fund:", await Basket.lockedFunds(Inv4));

    // console.log("total ex funds",await Basket._exchangeLockedLiquidity());
    // _requirdLiquidity = 2138
    // _ContractFunds = 0
    // _exchangeLockedLiquidity = 700
    // _TotalFunds  = 700
    // _TotalWithdrawRequestFunds = 438
    // _TotalQueuedFunds = 0
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


    await expect(await Basket._inContractLockedLiquidity()).to.equal(Number(RequiredFunds4) -438 + Math.floor((438*200)/700) ); // 438 withdraw request of user 2
    await expect(await Basket._exchangeLockedLiquidity()).to.equal(700 - 200 - Number(RequiredFunds4) ); // 200 loss
    await expect(await Basket._totalQueuedFunds()).to.equal(0);
    await expect(await Basket._totalWithdrawRequests()).to.equal(0);
    await expect(await Basket._requirdLiquidity()).to.equal(2138 + 438 - Math.floor((438*200)/700) );

    await expect(await Basket.lockedFunds(Inv1)).to.equal(100-Math.floor((100*100)/800) - Math.floor(((100-Math.floor((100*100)/800))*200)/700));
    await expect(await Basket.lockedFunds(Inv2)).to.equal(0);
    await expect(await Basket.lockedFunds(Inv3)).to.equal(0);
    await expect(await Basket.lockedFunds(Inv4)).to.equal(200-Math.floor((200*100)/800) - Math.floor(((200-Math.floor((200*100)/800))*200)/700));
    await expect(await Basket.totalLockedFunds()).to.equal(800-100-438 + Math.floor((438*200)/700)-200);

    await expect(await Basket._profits(Inv1)).to.equal(Math.floor((100 * 100) / 1600) + Math.floor((100 * 500) / 1500) + Math.floor((100 * 500) / 1500) + Math.floor((100 * 700) / 1000));
    await expect(await Basket._profits(Inv2)).to.equal(Math.floor((500 * 100) / 1600) + Math.floor((500 * 500) / 1500) + Math.floor((500 * 500) / 1500) + Math.floor((500 * 700) / 1000));
    await expect(await Basket._profits(Inv3)).to.equal(Math.floor((700 * 500) / 1500) + Math.floor((700 * 500) / 1500) + Math.floor((200 * 700) / 1000));
    await expect(await Basket._profits(Inv4)).to.equal(Math.floor((200 * 500) / 1500) + Math.floor((200 * 500) / 1500) + Math.floor((200 * 700) / 1000));

  })

  async function CreateUSDT() {
    let usdt = await ethers.getContractFactory("Token");
    let USDT = await usdt.deploy("USDT", "USDT", 2);
    expect(USDT.connect(Trader).transfer(Inv1, 10000)).not.to.be.reverted;
    expect(USDT.connect(Trader).transfer(Inv2, 10000)).not.to.be.reverted;
    expect(USDT.connect(Trader).transfer(Inv3, 10000)).not.to.be.reverted;
    expect(USDT.connect(Trader).transfer(Inv4, 10000)).not.to.be.reverted;
    return USDT;
  }

  async function CreateBasket(baseToken: any) {
    let basket = await ethers.getContractFactory("Basket");
    let Basket = basket.deploy(baseToken, 0);
    return Basket;
  }
  

});