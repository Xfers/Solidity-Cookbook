// Test script for TBillContract.sol

const { expect } = require("chai");

describe("TBillContract", function () {
  it("Should return correct constants", async function () {
    const [interestFund] = await ethers.getSigners();
    const erc20TokenContract = await ethers.getContractFactory("ERC20TokenContract");
    const tbillContract = await ethers.deployContract("TBillContract", [interestFund.address, erc20TokenContract.address]);

    expect(await tbillContract.interestRateDecimals()).to.equal(6);
    expect(await tbillContract.interestFundAddress()).to.equal(interestFund.address);
    expect(await tbillContract.getERC20TokenAddress()).to.equal(erc20TokenContract.address);
  });
});
