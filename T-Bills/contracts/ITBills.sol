// SPDX-License-Identifier: MIT

pragma solidity >= 0.8.18;

interface TBill {
  event InterestPolicyChanged(uint256 period, uint256 interestRate);
  event TBillLocked(LockedTBill);
  event TBillRevoked(LockedTBill);
  event TBillRedeemed(LockedTBill);
  event TBillForceRefunded(LockedTBill);

  struct InterestPolicy {
    uint256 period;
    uint256 interestRate;
  }

  struct LockedTBill {
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
  function getInterestPolicies() external view returns (InterestPolicy[] memory policies);

  //=== Admin functions ===//
  // @dev Allow admin to set interest rates for each period, if interest rate is <= 0, then the period is not available
  function setInterestRate(uint256 period, uint256 interestRate) external;

  // @dev Allow admin to deposit ERC20Token to interests pool
  function depositInterestFunds(uint256 amount) external;

  // @dev Allow admin to withdraw ERC20Token from interests pool
  function withdrawInterestFunds(uint256 amount) external;

  //=== User functions ===//
  // @dev Let people buy TBill token with ERC20Token and select the locking period
  function buyTBill(uint256 amount, uint256 period) external returns (uint256 id);

  // @dev Query msg.sender's TBill holdings and details
  function getTBillHolding() external view returns (LockedTBill[] memory tbills);

  // @dev Query msg.sender's TBill holding by id
  function getTBillById(uint256 id) external view returns (LockedTBill memory tbill);

  // @dev Redeem TBill token to get back ERC20Token when released
  function redeemTBill(uint256 id) external;

  // @dev Allow user to do force refund if the contract is not able to pay back with interests after the release date
  function forceRefund(uint256 id) external;
}
