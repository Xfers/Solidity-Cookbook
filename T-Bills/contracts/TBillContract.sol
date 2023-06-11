// SPDX-License-Identifier: MIT

pragma solidity >=0.8.18;

import "./ITBill.sol";
import "./SafeMath.sol";
import "hardhat/console.sol";

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
    uint256 public maxInterestRate = 500000; // 50%
    uint256 public minimumLockingPeriod = 1 days;
    address public interestFundAddress; // a.k.a. Owner
    address public erc20TokenAddress;

    InterestPolicy[] private _interestPolicies;
    mapping(address => LockedTBill[]) private _ownedTBills;

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
        require(interestRate < maxInterestRate, "Interest rate should be less than 50%");

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
            erc20token.transferFrom(msg.sender, address(this), amount),
            "Token transfer failed"
        );

        // Create receipt
        id = _ownedTBills[msg.sender].length;
        LockedTBill memory createdTBill = LockedTBill({
            id: id,
            owner: msg.sender,
            interestRate: _getInterestRate(period),
            spotTokenAmount: amount,
            releaseTimestamp: block.timestamp + period
        });

        _ownedTBills[msg.sender].push(createdTBill);

        emit TBillLocked(createdTBill);
        return createdTBill.id;
    }

    function getTBillHoldings()
        external
        view
        override
        returns (LockedTBill[] memory)
    {
        return _ownedTBills[msg.sender];
    }

    function getTBillById(
        uint256 id
    ) external view override returns (LockedTBill memory tbill) {
        LockedTBill storage lockedTBill = _ownedTBills[msg.sender][id];
        require(lockedTBill.owner == msg.sender, "Not the owner of the TBill");

        return lockedTBill;
    }

    function cancelTBill(uint256 id) external pure override {
        require(false, "Cancellation not allowed for now");
    }

    function redeemTBill(uint256 id) external override {
        require(id < _ownedTBills[msg.sender].length, "TBill not found");
        LockedTBill storage tbill = _ownedTBills[msg.sender][id];
        require(tbill.owner == msg.sender, "Not the owner of the TBill");
        require(
            block.timestamp >= tbill.releaseTimestamp,
            "TBill not yet released"
        );

        // Release the interest
        uint256 interest = tbill.spotTokenAmount.mul(tbill.interestRate).div(10 ** interestRateDecimals);
        IERC20 erc20token = IERC20(erc20TokenAddress);

        // Transfer from interestFundAddress to this
        require(interest > 0, "Interest is 0, do forceRefund Instead");

        try erc20token.transferFrom(interestFundAddress, tbill.owner, interest) {
        } catch Error(string memory errorMessage) {
            revert(string.concat("Interests transfer failed: ", errorMessage));
        }

        try erc20token.transfer(msg.sender, tbill.spotTokenAmount) {
        } catch Error(string memory errorMessage) {
            revert(string.concat("Token transfer failed: ", errorMessage));
        }

        _deleteTBill(msg.sender, id);
    }

    function forceRefund(uint256 id) external override {
        LockedTBill storage tbill = _ownedTBills[msg.sender][id];
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

        _deleteTBill(msg.sender, id);
    }

    function _getInterestRate(uint256 period) private view returns (uint256) {
        for (uint256 i = 0; i < _interestPolicies.length; i++) {
            if (_interestPolicies[i].period == period) {
                return _interestPolicies[i].interestRate;
            }
        }

        return 0;
    }

    function _deleteTBill(address owner, uint256 id) private {
        _ownedTBills[owner][id] = _ownedTBills[owner][_ownedTBills[owner].length - 1];
        _ownedTBills[owner][id].id = id;
        _ownedTBills[owner].pop();
    }
}
