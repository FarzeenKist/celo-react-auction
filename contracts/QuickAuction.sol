// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract QuickAuction is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() ERC721("AuctionNFT", "AUC") {}

    struct Auction {
        address owner;
        uint256 startPrice;
        uint256 highestBid;
        address highestBidder;
        address[] buyers;
        uint256 endTime;
        bool isActive;
        bool ownerTaken;
        bool collected;
    }

    mapping(address => mapping(uint256 => uint256)) private bids;
    mapping(uint256 => Auction) private auctions;
    mapping(address => uint[]) private participatedIn;

    event NewAuction(uint256 id);
    event Bid(address indexed sender, uint256 amount);
    event End(address winner, uint256 amount);

    /* Check if the auction has ended */
    modifier isTimeUp(uint256 _id) {
        if (
            block.timestamp > auctions[_id].endTime && auctions[_id].isActive
        ) {
            auctions[_id].isActive = false;
        }
        _;
    }

    /*╔═════════════════════════════╗
      ║        AUCTION FUNCTIONS    ║
      ╚═════════════════════════════╝*/

    /**
     * @dev Creates a new auction provided the right parameters are given */
    function createAuction(
        string memory tokenURI,
        uint256 _startPrice,
        uint256 _endTime
    ) external {
        require(bytes(tokenURI).length > 0, "Empty token URI");
        uint256 newItemId = _tokenIds.current();
        _tokenIds.increment();
        _mint(msg.sender, newItemId);
        _setTokenURI(newItemId, tokenURI);

        auctions[newItemId].startPrice = _startPrice;
        auctions[newItemId].endTime = block.timestamp + _endTime;
        auctions[newItemId].owner = msg.sender;
        auctions[newItemId].isActive = true;
        participatedIn[msg.sender].push(newItemId);
        _transfer(msg.sender, address(this), newItemId);
        emit NewAuction(newItemId);
    }

    /**
     * @dev  Make a bid to a specific auction */
    function bid(uint256 _id) external payable isTimeUp(_id) {
        require(
            block.timestamp < auctions[_id].endTime || auctions[_id].isActive,
            "Auction ended"
        );
        require(msg.sender != auctions[_id].owner, "Owner can't bid duh!!!");

        uint256 currentBid = bids[msg.sender][_id] + msg.value;

        if (auctions[_id].highestBid == 0) {
            require(
                msg.value >= auctions[_id].startPrice,
                "Amount is less than starting price"
            );
            auctions[_id].highestBid = msg.value;
        } else {
            require(
                currentBid > auctions[_id].highestBid,
                "Amount is less than current bid"
            );
            auctions[_id].highestBid = currentBid;
        }

        auctions[_id].highestBidder = msg.sender;
        if (bids[msg.sender][_id] == 0) {
            auctions[_id].buyers.push(msg.sender);
            participatedIn[msg.sender].push(_id);
        }
        bids[msg.sender][_id] = currentBid;

        emit Bid(msg.sender, currentBid);
    }

    /**
     @dev Auction is over, collect your rewards if you participated */
    function timeUp(uint256 _id) external isTimeUp(_id) {
        require(!auctions[_id].isActive, "Auction has not yet ended");
        if (auctions[_id].owner == msg.sender && !auctions[_id].ownerTaken) {
            if (auctions[_id].highestBidder == address(0)) {
                _transfer(address(this), msg.sender, _id);
                auctions[_id].ownerTaken = true;
            } else {
                uint amount = auctions[_id].highestBid;
                auctions[_id].highestBid = 0;
                auctions[_id].ownerTaken = true;
                (bool success, ) = payable(auctions[_id].owner).call{
                    value: amount
                }("");
                require(success, "Transfer failed");
            }
        } else if (
            auctions[_id].highestBidder == msg.sender &&
            !auctions[_id].collected
        ) {
            auctions[_id].collected = true;
            _transfer(address(this), auctions[_id].highestBidder, _id);
        } else {
            require(
                auctions[_id].highestBidder != msg.sender,
                "You can't withdraw your bid as the highest bidder"
            );
            require(bids[msg.sender][_id] != 0, "Did you participate???");
            uint amount = bids[msg.sender][_id];
            bids[msg.sender][_id] = 0;
            (bool sent, ) = payable(msg.sender).call{value: amount}("");
            require(sent, "Withdrawal failed");
        }
    }

    /**
     * @dev Get details of the auction with that id */
    function getAuction(uint256 _id)
        public
        view
        returns (Auction memory auction)
    {
        return auctions[_id];
    }

    /**
     * @dev  Get the amount a user has bidded for a particular auction */
    function getUserBid(uint256 _id) public view returns (uint256) {
        return bids[msg.sender][_id];
    }

    /* Get details of all auctions*/
    function getAuctions() external view returns (Auction[] memory) {
        uint auctionsCount = _tokenIds.current();
        Auction[] memory allAuctions = new Auction[](auctionsCount);
        for (uint256 i = 0; i < auctionsCount; i++) {
            allAuctions[i] = auctions[i];
        }
        return allAuctions;
    }

    /**
     * @dev Get auctions the caller participated in
     */
    function getUserAuctions() external view returns (Auction[] memory) {
        uint paritcipationsCount = participatedIn[msg.sender].length;
        Auction[] memory allAuctions = new Auction[](paritcipationsCount);
        for (uint256 i = 0; i < paritcipationsCount; ++i) {
            uint index = participatedIn[msg.sender][i];
            allAuctions[i] = auctions[index];
        }
        return allAuctions;
    }

    /**
     * @dev Get how long is remaining to auction for a specific auction */
    function getTimeRemaining(uint256 _id)
        public
        view
        returns (uint256 time)
    {
        if (auctions[_id].endTime > block.timestamp) {
            return auctions[_id].endTime - block.timestamp;
        }
        return 0;
    }
}
