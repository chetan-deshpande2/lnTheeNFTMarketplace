// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

interface IMarketplace {
    struct Listing {
        uint256 tokenId;
        uint256 value;
        address seller;
        uint256 nftCount;
        uint256 tokenType;
        uint256 expireTimestamp;
    }

    struct Bid {
        uint256 tokenId;
        uint256 value;
        address bidder;
        uint256 nftCount;
        uint256 tokenType;
        uint256 expireTimestamp;
        uint256 paymentOption;
    }

    struct TokenBids {
        EnumerableSet.AddressSet bidders;
        mapping(address => Bid) bids;
    }

    struct ERC721Market {
        EnumerableSet.UintSet tokenIdWithListing;
        mapping(uint256 => Listing) listings;
        EnumerableSet.UintSet tokenIdWithBid;
        mapping(uint256 => TokenBids) bids;
    }

    event TokenListed(
        address indexed contractAddress,
        uint256 indexed tokenId,
        Listing listing
    );

    event TokenDelisted(
        address indexed contractAddress,
        uint256 indexed tokenId,
        Listing listing
    );

    event TokenBought(
        address indexed contractAddress,
        uint256 indexed tokenId,
        address indexed buyer,
        Listing listing,
        uint256 serviceFee,
        uint256 royaltyFee
    );

    event TokenBidEntered(
        address indexed contractAddress,
        uint256 indexed tokenId,
        Bid bid
    );

    event TokenBidWithdrawn(
        address indexed contractAddress,
        uint256 indexed tokenId,
        Bid bid
    );

    event TokenBidAccepted(
        address indexed contractAddress,
        uint256 indexed tokenId,
        address indexed seller,
        Bid bid,
        uint256 serviceFee,
        uint256 royaltyFee
    );

    /**
     * @dev List token for sale
     * @param tokenId erc721 token Id
     * @param value min price to sell the token
     * @param expireTimestamp when would this listing expire
     */
    function listToken(
        address contractAddress,
        uint256 tokenId,
        uint256 value,
        uint256 expireTimestamp,
        uint256 nftAmount,
        uint8 tokenType
    ) external;

    /**
     * @dev Delist token for sale
     * @param tokenId erc721 token Id
     */
    function delistToken(address contractAddress, uint256 tokenId) external;

    /**
     * @dev Buy token
     * @param tokenId erc721 token Id
     */
    function buyToken(
        address contractAddress,
        uint256 tokenId,
        uint256 tokenAmount,
        uint256 tokenType,
        uint256 paymentTokenType
    ) external payable;

    /**
     * @dev Enter bid for token
     * @param tokenId erc721 token Id
     * @param value price in payment token
     * @param expireTimestamp when would this bid expire
     */
    function enterBidForToken(
        address contractAddress,
        uint256 tokenId,
        uint256 value,
        uint256 expireTimestamp,
        uint256 nftCount,
        uint256 tokenType,
        uint256 paymentOption
    ) external payable;

    /**
     * @dev Withdraw bid for token
     * @param tokenId erc721 token Id
     */
    function withdrawBidForToken(
        address contractAddress,
        uint256 tokenId
    ) external;

    /**
     * @dev get bidder's bid on a token
     * @param tokenId erc721 token Id
     * @param bidder address of a bidder
     * @return Valid bid or empty bid
     */
    function getBidderTokenBid(
        address contractAddress,
        uint256 tokenId,
        address bidder
    ) external view returns (Bid memory);

    /**
     * @dev Accept a bid of token from a bidder
     * @param tokenId erc721 token Id
     * @param bidder bidder address
     * @param value value of a bid to avoid frontrun attack
     */
    function acceptBidForToken(
        address contractAddress,
        uint256 tokenId,
        address bidder,
        uint256 tokenType,
        uint256 nftAmount,
        uint256 paymentTokenType,
        uint256 value
    ) external payable;

    /**
     * @dev get highest bid of a token
     * @param tokenId erc721 token Id
     * @return Valid highest bid or empty bid
     */
    function getTokenHighestBid(
        address contractAddress,
        uint256 tokenId
    ) external view returns (Bid memory);

    /**
     * @dev get current highest bids
     * @param from index to start
     * @param size size to query
     * @return current highest bids
     * This to help batch query when list gets big
     */
    function getTokenHighestBids(
        address contractAddress,
        uint256 from,
        uint256 size
    ) external view returns (Bid[] memory);

    /**
     * @dev get all bids of a bidder address
     * @return All valid bids of a bidder
     */
    function getBidderBids(
        address contractAddress,
        address bidder,
        uint256 from,
        uint256 size
    ) external view returns (Bid[] memory);

    /**
     * @dev get current listing of a token
     * @param tokenId contract token Id
     * @return current valid listing or empty listing struct
     */
    function getTokenListing(
        address contractAddress,
        uint256 tokenId
    ) external view returns (Listing memory);

    /**
     * @dev get count of tokens with bid(s)
     */
    function numTokenWithBids(
        address contractAddress
    ) external view returns (uint256);

    /**
     * @dev get all valid bids of a token
     * @param tokenId erc721 token Id
     * @return Valid bids of a token
     */
    function getTokenBids(
        address contractAddress,
        uint256 tokenId
    ) external view returns (Bid[] memory);

    /**
     * @dev Surface minimum listing and bid time range
     */
    function actionTimeOutRangeMin() external view returns (uint256);

    /**
     * @dev Surface maximum listing and bid time range
     */
    function actionTimeOutRangeMax() external view returns (uint256);

    /**
     * @dev Payment token address
     */
    function paymentToken() external view returns (address);

    /**
     * @dev Service fee
     * @return fee fraction based on 1000
     */
    function serviceFee() external view returns (uint8);
}
