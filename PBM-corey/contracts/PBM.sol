// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

// TODO: Multi-Sig
contract PurposeBoundMoney {
    IERC20 public moneyToken;
    struct Trasnaction {
        address to;
        uint256 pbmAmount;
        uint256 tokenAmount;
        bool donatorAp;
    }

    mapping (address => uint256) public vouchers;
    mapping (address => mapping (uint256 => Trasnaction)) public pendingTransactions;

    // Events
    event Mint(address indexed _to, uint256 _amount);
    event Transfer(address indexed _from, address indexed _to, uint256 _totalAmount, uint256 _pbmSpent);

    constructor(address _tokenContractAddress) {
        moneyToken = IERC20(_tokenContractAddress);
    }

    modifier validTransfer(address _to, uint256 _pbmAmount, uint256 _tokenAmount) {
        require(_to != address(0), "Invalid address");
        require(_pbmAmount > 0, "Invalid amount");
        require(vouchers[msg.sender] >= _pbmAmount, "Not enough PBM");
        _;
    }

    function mint(address _to, uint256 _amount) public {
        require(moneyToken.balanceOf(msg.sender) >= _amount, "Not enough tokens");
        vouchers[_to] += _amount;
        moneyToken.transfer(address(this), _amount);
        emit Mint(_to, _amount);
    }

    function directTransfer(address _to, uint256 _pbmAmount, uint256 _tokenAmount) public validTransfer(_to, _pbmAmount, _tokenAmount) {
        transferTokensIn(_tokenAmount);

        // Unwrap PBM
        uint256 _totalAmount = _pbmAmount + _tokenAmount;

        vouchers[msg.sender] -= _pbmAmount;

        moneyToken.transfer(_to, _pbmAmount + _tokenAmount);

        emit Transfer(msg.sender, _to, _totalAmount, _pbmAmount);
    }

    function requestDonateTransfer(uint32 txnId, address _to, uint256 _pbmAmount, uint256 _tokenAmount) public validTransfer(_to, _pbmAmount, _tokenAmount) {
    }

    function donaterTransfer(uint32 txnId, address _to, uint256 _pbmAmount, uint256 _tokenAmount) public {

    }

    function transferTokensIn(uint256 _amount) public {
        require(moneyToken.approve(address(this), _amount), "Approval failed");
        require(moneyToken.transferFrom(msg.sender, address(this), _amount), "Transfer failed");
    }
}
