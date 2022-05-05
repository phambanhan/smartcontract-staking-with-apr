const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("staking", function () {
    let [admin, stake1, stake2] = []
    let reserve
    let gold
    let staking
    let defaulFeeRate = 10
    let defaulFeeDecimal = 0
    let minStaking = ethers.utils.parseEther("100")
    let defaulBalance = ethers.utils.parseEther("10000")
    let address0 = "0x0000000000000000000000000000000000000000"
    const oneDay = 24 * 60 * 60;
    const defaultLockTime = Math.floor(Date.now() / 1000) + oneDay;
    beforeEach(async () => {
        [admin, stake1, stake2] = await ethers.getSigners();
        const Gold = await ethers.getContractFactory("Gold");
        gold = await Gold.deploy()
        await gold.deployed()

        const Reserve = await ethers.getContractFactory("StakingReserve");
        reserve = await Reserve.deploy(gold.address)
        await reserve.deployed()
        await gold.transfer(reserve.address, defaulBalance)

        const Staking = await ethers.getContractFactory("Staking");
        staking = await Staking.deploy(gold.address, reserve.address)
        await staking.deployed()
        await staking.addStakePackage(defaulFeeRate, defaulFeeDecimal, minStaking, defaultLockTime)    

        await reserve.setStakeAdress(staking.address)
    })
    describe("common", function () {
        it("feeDecimal should return correct value", async function () {
            const stakePackage =await staking.getStakePackage(1);
            expect(stakePackage.decimal).to.be.equal(defaulFeeDecimal)
        });
        it("feeRate should return correct value", async function () {
            const stakePackage =await staking.getStakePackage(1);
            expect(stakePackage.rate).to.be.equal(defaulFeeRate)
        });
        it("minStaking should return correct value", async function () {
            const stakePackage =await staking.getStakePackage(1);
            expect(stakePackage.minStaking).to.be.equal(minStaking)
        });
        it("lockTime should return correct value", async function () {
            const stakePackage =await staking.getStakePackage(1);
            expect(stakePackage.lockTime).to.be.equal(defaultLockTime)
        });
    })
    describe("stake", function () {
        it("stake should revert if amount = 0", async function () {
            await expect(staking.stake(0, 1))
            .to.be.revertedWith("Staking: Amount must be greater than 0")
        });

        it("stake should revert if amount < minStake", async function () {
            await expect(staking.stake(ethers.utils.parseEther("99"), 1))
            .to.be.revertedWith("Staking: amount invalid")
        });

        it("stake should revert if packageId is not exists", async function () {
            await expect(staking.stake(ethers.utils.parseEther("100"), 2))
            .to.be.revertedWith("Staking: package not exists")
        });

        it("stake should revert if allowance invalid", async function () {
            await expect(staking.stake(ethers.utils.parseEther("100"), 1))
            .to.be.revertedWith("Staking: allowance invalid")
        });

        it("stake should be successfull", async function () {
            await gold.approve(staking.address, ethers.utils.parseEther("100"))
            let tx = await staking.stake(ethers.utils.parseEther("100"), 1);
            await expect(tx).to.be.emit(staking, "StakeUpdate")
                .withArgs(admin.address, 1, ethers.utils.parseEther("100"), "0");
        });
    })
    describe("unstake", function () {
        it("unstake should revert if packageId is not exists", async function () {
            await expect(staking.unStake(2))
            .to.be.revertedWith("Staking: package not exists")
        });

        it("unstake should revert if package still locked", async function () {
            await expect(staking.unStake(1))
            .to.be.revertedWith("Staking: package is still locked")
        });

        it("unstake should revert if user do not have any stake", async function () {
            await network.provider.send("evm_increaseTime", [oneDay+1]);
            await ethers.provider.send("evm_mine", []);
            await expect(staking.connect(stake1).unStake(1))
            .to.be.revertedWith("Staking: user amount must be greater than zero")
        });

        it("calculateProfit one day should be correctly", async function () {
            await gold.approve(staking.address, ethers.utils.parseEther("100"))
            let tx = await staking.stake(ethers.utils.parseEther("100"), 1);
            await expect(tx).to.be.emit(staking, "StakeUpdate")
                .withArgs(admin.address, 1, ethers.utils.parseEther("100"), "0");

            await network.provider.send("evm_increaseTime", [oneDay+1]);
            await ethers.provider.send("evm_mine", []);

            const profit = await staking.calculateProfit(1);
            const profitExpect = 1 * 100/365 * 0.1;
            expect(profit).to.be.equal(ethers.utils.parseEther(profitExpect.toString()))
        });

        it("unstake profit one day should be correctly", async function () {
            await gold.approve(staking.address, ethers.utils.parseEther("100"))
            let tx = await staking.stake(ethers.utils.parseEther("100"), 1);
            await expect(tx).to.be.emit(staking, "StakeUpdate")
                .withArgs(admin.address, 1, ethers.utils.parseEther("100"), "0");

            await network.provider.send("evm_increaseTime", [oneDay+1]);
            await ethers.provider.send("evm_mine", []);

            const txUnStake = await staking.unStake(1);
            const profitExpect = 1 * 100/365 * 0.1;
            await expect(txUnStake).to.be.emit(staking, "StakeReleased")
                .withArgs(admin.address, 1, ethers.utils.parseEther("100"), ethers.utils.parseEther(profitExpect.toString()));
        });
    })
})