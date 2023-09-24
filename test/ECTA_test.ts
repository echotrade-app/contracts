import {
    time,
    loadFixture,
  } from "@nomicfoundation/hardhat-toolbox/network-helpers";
  import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
  import { expect } from "chai";
  import { ethers } from "hardhat";
  import { ContractTransactionResponse } from "ethers";
  import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";

describe("ECTA", async ()=>{
    it("Vesting and Stacking", async ()=>{

        let Inv1:HardhatEthersSigner, Inv2:HardhatEthersSigner, O1:HardhatEthersSigner, O2:HardhatEthersSigner;
        let Other:HardhatEthersSigner;
        [Inv1, Inv2, O1,O2,Other] = await ethers.getSigners();
        let token = await ethers.getContractFactory("ECTA");
        let now = await time.latest();
        let decimalFactor = 10**6;
        let ECTA = await token.connect(Inv1).deploy(
            [
                {_address:Inv1,_share:50000000,_releaseDuration:3600,_startReleaseAt:now+60},
                {_address:Inv2,_share:50000000,_releaseDuration:0,_startReleaseAt:0},
            ]
        );
        
        // Time : 0
        await expect(ECTA.connect(Inv1).transfer(Other,1)).to.be.reverted;
        await expect(ECTA.connect(Inv2).transfer(Other,1*decimalFactor)).not.to.be.reverted;
            
        await expect(await ECTA.balanceOf(Inv1)).to.be.equal(50_000_000*decimalFactor);
        await expect(await ECTA.balanceOf(Other)).to.be.equal(1*decimalFactor);
        await expect(await ECTA.balanceOf(Inv2)).to.be.equal((50_000_000-1)*decimalFactor);
        
        await expect(ECTA.connect(Inv2).stake(10000)).to.be.reverted;
        await expect(ECTA.connect(Inv2).stake(100_000*decimalFactor)).not.to.be.reverted;
        await expect(await ECTA.locked(Inv2)).to.equal(100_000*decimalFactor);
        
        await expect(ECTA.connect(Inv1).stake(100_000*decimalFactor)).not.to.be.reverted;
        await expect(await ECTA.locked(Inv1)).to.equal(100_000*decimalFactor);
        
        await expect(ECTA.connect(Inv2).transfer(Other,99_999*decimalFactor)).not.to.be.reverted;
        await expect(ECTA.connect(Other).stake(100_000*decimalFactor)).not.to.be.reverted;
        let capBalance = await ECTA.balanceOf(Inv2);
        await expect(ECTA.connect(Inv2).transfer(Other,capBalance)).to.be.reverted;

        // time : 100+3600/2 - start
        await time.increaseTo(now+100+3600/2);

        await expect(ECTA.connect(Inv1).transfer(Other,Number(await ECTA.balanceOf(Inv1))/2)).not.to.be.reverted;
        await expect(await ECTA.balanceOf(Inv1)).to.equal((50_000_000/2)*decimalFactor);
        await expect(await ECTA.locked(Inv1)).to.equal(100_000*decimalFactor);

        await expect(ECTA.connect(Inv1).transfer(Other,Number(await ECTA.balanceOf(Inv1))/2)).to.be.reverted;

    }) 

    it("Baskets", async () => {
        let Inv1:HardhatEthersSigner, Inv2:HardhatEthersSigner, O1:HardhatEthersSigner, O2:HardhatEthersSigner;
        let Other:HardhatEthersSigner;
        let token = await ethers.getContractFactory("ECTA");
        let now = await time.latest();
        let decimalFactor = 10**6;
        [Inv1, Inv2, O1,O2,Other] = await ethers.getSigners();
        let ECTA = await token.connect(Inv1).deploy(
            [
                {_address:Inv1,_share:50000000,_releaseDuration:3600,_startReleaseAt:now+60},
                {_address:Inv2,_share:50000000,_releaseDuration:0,_startReleaseAt:0},
            ]
        );
        await expect(ECTA.connect(Inv1).stake(5_000_000*decimalFactor)).not.to.be.reverted;
        await expect(ECTA.connect(Inv2).stake(5_000_000*decimalFactor)).not.to.be.reverted;

        let usdt = await ethers.getContractFactory("USDT");
        let USDT = await usdt.deploy("USDT", "USDT", 2,await time.latest()-100,1);
        await expect(USDT.connect(Inv1).transfer(Inv2, 10000)).not.to.be.reverted;
        await expect(USDT.connect(Inv1).transfer(Other, 10000)).not.to.be.reverted;
        
        let basket = await ethers.getContractFactory("Basket");
        let Basket = await basket.deploy(100, await USDT.getAddress(), Other,await ECTA.getAddress(), 0, 100000, 0, 1500, 500,now,now+24*3600 );
        
        await expect(Basket.connect(Other).active()).not.to.be.reverted;
        
        async function _invest(Investor: any, amount: number) {
            await expect(USDT.connect(Investor).approve(await Basket.getAddress(), amount)).not.to.be.reverted;
            let msg = await Basket.invest_signatureData(Investor,amount,Math.floor((await time.latest())/300));
            let sig  = await Inv2.signMessage(ethers.getBytes(msg));
            await expect(Basket.connect(Investor).invest(amount, sig)).not.to.be.reverted;
        }
        
        await expect(ECTA.addBasket(await Basket.getAddress())).not.to.be.reverted;
        await expect(ECTA.connect(Inv1).setAssistant(0,Inv2)).not.to.be.reverted;

        await _invest(Inv2,10000);
        await expect(Basket.connect(Other).profitShare(10000, ethers.encodeBytes32String(""), ethers.encodeBytes32String(""))).not.to.be.reverted;

        await expect(ECTA.connect(Other).gatherProfits([0])).not.to.be.reverted;

        await expect(await ECTA.withdrawableProfit(Inv1,await USDT.getAddress())).to.equal(250);
        let CompanyUSDTBalance = await USDT.balanceOf(Inv1);
        await expect(ECTA.connect(Inv1)["withdrawProfit(address)"](await USDT.getAddress())).not.to.be.reverted;
        await expect(await USDT.balanceOf(Inv1)).to.equal(Number(CompanyUSDTBalance)+250);

        await expect(ECTA.connect(Other).removeBasket(0)).to.be.reverted;

        await expect(USDT.connect(Other).transfer(await Basket.getAddress(),await Basket.exchangeLockedLiquidity())).not.to.be.reverted;
        await expect(Basket.connect(Inv2).transferFundFromExchange(await Basket.exchangeLockedLiquidity())).not.to.be.reverted;
        await expect(Basket.connect(Other).close()).not.to.be.reverted;

        console.log(await ECTA.baskets(0));
        await expect(ECTA.connect(Inv1).removeBasket(0)).not.to.be.reverted;
    })

    it("Staking and ProfitShares", async () => {
        
        let Inv1:HardhatEthersSigner, Inv2:HardhatEthersSigner, Bank:HardhatEthersSigner;
        [Inv1, Inv2, Bank] = await ethers.getSigners();
        let token = await ethers.getContractFactory("ECTA");
        let now = await time.latest();
        let decimalFactor = 10**6;
        let ECTA = await token.connect(Inv1).deploy(
            [
                {_address:Inv1,_share:50000000,_releaseDuration:3600,_startReleaseAt:now+60},
                {_address:Inv2,_share:50000000,_releaseDuration:0,_startReleaseAt:0},
            ]
        );

        await expect(ECTA.connect(Inv1).stake(2_000_000*decimalFactor)).not.to.be.reverted;
        await expect(ECTA.connect(Inv1)["widthrawReleased()"]()).to.be.reverted;
        await expect(ECTA.connect(Inv1).unstake(10_000_000*decimalFactor)).to.be.reverted;
        await expect(ECTA.connect(Inv1)["widthrawReleased()"]()).to.be.reverted;

        await expect(ECTA.connect(Inv2).stake(8_000_000*decimalFactor)).not.to.be.reverted;
        
        let usdt = await ethers.getContractFactory("USDT");
        let USDT = await usdt.connect(Bank).deploy("USDT", "USDT", 2,await time.latest()-100,1);
        
        await expect(USDT.connect(Bank).transfer(Inv2, 10000)).not.to.be.reverted;
        //transfer USDT to ECTA as profit
        await expect(USDT.connect(Bank).transfer(await ECTA.getAddress(),10000)).not.to.be.reverted;

        await expect(ECTA.connect(Bank).profitShareBalance(await USDT.getAddress(),10000)).not.to.be.reverted;
        expect(await ECTA.withdrawableProfit(Inv1,await USDT.getAddress())).to.equal(2000);
        console.log("Inv2-Profit:",await ECTA.withdrawableProfit(Inv2,await USDT.getAddress()))
        await expect(ECTA.connect(Inv1)["withdrawProfit(address)"](await USDT.getAddress())).not.to.be.reverted;
        expect(await USDT.balanceOf(Inv1)).to.equal(2000);

        await expect(ECTA.connect(Inv1).stake(48_000_000*decimalFactor)).not.to.be.reverted;
        await expect(ECTA.connect(Inv1).stake(1_000_000*decimalFactor)).to.be.reverted;
        
        await expect(ECTA.connect(Inv1).transfer(Bank,1*decimalFactor)).to.be.reverted;
        await expect(ECTA.connect(Inv1).unstake(10_000_000*decimalFactor)).not.to.be.reverted;
        time.increase(await time.latest()+1*24*3600);
        await expect(ECTA.connect(Inv1).unstake(10_000_000*decimalFactor)).not.to.be.reverted;
        time.increase(await time.latest()+1*24*3600);
        await expect(ECTA.connect(Inv1).unstake(10_000_000*decimalFactor)).not.to.be.reverted;
        await expect(ECTA.connect(Inv1).transfer(Bank,1)).to.be.reverted;
        
        
        console.log("Inv1: remaining Stacked",await ECTA.stacked(Inv1));
        console.log("Inv1: UnlockRequest Stacked",await ECTA.getTotalUnlockedRequests(Inv1));
        await expect(ECTA.connect(Inv1).unstake(20_000_000*decimalFactor)).not.to.be.reverted;
        await expect(ECTA.connect(Inv1).unstake(10_000_000*decimalFactor)).to.be.reverted;
        
        await expect(USDT.connect(Bank).approve(await ECTA.getAddress(),10000)).not.to.be.reverted;
        await expect(ECTA.connect(Bank)["profitShareApproved(address,uint256,address)"](await USDT.getAddress(),10000,Bank)).not.to.be.reverted;
        
        expect(await ECTA.withdrawableProfit(Inv2,await USDT.getAddress())).to.equal(10000+8000);

        // 14 days later
        time.increase(await time.latest()+15*24*3600);
        await expect(ECTA.connect(Inv1).transfer(Bank,1*decimalFactor)).to.be.reverted;
        await expect(ECTA.connect(Inv1).stake(1_000_000*decimalFactor)).to.be.reverted;
        
        await expect(ECTA.connect(Inv1)["widthrawReleased()"]()).not.to.be.reverted;
        await expect(ECTA.connect(Inv1).transfer(Bank,1*decimalFactor)).not.to.be.reverted;
        await expect(ECTA.connect(Inv1).stake(28_000_000*decimalFactor)).not.to.be.reverted;
        await expect(ECTA.connect(Inv1)["widthrawReleased()"]()).to.be.reverted;
        
        

        
    })
})