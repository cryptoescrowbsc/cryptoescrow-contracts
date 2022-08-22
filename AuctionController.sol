// SPDX-License-Identifier: None
pragma solidity ^0.8.0;

import "./SafeMath.sol";
import "./Ownable.sol";
import "./SafeERC20.sol";
import "./IERC20.sol";

contract AuctionController is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each auction.
    struct AuctionInfo {
        address auctionOwner;
        address inputToken;
        address wantedToken;
        uint256 inputAmount;
        uint256 wantedAmount;
        uint256 taxFee;
        bool active;
        bool completed;
    }

    // Info of each token.
    struct InputToken {
        address tokenAddress;
        uint256 taxFee;
        bool isActive;
    }

    InputToken[] public tokenList;
    AuctionInfo[] public auctionInfo;

    address public feeAddress;

    mapping(address => bool) public tokenExistence;

    constructor() {
        feeAddress = msg.sender;
    }

    function getAuctions() external view returns (AuctionInfo[] memory) {
        return auctionInfo;
    }

    function getTokenList() external view returns (InputToken[] memory) {
        return tokenList;
    }

    function auctionLength() external view returns (uint256) {
        return auctionInfo.length;
    }

    function addToken(address _token, uint256 _taxFee) public onlyOwner {
        require(_taxFee <= 100, "Token fee must be lower than 1%");

        tokenList.push(InputToken({
            tokenAddress: _token,
            taxFee: _taxFee,
            isActive: true
        }));
        tokenExistence[_token] = true;
    }

    function removeToken(address _token) public onlyOwner {
        for (uint i; i < tokenList.length; i++) {
            if (tokenList[i].tokenAddress == _token) {
                tokenList[i].isActive = false;
            }
        }
        tokenExistence[_token] = false;
    }

    function updateTokenFee(address _token, uint256 _taxFee) public onlyOwner {
        require(_taxFee <= 100, "Token fee must be lower than 1%");
        
        for (uint i; i < tokenList.length; i++) {
            if (tokenList[i].tokenAddress == _token) {
                tokenList[i].taxFee = _taxFee;
            }
        }
    }

    function createAuction(address _inputToken, address _wantedToken, uint256 _inputAmount, uint256 _wantedAmount) public {
        require(tokenExistence[_inputToken] == true, "inputToken must be in list");

        IERC20(_inputToken).safeTransferFrom(msg.sender, address(this), _inputAmount);

        uint256 taxFee = 0;

        for (uint i; i < tokenList.length; i++) {
            if (tokenList[i].tokenAddress == _inputToken) {
                taxFee = tokenList[i].taxFee;
            }
        }

        auctionInfo.push(AuctionInfo({
            auctionOwner: msg.sender,
            inputToken: _inputToken,
            wantedToken: _wantedToken,
            inputAmount: _inputAmount,
            wantedAmount: _wantedAmount,
            taxFee: taxFee,
            active: true,
            completed: false
        }));
    }

    function leaveAuction(uint256 _auctionId) public {
        AuctionInfo storage auction = auctionInfo[_auctionId];
        require(auction.auctionOwner == msg.sender, "You are not the auction owner");
        require(auction.active == true, "Auction is not active");
        require(auction.completed == false, "You can't leave an auction already completed");

        IERC20(auction.inputToken).safeTransfer(msg.sender, auction.inputAmount);
        
        auction.active = false;
    }

    function acceptAuction(uint256 _auctionId) public {
        AuctionInfo storage auction = auctionInfo[_auctionId];
        require(auction.active == true, "Auction is not active");
        require(auction.completed == false, "Auction has already been completed");

        // send to buyer
        IERC20(auction.wantedToken).safeTransferFrom(msg.sender, address(this), auction.wantedAmount);
        IERC20(auction.inputToken).safeTransfer(msg.sender, auction.inputAmount);

        // send to auction owner
        uint256 controllerFeeAmount = auction.wantedAmount.mul(auction.taxFee).div(10000);
        uint256 auctionOwnerAmount = auction.wantedAmount.sub(controllerFeeAmount);

        IERC20(auction.wantedToken).safeTransfer(auction.auctionOwner, auctionOwnerAmount);
        IERC20(auction.wantedToken).safeTransfer(feeAddress, controllerFeeAmount);

        auction.completed = true;
    }

    function editAuction(uint256 _auctionId, address _wantedToken, uint256 _wantedAmount) public {
        AuctionInfo storage auction = auctionInfo[_auctionId];
        require(auction.auctionOwner == msg.sender, "You are not the auction owner");
        require(auction.active == true, "Auction is not active");
        require(auction.completed == false, "Auction has already been completed");

        auction.wantedToken = _wantedToken;
        auction.wantedAmount = _wantedAmount;
    }

    function setFeeAddress(address _feeAddress) public onlyOwner {
        feeAddress = _feeAddress;
    }
}