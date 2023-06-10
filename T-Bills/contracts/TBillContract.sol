// SPDX-License-Identifier: MIT

pragma solidity >=0.8.18;

import "./ITBill.sol";
import "./SafeMath.sol";

interface IERC20 {
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);
}

contract TBillContract is ITBill {
    using SafeMath for uint256;

    //=== Database ===//
    uint256 public interestRateDecimals = 6;
    uint256 public minimumLockingPeriod = 1 days;
    address public interestFundAddress; // a.k.a. Owner
    address public erc20TokenAddress;
    // Period => InterestRate
    InterestPolicy[] private _interestPolicies;
    LockedTBill[] private _tbills;

    //=== Index ===//
    uint256 private _totalLockedTokens;
    // Owner Address => TBillID[]
    mapping(address => uint256[]) private _tbillsHoldingIndex;

    constructor(address _interestFundAddress, address _erc20TokenAddress) {
        interestFundAddress = _interestFundAddress;
        erc20TokenAddress = _erc20TokenAddress;
    }

    //=== Modifiers ===//
    modifier onlyOwner() {
        require(
            msg.sender == interestFundAddress,
            "Only owner can call this function"
        );
        _;
    }

    //=== Public view functions ===//
    function getERC20TokenAddress() external view override returns (address) {
        return erc20TokenAddress;
    }

    function getTotalLockedTokens() external view override returns (uint256) {
        IERC20 erc20token = IERC20(erc20TokenAddress);
        return erc20token.balanceOf(address(this));
    }

    function getInterestPolicies()
        external
        view
        override
        returns (InterestPolicy[] memory)
    {
        return _interestPolicies;
    }

    function getInterestFundBalance() external view override returns (uint256) {
        IERC20 erc20token = IERC20(erc20TokenAddress);
        return erc20token.balanceOf(interestFundAddress);
    }

    function getInterestRate(uint256 period)
        external
        view
        override
        returns (uint256)
    {
        return _getInterestRate(period);
    }

    //=== Admin functions ===//
    function setInterestRate(
        uint256 period,
        uint256 interestRate
    ) external override onlyOwner {
        require(period >= minimumLockingPeriod, "Period too short");

        for (uint256 i = 0; i < _interestPolicies.length; i++) {
            if (_interestPolicies[i].period == period) {
                _interestPolicies[i].interestRate = interestRate;
                emit InterestPolicyChanged(period, interestRate);
                return;
            }
        }

        InterestPolicy memory newPolicy = InterestPolicy({
            period: period,
            interestRate: interestRate
        });

        _interestPolicies.push(newPolicy);
        emit InterestPolicyChanged(period, interestRate);
    }

    //=== User functions ===//

    function buyTBill(
        uint256 amount,
        uint256 period
    ) external override returns (uint256 id) {
        require(amount > 0, "Amount must be greater than zero");
        require(_getInterestRate(period) > 0, "Period not supported");

        // Lock the token into the contract
        IERC20 erc20token = IERC20(erc20TokenAddress);
        require(
            erc20token.approve(address(this), amount),
            "Token approval failed"
        );
        require(
            erc20token.transferFrom(msg.sender, address(this), amount),
            "Token transfer failed"
        );

        // Create receipt
        id = _tbills.length;
        LockedTBill memory createdTBill = LockedTBill({
            id: id,
            owner: msg.sender,
            interestRate: _getInterestRate(period),
            spotTokenAmount: amount,
            releaseTimestamp: block.timestamp + period
        });

        _tbills.push(createdTBill);

        _tbillsHoldingIndex[msg.sender].push(createdTBill.id);

        emit TBillLocked(createdTBill);
        return createdTBill.id;
    }

    function getTBillHolding()
        external
        view
        override
        returns (LockedTBill[] memory tbills)
    {
        tbills = new LockedTBill[](_tbillsHoldingIndex[msg.sender].length);

        for (uint256 i = 0; i < _tbillsHoldingIndex[msg.sender].length; i++) {
            tbills[i] = _tbills[_tbillsHoldingIndex[msg.sender][i]];
        }

        return tbills;
    }

    function getTBillById(
        uint256 id
    ) external view override returns (LockedTBill memory tbill) {
        LockedTBill storage lockedTBill = _tbills[id];
        require(lockedTBill.owner == msg.sender, "Not the owner of the TBill");

        return lockedTBill;
    }

    function cancelTBill(uint256 id) external pure override {
        require(false, "Cancellation not allowed for now");
    }

    function redeemTBill(uint256 id) external override {
        LockedTBill storage tbill = _tbills[id];
        require(tbill.owner == msg.sender, "Not the owner of the TBill");
        require(
            block.timestamp >= tbill.releaseTimestamp,
            "TBill not yet released"
        );

        // Release the interest
        uint256 interest = tbill.spotTokenAmount.mul(
            tbill.interestRate.div(10 ** interestRateDecimals)
        );
        IERC20 erc20token = IERC20(erc20TokenAddress);

        // Transfer from interestFundAddress to this
        require(
            erc20token.transferFrom(msg.sender, tbill.owner, interest),
            "Token transfer failed"
        );
        require(
            erc20token.transfer(msg.sender, tbill.spotTokenAmount),
            "Token transfer failed"
        );

        // Mark as redeemed
        tbill.owner = address(0);
    }

    function forceRefund(uint256 id) external override {
        LockedTBill storage tbill = _tbills[id];
        require(tbill.owner == msg.sender, "Not the owner of the TBill");
        require(
            block.timestamp >= tbill.releaseTimestamp,
            "TBill not yet released"
        );

        IERC20 erc20token = IERC20(erc20TokenAddress);
        require(
            erc20token.transfer(msg.sender, tbill.spotTokenAmount),
            "Token transfer failed"
        );

        // Mark as redeemed
        tbill.owner = address(0);
    }

    function _getInterestRate(uint256 period) private view returns (uint256) {
        for (uint256 i = 0; i < _interestPolicies.length; i++) {
            if (_interestPolicies[i].period == period) {
                return _interestPolicies[i].interestRate;
            }
        }

        return 0;
    }
}
