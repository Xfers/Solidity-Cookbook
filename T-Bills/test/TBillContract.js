// Test script for TBillContract.sol

const { expect } = require("chai");

const DAY = 86400;

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
    const [interestFund, user1, user2] = await ethers.getSigners();
    const spotTokenContract = await ethers.deployContract("SpotTokenContract");
    const tbillContract = await ethers.deployContract("TBillContract", [interestFund.address, spotTokenContract.address]);

    tbillContract.setInterestRate(30 * DAY, 150000);
    await spotTokenContract.mint(user1.address, 666);
    await spotTokenContract.mint(user2.address, 777);

    let holding;
    let blockNum;
    let now;

    // User1 buys TBill with 10 tokens
    await spotTokenContract.connect(user1).approve(tbillContract.address, 10);
    await tbillContract.connect(user1).buyTBill(10, 30 * DAY);

    expect(await spotTokenContract.balanceOf(user1.address)).to.equal(656);
    expect(await spotTokenContract.balanceOf(tbillContract.address)).to.equal(10);
    expect(await tbillContract.getTotalLockedTokens()).to.equal(10);

    holding = await tbillContract.connect(user1).getTBillHolding();
    blockNum = await ethers.provider.getBlockNumber();
    now = await ethers.provider.getBlock(blockNum);

    expect(holding).to.have.lengthOf(1);
    expect(holding[0].id).to.equal(0);
    expect(holding[0].owner).to.equal(user1.address);
    expect(holding[0].interestRate).to.equal(150000);
    expect(holding[0].spotTokenAmount).to.equal(10);
    expect(holding[0].releaseTimestamp).to.equal(now.timestamp + 30 * DAY);

    // User2 buys TBill with 50 tokens
    await spotTokenContract.connect(user2).approve(tbillContract.address, 50);
    await tbillContract.connect(user2).buyTBill(50, 30 * DAY);

    expect(await spotTokenContract.balanceOf(user2.address)).to.equal(727);
    expect(await spotTokenContract.balanceOf(tbillContract.address)).to.equal(60);
    expect(await tbillContract.getTotalLockedTokens()).to.equal(60);

    holding = await tbillContract.connect(user2).getTBillHolding();
    blockNum = await ethers.provider.getBlockNumber();
    now = await ethers.provider.getBlock(blockNum);

    expect(holding).to.have.lengthOf(1);
    expect(holding[0].id).to.equal(1);
    expect(holding[0].owner).to.equal(user2.address);
    expect(holding[0].interestRate).to.equal(150000);
    expect(holding[0].spotTokenAmount).to.equal(50);
    expect(holding[0].releaseTimestamp).to.equal(now.timestamp + 30 * DAY);
  });
});
