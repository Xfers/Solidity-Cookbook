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
        IERC20 erc20token;
        uint256 value;
        PBMRedemption redemption;
    }

    // PBM Owner => PBM ID => PBM Token
    mapping (address => mapping(uint256 => PBMToken)) public pbmTokens;

    function redeem(address _to, uint256 _pbmID) public {
        PBMToken storage pbm = pbmTokens[msg.sender][_pbmID];
        require(pbm.redemption.status != TransactionStatus.REDEEMED, "Already redeemed");
        require(pbm.redemption.status != TransactionStatus.REQUESTED, "Already requested");

        if (pbm.redemption.status == TransactionStatus.NONE) {
            uint256 unwrappedAmount = pbm.value;

            pbm.redemption = PBMRedemption({
                to: _to,
                unwrappedAmount: unwrappedAmount,
                status: TransactionStatus.REQUESTED
            });
        } else if (pbm.redemption.status == TransactionStatus.APPROVED) {
            unwrapPBM(pbm);
        }
    }

    function approve(address _pbmOwner, uint256 _pbmID, address _to) public {
        PBMToken storage pbm = pbmTokens[_pbmOwner][_pbmID];
        require(pbm.redemption.status != TransactionStatus.REDEEMED, "Already redeemed");
        require(pbm.redemption.status != TransactionStatus.APPROVED, "Already approved");

        if (pbm.redemption.status == TransactionStatus.NONE) {
            uint256 unwrappedAmount = pbm.value;

            pbm.redemption = PBMRedemption({
                to: _to,
                unwrappedAmount: unwrappedAmount,
                status: TransactionStatus.APPROVED
            });

            require(pbm.erc20token.approve(address(this), unwrappedAmount), "Approval failed");
            require(pbm.erc20token.transferFrom(msg.sender, address(this), unwrappedAmount), "Transfer to contract account failed");
        } else if (pbm.redemption.status == TransactionStatus.REQUESTED) {
            unwrapPBM(pbm);
        }
    }

    function unwrapPBM(PBMToken storage pbm) private {
        require(pbm.erc20token.transfer(pbm.redemption.to, pbm.redemption.unwrappedAmount), "Transfer to recipient failed");
        pbm.redemption.status = TransactionStatus.REDEEMED;
    }
}
