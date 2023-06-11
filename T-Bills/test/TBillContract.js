// Test script for TBillContract.sol
const helpers = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");

const DAY = 86400;
const INTEREST_RATE_UNIT = 10 ** 6;

describe("TBillContract", function () {
  it("Should return correct constants", async function () {
    const [interestFund] = await ethers.getSigners();
    const spotTokenContract = await ethers.deployContract("SpotTokenContract");
    const tbillContract = await ethers.deployContract("TBillContract", [interestFund.address, spotTokenContract.address]);

    expect(await tbillContract.interestRateDecimals()).to.equal(6);
    expect(await tbillContract.interestFundAddress()).to.equal(interestFund.address);
    expect(await tbillContract.getERC20TokenAddress()).to.equal(spotTokenContract.address);
    expect(await tbillContract.getTotalLockedTokens()).to.equal(0);
    expect(await tbillContract.getInterestPolicies()).to.be.empty;
    expect(await tbillContract.getInterestFundBalance()).to.equal(0);
  });

  it("Should add interest policy", async function () {
    const [interestFund] = await ethers.getSigners();
    const spotTokenContract = await ethers.deployContract("SpotTokenContract");
    const tbillContract = await ethers.deployContract("TBillContract", [interestFund.address, spotTokenContract.address]);
    let policies;

    await tbillContract.setInterestRate(DAY, 100000);
    policies = await tbillContract.getInterestPolicies();
    expect(policies).to.have.lengthOf(1);
    expect(policies[0].period).to.equal(DAY);
    expect(policies[0].interestRate).to.equal(100000);

    await tbillContract.setInterestRate(DAY, 200000);
    policies = await tbillContract.getInterestPolicies();
    expect(policies).to.have.lengthOf(1);
    expect(policies[0].period).to.equal(DAY);
    expect(policies[0].interestRate).to.equal(200000);

    await tbillContract.setInterestRate(DAY * 30, 200000);
    policies = await tbillContract.getInterestPolicies();
    expect(policies).to.have.lengthOf(2);
    expect(policies[0].period).to.equal(DAY);
    expect(policies[0].interestRate).to.equal(200000);
    expect(policies[1].period).to.equal(DAY * 30);
    expect(policies[1].interestRate).to.equal(200000);

    try {
      await tbillContract.setInterestRate(85399, 200000);
    } catch (err) {
      expect(err.message).to.contain("Period too short");
    }
  })

  it("Should lock tokens when buying TBill", async function () {
    // Setup
    const [interestFund, user1] = await ethers.getSigners();
    const spotTokenContract = await ethers.deployContract("SpotTokenContract");
    const tbillContract = await ethers.deployContract("TBillContract", [interestFund.address, spotTokenContract.address]);

    await tbillContract.setInterestRate(30 * DAY, 0.015 * INTEREST_RATE_UNIT);
    await spotTokenContract.mint(user1.address, 666000);

    // User1 buys TBill with 10000 tokens
    await spotTokenContract.connect(user1).approve(tbillContract.address, 10000);
    await tbillContract.connect(user1).buyTBill(10000, 30 * DAY);

    expect(await spotTokenContract.balanceOf(user1.address)).to.equal(656000);
    expect(await spotTokenContract.balanceOf(tbillContract.address)).to.equal(10000);
    expect(await tbillContract.getTotalLockedTokens()).to.equal(10000);

    const holdings = await tbillContract.connect(user1).getTBillHoldings();
    const blockNum = await ethers.provider.getBlockNumber();
    const now = await ethers.provider.getBlock(blockNum);

    expect(holdings).to.have.lengthOf(1);
    expect(holdings[0].id).to.equal(0);
    expect(holdings[0].owner).to.equal(user1.address);
    expect(holdings[0].interestRate).to.equal(0.015 * INTEREST_RATE_UNIT);
    expect(holdings[0].spotTokenAmount).to.equal(10000);
    expect(holdings[0].releaseTimestamp).to.equal(now.timestamp + 30 * DAY);


    const holding = await tbillContract.connect(user1).getTBillById(0);
    expect(holding.id).to.equal(0);
    expect(holding.owner).to.equal(user1.address);
    expect(holding.interestRate).to.equal(0.015 * INTEREST_RATE_UNIT);
    expect(holding.spotTokenAmount).to.equal(10000);
    expect(holding.releaseTimestamp).to.equal(now.timestamp + 30 * DAY);

    // Redeem immediatly
    try {
      await tbillContract.connect(user1).redeemTBill(0);
      expect(false).to.be.true; // Expect this line not to reach
    } catch (err) {
      expect(err.message).to.contain("TBill not yet released");
    }

    // Redeem before release
    await helpers.time.increaseTo(now.timestamp + 29 * DAY);
    try {
      await tbillContract.connect(user1).redeemTBill(holding.id);
      expect(false).to.be.true; // Expect this line not to reach
    } catch (err) {
      expect(err.message).to.contain("TBill not yet released");
    }

    // Redeem after release: But insufficient funds for interests
    await helpers.time.increaseTo(now.timestamp + 30 * DAY);

    try {
      await tbillContract.connect(user1).redeemTBill(holding.id);
      expect(false).to.be.true; // Expect this line not to reach
    } catch (err) {
      expect(err.message).to.contain("Interests transfer failed: ERC20: insufficient allowance");
    }

    expect(await spotTokenContract.balanceOf(user1.address)).to.equal(656000);
    expect(await spotTokenContract.balanceOf(tbillContract.address)).to.equal(10000);
    expect(await tbillContract.getTotalLockedTokens()).to.equal(10000);

    // Deposit to interests fund
    await spotTokenContract.mint(interestFund.address, 999999999);
    await spotTokenContract.connect(interestFund).approve(tbillContract.address, 999999999);

    // Redeem after release: Sufficient funds for interests
    await tbillContract.connect(user1).redeemTBill(holding.id);
    expect(await spotTokenContract.balanceOf(user1.address)).to.equal(656000 + 10000 * 1.015);
    expect(await spotTokenContract.balanceOf(interestFund.address)).to.equal(999999999 - 10000 * 0.015);
    expect(await spotTokenContract.balanceOf(tbillContract.address)).to.equal(0);
    expect(await tbillContract.getTotalLockedTokens()).to.equal(0);

    // Expect cannot redeem again
    try {
      await tbillContract.connect(user1).redeemTBill(holding.id);
      expect(false).to.be.true; // Expect this line not to reach
    } catch (err) {
      expect(err.message).to.contain("TBill not found");
    }

    // Expect no holding already
    const holdings2 = await tbillContract.connect(user1).getTBillHoldings();
    expect(holdings2).to.have.lengthOf(0);
  });

  it("Should handle multiple holdings properly", async function () {
    // Setup
    const [interestFund, user1, user2] = await ethers.getSigners();
    const spotTokenContract = await ethers.deployContract("SpotTokenContract");
    const tbillContract = await ethers.deployContract("TBillContract", [interestFund.address, spotTokenContract.address]);

    await tbillContract.setInterestRate(30 * DAY, 0.015 * INTEREST_RATE_UNIT);
    await tbillContract.setInterestRate(60 * DAY, 0.02 * INTEREST_RATE_UNIT);
    await spotTokenContract.mint(user1.address, 666000);
    await spotTokenContract.mint(user2.address, 999000);
    // Deposit to interests fund
    await spotTokenContract.mint(interestFund.address, 999999999);
    await spotTokenContract.connect(interestFund).approve(tbillContract.address, 999999999);

    // Different Users buying
    await spotTokenContract.connect(user1).approve(tbillContract.address, 10000);
    await tbillContract.connect(user1).buyTBill(10000, 30 * DAY);
    await spotTokenContract.connect(user1).approve(tbillContract.address, 20000);
    await tbillContract.connect(user1).buyTBill(20000, 60 * DAY);
    await spotTokenContract.connect(user2).approve(tbillContract.address, 90000);
    await tbillContract.connect(user2).buyTBill(90000, 30 * DAY);


    let holdings = await tbillContract.connect(user1).getTBillHoldings();
    expect(holdings).to.have.lengthOf(2);
    expect(await spotTokenContract.balanceOf(user1.address)).to.equal(636000);
    expect(await spotTokenContract.balanceOf(user2.address)).to.equal(909000);
    expect(await spotTokenContract.balanceOf(tbillContract.address)).to.equal(120000);
    expect(await tbillContract.getTotalLockedTokens()).to.equal(120000);

    // User1 redeeming
    await helpers.time.increaseTo((await ethers.provider.getBlock(await ethers.provider.getBlockNumber())).timestamp + 60 * DAY);
    await tbillContract.connect(user1).redeemTBill(0);
    expect(await spotTokenContract.balanceOf(user1.address)).to.equal(636000 + 10000 * 1.015);
    expect(await spotTokenContract.balanceOf(interestFund.address)).to.equal(999999999 - 10000 * 0.015);
    expect(await spotTokenContract.balanceOf(tbillContract.address)).to.equal(110000);
    expect(await tbillContract.getTotalLockedTokens()).to.equal(110000);

    // User2 redeeming
    await tbillContract.connect(user2).redeemTBill(0);
    expect(await spotTokenContract.balanceOf(user2.address)).to.equal(909000 + 90000 * 1.015);
    expect(await spotTokenContract.balanceOf(interestFund.address)).to.equal(999999999 - 10000 * 0.015 - 90000 * 0.015);

    // // User1 redeeming again
    await tbillContract.connect(user1).redeemTBill(0); // NOTE: After we swap, the ID changed
    expect(await spotTokenContract.balanceOf(user1.address)).to.equal(636000 + 10000 * 1.015 + 20000 * 1.02);
    expect(await spotTokenContract.balanceOf(interestFund.address)).to.equal(999999999 - 10000 * 0.015 - 90000 * 0.015 - 20000 * 0.02);
    expect(await spotTokenContract.balanceOf(tbillContract.address)).to.equal(0);
    expect(await tbillContract.getTotalLockedTokens()).to.equal(0);

    // Expect no holding already
    expect(await tbillContract.connect(user1).getTBillHoldings()).to.have.lengthOf(0);
    expect(await tbillContract.connect(user2).getTBillHoldings()).to.have.lengthOf(0);
  });
});
