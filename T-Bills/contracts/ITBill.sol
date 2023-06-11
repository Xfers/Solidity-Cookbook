// SPDX-License-Identifier: MIT

pragma solidity >=0.8.18;

interface ITBill {
    event InterestPolicyChanged(uint32 period, uint32 interestRate);
    event TBillLocked(LockedTBill);
    event TBillRevoked(LockedTBill);
    event TBillRedeemed(LockedTBill);
    event TBillForceRefunded(LockedTBill);

    struct InterestPolicy {
        uint32 period;
        uint32 interestRate;
    }

    struct LockedTBill {
        uint256 id;
        address owner;
        uint256 expectedInterests;
        uint256 spotTokenAmount;
        uint256 releaseTimestamp;
    }

    //=== Public view functions ===//
    // @dev Get supported ERC20 token address
    function getERC20TokenAddress() external view returns (address);

    // @dev Get total locked ERC20 token amount
    function getTotalLockedTokens() external view returns (uint256);

    // @dev Show current interest rate policies
    function getInterestPolicies()
        external
        view
        returns (InterestPolicy[] memory policies);

    // @dev Get Interest Fund Balance
    function getInterestFundBalance() external view returns (uint256);

    // @dev Get Interest rate
    function getInterestRate(uint32 period) external view returns (uint32);

    //=== Admin functions ===//
    // @dev Allow admin to set interest rates for each period, if interest rate is <= 0, then the period is not available
    function setInterestRate(uint32 period, uint32 interestRate) external;

    // @dev Allow admin to change the interest fund address
    function setInterestFundAddress(address newAddress) external;

    //=== User functions ===//
    // @dev Let people buy TBill token with ERC20Token and select the locking period
    function buyTBill(
        uint256 amount,
        uint32 period
    ) external returns (uint256 id);

    // @dev Query msg.sender's TBill holdings and details
    function getTBillHoldings()
        external
        view
        returns (LockedTBill[] memory tbills);

    // @dev Query msg.sender's TBill holding by id
    function getTBillById(
        uint256 id
    ) external view returns (LockedTBill memory tbill);

    // @dev Let people revoke TBill within the cancellation period
    function cancelTBill(uint256 id) external;

    // @dev Redeem TBill token to get back ERC20Token when released
    function redeemTBill(uint256 id) external;

    // @dev Allow user to do force refund if the contract is not able to pay back with interests after the release date
    function forceRefund(uint256 id) external;
}
