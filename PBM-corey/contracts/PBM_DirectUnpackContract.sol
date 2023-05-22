// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract PBM_DirectUnpackContract {
    enum TransactionStatus { NONE, REQUESTED, APPROVED, REDEEMED }

    struct PBMRedemption {
        address to;
        uint256 unwrappedAmount;
        TransactionStatus status;
    }

    struct PBMToken {
        address erc20tokenAddress;
        uint256 value;
        PBMRedemption redemption;
    }

    // PBM Owner => PBM ID => PBM Token
    mapping (address => mapping(uint256 => PBMToken)) public pbmTokens;

    // PBM Owner => PBM Count
    mapping (address => uint256) public pbmCount;

    function mint(address _pbmOwner, address _erc20tokenAddress, uint256 _value) public returns(uint256) {
        uint256 pbmID = pbmCount[_pbmOwner];
        PBMToken storage pbm = pbmTokens[_pbmOwner][pbmID];
        require(_value != 0, "Value must be greater than 0");
        require(_erc20tokenAddress != address(0), "Token address must be valid");
        require(pbm.value == 0, "PBM already exists");

        pbm.value = _value;
        pbm.erc20tokenAddress = _erc20tokenAddress;
        pbm.redemption.status = TransactionStatus.NONE;
        pbmCount[_pbmOwner] = pbmID + 1;

        return pbmID;
    }

    function redeem(address _to, uint256 _pbmID) public {
        PBMToken storage pbm = pbmTokens[msg.sender][_pbmID];
        require(pbm.value != 0, "PBM does not exist");
        require(pbm.redemption.status != TransactionStatus.REDEEMED, "Already redeemed");
        require(pbm.redemption.status != TransactionStatus.REQUESTED, "Already requested");

        uint256 unwrappedAmount = pbm.value;
        if (pbm.redemption.status == TransactionStatus.NONE) {
            pbm.redemption = PBMRedemption({
                to: _to,
                unwrappedAmount: unwrappedAmount,
                status: TransactionStatus.REQUESTED
            });
        } else if (pbm.redemption.status == TransactionStatus.APPROVED) {
            require(pbm.redemption.to == _to, "Recipient does not match");
            require(pbm.redemption.unwrappedAmount == unwrappedAmount, "Unwrapped amount does not match");
            unwrapPBM(pbm);
        }
    }

    function approve(address _pbmOwner, uint256 _pbmID, address _to) public {
        PBMToken storage pbm = pbmTokens[_pbmOwner][_pbmID];
        require(pbm.value != 0, "PBM does not exist");
        require(pbm.redemption.status != TransactionStatus.REDEEMED, "Already redeemed");
        require(pbm.redemption.status != TransactionStatus.APPROVED, "Already approved");

        uint256 unwrappedAmount = pbm.value;
        if (pbm.redemption.status == TransactionStatus.NONE) {
            pbm.redemption = PBMRedemption({
                to: _to,
                unwrappedAmount: unwrappedAmount,
                status: TransactionStatus.APPROVED
            });

            IERC20 erc20token = IERC20(pbm.erc20tokenAddress);
            if(!erc20token.approve(address(this), unwrappedAmount)) {
                revert("Approval failed");
            }

            if (!erc20token.transferFrom(msg.sender, address(this), unwrappedAmount)) {
                revert("Transfer to contract account failed");
            }
        } else if (pbm.redemption.status == TransactionStatus.REQUESTED) {
            require(pbm.redemption.to == _to, "Recipient does not match");
            require(pbm.redemption.unwrappedAmount == unwrappedAmount, "Unwrapped amount does not match");
            unwrapPBM(pbm);
        }
    }

    function unwrapPBM(PBMToken storage pbm) private {
        IERC20 erc20token = IERC20(pbm.erc20tokenAddress);
        if(!erc20token.transfer(pbm.redemption.to, pbm.redemption.unwrappedAmount)) {
            revert("Transfer to recipient failed");
        }
        pbm.redemption.status = TransactionStatus.REDEEMED;
    }
}
