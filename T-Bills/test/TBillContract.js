// Test script for TBillContract.sol

const { expect } = require("chai");

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

    await tbillContract.setInterestRate(86400, 100000);
    policies = await tbillContract.getInterestPolicies();
    expect(policies).to.have.lengthOf(1);
    expect(policies[0].period).to.equal(86400);
    expect(policies[0].interestRate).to.equal(100000);

    await tbillContract.setInterestRate(86400, 200000);
    policies = await tbillContract.getInterestPolicies();
    expect(policies).to.have.lengthOf(1);
    expect(policies[0].period).to.equal(86400);
    expect(policies[0].interestRate).to.equal(200000);

    await tbillContract.setInterestRate(86400 * 30, 200000);
    policies = await tbillContract.getInterestPolicies();
    expect(policies).to.have.lengthOf(2);
    expect(policies[0].period).to.equal(86400);
    expect(policies[0].interestRate).to.equal(200000);
    expect(policies[1].period).to.equal(86400 * 30);
    expect(policies[1].interestRate).to.equal(200000);

    try {
      await tbillContract.setInterestRate(85399, 200000);
    } catch (err) {
      expect(err.message).to.contain("Period too short");
    }
  })
});
