// SPDX-License-Identifier: MIT

pragma solidity >= 0.8.18;

interface TBills {
  event TBillsLocked(LockedTBills);
  event TBillsRevoked(LockedTBills);
  event TBillsRedeemed(LockedTBills);
  event TBillsForceRefunded(LockedTBills);

  struct InterestPolicy {
    uint256 period;
    uint256 interestRate;
  }

  struct LockedTBills {
    uint256 id;
    address owner;
    uint256 interestRate;
    uint256 spotTokenAmount;
    uint256 releaseTimestamp;
  }

  //=== Public view functions ===//
  // @dev Get supported ERC20 token address
  function getERC20TokenAddress() external view returns (address erc20TokenAddress);

  // @dev Get total locked ERC20 token amount
  function getTotalLockedTokens() external view returns (uint256 totalLockedTokens);

  // @dev Show current interest rate policies
  function getInterestRatePolicies() external view returns (InterestPolicy[] memory policies);

  //=== Admin functions ===//
  // @dev Allow admin to set interest rates for each period, if interest rate is <= 0, then the period is not available
  function setInterestRate(uint256 period, uint256 interestRate) external;

  // @dev Allow admin to deposit ERC20Token for interests
  function depositInterestFunds(uint256 amount) external;

  // @dev Allow admin to withdraw ERC20Token for interests
  function withdrawInterestFunds(uint256 amount) external;

  //=== User functions ===//
  // @dev Let people buy TBills token with ERC20Token and select the locking period
  function buyTBills(uint256 amount, uint256 period) external returns (uint256 id);

  // @dev Let people revoke the locking if it's within 30 minutes after the purchase
  function revokeTBills(uint256 id) external;

  // @dev Query msg.sender's TBills holdings and details
  function getTBillsHolding() external view returns (LockedTBills[] memory tbills);

  // @dev Redeem TBills token to get back ERC20Token when released
  function redeemTBills(uint256 id) external;

  // @dev Allow user to do force refund if the contract is not able to pay back with interests after the release date
  function forceRefund(uint256 id) external;
}
