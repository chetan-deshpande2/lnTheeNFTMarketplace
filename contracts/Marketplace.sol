// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interface/IMarketplace.sol";
import "./Royalty.sol";
import "hardhat/console.sol";

contract Marketplace is IMarketplace, Ownable, Royalty, ReentrancyGuard {
    using Address for address;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    constructor(address _paymentTokenAddress) {
        _paymentToken = IERC20(_paymentTokenAddress);
    }

    IERC20 private immutable _paymentToken;

    bool private _isTradingEnabled = true;
    uint8 private _serviceFeeFraction = 20;
    uint256 private _actionTimeOutRangeMin = 1800; // 30 mins
    uint256 private _actionTimeOutRangeMax = 31536000; // One year - This can extend by owner is contract is working smoothly

    mapping(address => ERC721Market) private _erc721Market;

    enum ListingType {
        FLOOR_PRICE_BID, // 0
        AUCTION // 1
    }

    /**
     * @dev only if listing and bid is enabled
     * This is to help contract migration in case of upgrading contract
     */
    modifier onlyTradingOpen() {
        require(_isTradingEnabled, "Listing and bid are not enabled");
        _;
    }

    /**
     * @dev only if the entered timestamp is within the allowed range
     * This helps to not list or bid for too short or too long period of time
     */
    modifier onlyAllowedExpireTimestamp(uint256 expireTimestamp) {
        require(
            expireTimestamp - block.timestamp >= _actionTimeOutRangeMin,
            "Please enter a longer period of time"
        );
        require(
            expireTimestamp - block.timestamp <= _actionTimeOutRangeMax,
            "Please enter a shorter period of time"
        );
        _;
    }

    /**
     * @dev See {TheeNFTMarketplace-listToken}.
     * The timestamp set needs to be in the allowed range
     * Listing must be valid
     */
    function listToken(
        address contractAddress,
        uint256 tokenId,
        uint256 value,
        uint256 expireTimestamp,
        uint256 nftAmount,
        uint8 tokenType
    )
        external
        override
        onlyTradingOpen
        onlyAllowedExpireTimestamp(expireTimestamp)
    {
        Listing memory listing = Listing({
            tokenId: tokenId,
            value: value,
            seller: msg.sender,
            nftCount: nftAmount,
            tokenType: tokenType,
            expireTimestamp: expireTimestamp
        });

        // require(
        //     _isListingValid(contractAddress, listing),
        //     "Listing is not valid"
        // );

        _erc721Market[contractAddress].listings[tokenId] = listing;
        _erc721Market[contractAddress].tokenIdWithListing.add(tokenId);

        emit TokenListed(contractAddress, tokenId, listing);
    }

    /**
     * @dev See {TheeNFTMarketplace-delistToken}.
     * msg.sender must be the seller of the listing record
     */
    function delistToken(
        address contractAddress,
        uint256 tokenId
    ) external override {
        require(
            _erc721Market[contractAddress].listings[tokenId].seller ==
                msg.sender,
            "Only token seller can delist token"
        );

        emit TokenDelisted(
            contractAddress,
            tokenId,
            _erc721Market[contractAddress].listings[tokenId]
        );

        _delistToken(contractAddress, tokenId);
    }

    /**
     * @dev See {TheeNFTMarketplace-buyToken}.
     * Must have a valid listing
     * msg.sender must not the owner of token
     * msg.value must be at least sell price plus fees
     */
    function buyToken(
        address contractAddress,
        uint256 tokenId,
        uint256 tokenAmount,
        uint256 tokenType,
        uint256 paymentTokenType
    ) external payable override nonReentrant {
        Listing memory listing = _erc721Market[contractAddress].listings[
            tokenId
        ];
        require(
            _isListingValid(contractAddress, listing),
            "Token is not for sale"
        );
        // require(
        //     !_isTokenOwner(contractAddress, tokenId, msg.sender),
        //     "Token owner can't buy their own token"
        // );

        (uint256 _serviceFee, uint256 _royaltyFee) = _calculateFees(
            contractAddress,
            listing.value
        );
        if (paymentTokenType == 2) {
            require(
                msg.value >= listing.value,
                "The value send is below sale price"
            );

            Address.sendValue(
                payable(listing.seller),
                msg.value - _serviceFee - _royaltyFee
            );
            Address.sendValue(payable(owner()), _serviceFee);

            address _royaltyRecipient = royalty(contractAddress).recipient;
            if (_royaltyRecipient != address(0) && _royaltyFee > 0) {
                Address.sendValue(payable(_royaltyRecipient), _royaltyFee);
            }

            // Send token to buyer
            emit TokenBought({
                contractAddress: contractAddress,
                tokenId: tokenId,
                buyer: msg.sender,
                listing: listing,
                serviceFee: _serviceFee,
                royaltyFee: _royaltyFee
            });

            if (tokenType == 1) {
                IERC721(contractAddress).safeTransferFrom(
                    listing.seller,
                    msg.sender,
                    tokenId
                );
            } else {
                IERC1155(contractAddress).safeTransferFrom(
                    listing.seller,
                    msg.sender,
                    tokenId,
                    listing.nftCount,
                    "0x00"
                );
            }
            // Remove token listing
            _delistToken(contractAddress, tokenId);
            _removeBidOfBidder(contractAddress, tokenId, msg.sender);
        } else {
            _paymentToken.safeTransferFrom({
                from: msg.sender,
                to: listing.seller,
                value: listing.value
            });
            _paymentToken.safeTransferFrom({
                from: msg.sender,
                to: owner(),
                value: _serviceFee
            });
            address _royaltyRecipient = royalty(contractAddress).recipient;
            if (_royaltyRecipient != address(0) && _royaltyFee > 0) {
                _paymentToken.safeTransferFrom({
                    from: msg.sender,
                    to: _royaltyRecipient,
                    value: _royaltyFee
                });
            }
            // Send token to buyer
            emit TokenBought({
                contractAddress: contractAddress,
                tokenId: tokenId,
                buyer: msg.sender,
                listing: listing,
                serviceFee: _serviceFee,
                royaltyFee: _royaltyFee
            });

            if (tokenType == 1) {
                IERC721(contractAddress).safeTransferFrom(
                    listing.seller,
                    msg.sender,
                    tokenId
                );
            } else {
                IERC1155(contractAddress).safeTransferFrom(
                    listing.seller,
                    msg.sender,
                    tokenId,
                    listing.nftCount,
                    "0x00"
                );
            }
            // Remove token listing
            _delistToken(contractAddress, tokenId);
            _removeBidOfBidder(contractAddress, tokenId, msg.sender);
        }
    }

    /**
     * @dev delist a token - remove token id record and remove listing from mapping
     * @param tokenId erc721 token Id
     */
    function _delistToken(address contractAddress, uint256 tokenId) private {
        if (
            _erc721Market[contractAddress].tokenIdWithListing.contains(tokenId)
        ) {
            delete _erc721Market[contractAddress].listings[tokenId];
            _erc721Market[contractAddress].tokenIdWithListing.remove(tokenId);
        }
    }

    /**
     * @dev Check if a listing is valid or not
     * The seller must be the owner
     * The seller must have give this contract allowance
     * The sell price must be more than 0
     * The listing mustn't be expired
     */
    function _isListingValid(
        address contractAddress,
        Listing memory listing
    ) private view returns (bool isValid) {
        if (
            // _isTokenOwner(
            //     contractAddress,
            //     listing.tokenId,
            //     listing.seller,
            //     listing.tokenType
            // ) &&
            _isAllTokenApproved(
                contractAddress,
                listing.seller,
                listing.tokenType
            ) &&
            listing.value > 0 &&
            listing.expireTimestamp > block.timestamp
        ) {
            isValid = true;
        }
    }

    /**
     * @dev check if the account is the owner of this erc721 or erc1155 token
     */
    function _isTokenOwner(
        address contractAddress,
        uint256 tokenId,
        address account,
        uint256 tokenType
    ) private view returns (bool) {
        if (tokenType == 1) {
            IERC721 _erc721 = IERC721(contractAddress);
            try _erc721.ownerOf(tokenId) returns (address tokenOwner) {
                return tokenOwner == account;
            } catch {
                return false;
            }
        } else {
            IERC1155 _erc1155 = IERC1155(contractAddress);
            // _erc1155.balanceOf(account,tokenId);

            try _erc1155.balanceOf(account, tokenId) returns (uint256) {
                return true;
            } catch {
                return false;
            }
        }
    }

    // /**
    //  * @dev check if this contract has approved to transfer this erc721 token
    //  */
    // function _isTokenApproved(
    //     address contractAddress,
    //     uint256 tokenId,
    //     uint256 tokenType
    // ) private view returns (bool) {
    //     IERC721 _erc721 = IERC721(contractAddress);
    //     try _erc721.getApproved(tokenId) returns (address tokenOperator) {
    //         return tokenOperator == address(this);
    //     } catch {
    //         return false;
    //     }
    // }

    /**
     * @dev check if this contract has approved to all of this owner's erc721/erc1155 tokens
     */
    function _isAllTokenApproved(
        address contractAddress,
        address owner,
        uint256 tokenType
    ) private view returns (bool) {
        if (tokenType == 1) {
            IERC721 _erc721 = IERC721(contractAddress);
            return _erc721.isApprovedForAll(owner, address(this));
        } else {
            IERC1155 _erc1155 = IERC1155(contractAddress);
            return _erc1155.isApprovedForAll(owner, address(this));
        }
    }

    /**
     * @dev Calculate service fee, royalty fee and left value
     * @param value bidder address
     */
    function _calculateFees(
        address contractAddress,
        uint256 value
    ) private view returns (uint256 _serviceFee, uint256 _royaltyFee) {
        uint256 _royaltyFeeFraction = royalty(contractAddress).feeFraction;
        uint256 _baseFractions = 1000 +
            _serviceFeeFraction +
            _royaltyFeeFraction;

        _serviceFee = (value * _serviceFeeFraction) / _baseFractions;
        _royaltyFee = (value * _royaltyFeeFraction) / _baseFractions;
    }

    /**
     * @dev remove a bid of a bidder
     * @param tokenId erc721 token Id
     * @param bidder bidder address
     */
    function _removeBidOfBidder(
        address contractAddress,
        uint256 tokenId,
        address bidder
    ) private {
        if (
            _erc721Market[contractAddress].bids[tokenId].bidders.contains(
                bidder
            )
        ) {
            // Step 1: delete the bid and the address
            delete _erc721Market[contractAddress].bids[tokenId].bids[bidder];
            _erc721Market[contractAddress].bids[tokenId].bidders.remove(bidder);

            // Step 2: if no bid left
            if (
                _erc721Market[contractAddress].bids[tokenId].bidders.length() ==
                0
            ) {
                _erc721Market[contractAddress].tokenIdWithBid.remove(tokenId);
            }
        }
    }

    /**
     * @dev See {TheeMarketplace-enterBidForToken}.
     * People can only enter bid if bid is valid
     */
    function enterBidForToken(
        address contractAddress,
        uint256 tokenId,
        uint256 value,
        uint256 expireTimestamp,
        uint256 nftCount,
        uint256 tokenType,
        uint256 paymentOption
    )
        external
        payable
        override
        onlyTradingOpen
        onlyAllowedExpireTimestamp(expireTimestamp)
    {
        Bid memory bid = Bid(
            tokenId,
            value,
            msg.sender,
            nftCount,
            tokenType,
            expireTimestamp,
            paymentOption
        );
        require(_isBidValid(contractAddress, bid), "Bid is not valid");

        _erc721Market[contractAddress].tokenIdWithBid.add(tokenId);
        _erc721Market[contractAddress].bids[tokenId].bidders.add(msg.sender);
        _erc721Market[contractAddress].bids[tokenId].bids[msg.sender] = bid;
    }

    function makeBidForToken(
        address contractAddress,
        uint256 tokenId,
        uint256 value,
        uint256 expireTimestamp,
        uint256 nftCount,
        uint256 tokenType,
        uint256 paymentOption
    )
        external
        payable
        onlyTradingOpen
        onlyAllowedExpireTimestamp(expireTimestamp)
    {
        value = msg.value;
        Bid memory bid = Bid(
            tokenId,
            value,
            msg.sender,
            nftCount,
            tokenType,
            expireTimestamp,
            paymentOption
        );
        require(_isBidValid(contractAddress, bid), "Bid is not valid");

        _erc721Market[contractAddress].tokenIdWithBid.add(tokenId);
        _erc721Market[contractAddress].bids[tokenId].bidders.add(msg.sender);
        _erc721Market[contractAddress].bids[tokenId].bids[msg.sender] = bid;
    }

    /**
     * @dev See {TheeNFTMarketplace-withdrawBidForToken}.
     * There must be a bid exists
     * remove this bid record
     */
    function withdrawBidForToken(
        address contractAddress,
        uint256 tokenId
    ) external override {
        Bid memory bid = _erc721Market[contractAddress].bids[tokenId].bids[
            msg.sender
        ];
        require(
            bid.bidder == msg.sender,
            "This address doesn't have bid on this token"
        );

        emit TokenBidWithdrawn(contractAddress, tokenId, bid);
        _removeBidOfBidder(contractAddress, tokenId, msg.sender);
    }

    /**
     * @dev Check if an bid is valid or not
     * Bidder must not be the owner
     * Bidder must have enough balance same or more than bid price
     * Bidder must give the contract allowance same or more than bid price
     * Bid price must > 0
     * Bid mustn't been expired
     */
    function _isBidValid(
        address contractAddress,
        Bid memory bid
    ) private view returns (bool isValid) {
        if (
            bid.tokenType == 2 &&
            bid.value > 0 &&
            bid.expireTimestamp > block.timestamp
        ) {
            isValid = true;
        } else if (
            bid.tokenType == 1 && // !_isTokenOwner(contractAddress, bid.tokenId, bid.bidder) &&
            _paymentToken.allowance(bid.bidder, address(this)) >= bid.value &&
            _paymentToken.balanceOf(bid.bidder) >= bid.value &&
            bid.value > 0 &&
            bid.expireTimestamp > block.timestamp
        ) {
            isValid = true;
        }
    }

    /**
     * @dev See {TheeNFTMarketplace-acceptBidForToken}.
     * Must be owner of this token
     * Must have approved this contract to transfer token
     * Must have a valid existing bid that matches
     */
    function acceptBidForToken(
        address contractAddress,
        uint256 tokenId,
        address bidder,
        uint256 tokenType,
        uint256 nftAmount,
        uint256 paymentTokenType,
        uint256 value
    ) external payable override nonReentrant {
        // require(
        //     _isTokenOwner(contractAddress, tokenId, msg.sender),
        //     "Only token owner can accept bid of token"
        // );
        require(
            // _isTokenApproved(contractAddress, tokenId) ||
            _isAllTokenApproved(contractAddress, msg.sender, tokenType),
            "The token is not approved to transfer by the contract"
        );

        Bid memory existingBid = getBidderTokenBid(
            contractAddress,
            tokenId,
            bidder
        );
        require(
            existingBid.tokenId == tokenId &&
                existingBid.value == value &&
                existingBid.bidder == bidder,
            "This token doesn't have a matching bid"
        );

        address _royaltyRecipient = royalty(contractAddress).recipient;
        (uint256 _serviceFee, uint256 _royaltyFee) = _calculateFees(
            contractAddress,
            existingBid.value
        );
        if (paymentTokenType == 2) {
            require(
                msg.value >= existingBid.value,
                "The value send is below sale price"
            );

            Address.sendValue(
                payable(existingBid.bidder),
                msg.value - _serviceFee - _royaltyFee
            );
            Address.sendValue(payable(owner()), _serviceFee);

            if (_royaltyRecipient != address(0) && _royaltyFee > 0) {
                Address.sendValue(payable(_royaltyRecipient), _royaltyFee);
            }
        } else {
            _paymentToken.safeTransferFrom({
                from: existingBid.bidder,
                to: msg.sender,
                value: existingBid.value - _serviceFee - _royaltyFee
            });
            _paymentToken.safeTransferFrom({
                from: existingBid.bidder,
                to: owner(),
                value: _serviceFee
            });
            if (_royaltyRecipient != address(0) && _royaltyFee > 0) {
                _paymentToken.safeTransferFrom({
                    from: existingBid.bidder,
                    to: _royaltyRecipient,
                    value: _royaltyFee
                });
            }

            if (tokenType == 1) {
                IERC721(contractAddress).safeTransferFrom({
                    from: msg.sender,
                    to: existingBid.bidder,
                    tokenId: tokenId
                });
            } else {
                IERC1155(contractAddress).safeTransferFrom({
                    from: msg.sender,
                    to: existingBid.bidder,
                    id: tokenId,
                    amount: nftAmount,
                    data: "0x00"
                });
            }

            emit TokenBidAccepted({
                contractAddress: contractAddress,
                tokenId: tokenId,
                seller: msg.sender,
                bid: existingBid,
                serviceFee: _serviceFee,
                royaltyFee: _royaltyFee
            });

            // Remove token listing
            _delistToken(contractAddress, tokenId);
            _removeBidOfBidder(contractAddress, tokenId, existingBid.bidder);
        }
    }

    /**
     * @dev See {TheeNFTMarketplace-AuctionEnd}.

     */

    function auctionEnd() public payable nonReentrant {}

    /* GETTERS */

    // to get token address through types
    // types:
    // WBNB
    function getTokensByType(
        uint256 _type
    ) public view returns (IERC20 _token) {
        require(_type != 2, "type 2 is for Default platform Token");

        if (_type == 1) {
            return _paymentToken;
        }
    }

    /**
     * @dev See {TheeNFTMarketplace-getBidderTokenBid}.
     */
    function getBidderTokenBid(
        address contractAddress,
        uint256 tokenId,
        address bidder
    ) public view override returns (Bid memory validBid) {
        Bid memory bid = _erc721Market[contractAddress].bids[tokenId].bids[
            bidder
        ];
        if (_isBidValid(contractAddress, bid)) {
            validBid = bid;
        }
    }

    /**
     * @dev See {TheeNFTMarketplace-getTokenBids}.
     */
    function getTokenBids(
        address contractAddress,
        uint256 tokenId
    ) external view override returns (Bid[] memory bids) {
        uint256 bidderCount = _erc721Market[contractAddress]
            .bids[tokenId]
            .bidders
            .length();

        bids = new Bid[](bidderCount);
        for (uint256 i; i < bidderCount; i++) {
            address bidder = _erc721Market[contractAddress]
                .bids[tokenId]
                .bidders
                .at(i);
            Bid memory bid = _erc721Market[contractAddress].bids[tokenId].bids[
                bidder
            ];
            if (_isBidValid(contractAddress, bid)) {
                bids[i] = bid;
            }
        }
    }

    /**
    @dev See {TheeNFTMarketplace-CheckBid}
    **/

    function CheckBidisValid(
        address contractAddress,
        uint256 tokenId
    ) internal view returns (bool) {
        Bid memory bid = _erc721Market[contractAddress].bids[tokenId].bids[
            contractAddress
        ];
        return true;
        // Listing memory listing = _erc721Market[contractAddress].listings[
        //     tokenId
        // ];
        // if (_isListingValid(contractAddress, listing)) {
        //     validListing = listing;
        // }
    }

    /**
     * @dev See {TheeNFTMarketplace-getTokenHighestBid}.
     */
    function getTokenHighestBid(
        address contractAddress,
        uint256 tokenId
    ) public view override returns (Bid memory highestBid) {
        highestBid = Bid(tokenId, 0, address(0), 0, 0, 0, 1);
        uint256 bidderCount = _erc721Market[contractAddress]
            .bids[tokenId]
            .bidders
            .length();
        for (uint256 i; i < bidderCount; i++) {
            address bidder = _erc721Market[contractAddress]
                .bids[tokenId]
                .bidders
                .at(i);
            Bid memory bid = _erc721Market[contractAddress].bids[tokenId].bids[
                bidder
            ];
            if (
                _isBidValid(contractAddress, bid) &&
                bid.value > highestBid.value
            ) {
                highestBid = bid;
            }
        }
    }

    /**
     * @dev See {TheeNFTMarketplace-getTokenHighestBids}.
     */
    function getTokenHighestBids(
        address contractAddress,
        uint256 from,
        uint256 size
    ) public view override returns (Bid[] memory highestBids) {
        uint256 tokenCount = numTokenWithBids(contractAddress);

        if (from < tokenCount && size > 0) {
            uint256 querySize = size;
            if ((from + size) > tokenCount) {
                querySize = tokenCount - from;
            }
            highestBids = new Bid[](querySize);
            for (uint256 i = 0; i < querySize; i++) {
                highestBids[i] = getTokenHighestBid({
                    contractAddress: contractAddress,
                    tokenId: _erc721Market[contractAddress].tokenIdWithBid.at(
                        i + from
                    )
                });
            }
        }
    }

    function getBidderBids(
        address contractAddress,
        address bidder,
        uint256 from,
        uint256 size
    ) external view override returns (Bid[] memory bidderBids) {
        uint256 tokenCount = numTokenWithBids(contractAddress);

        if (from < tokenCount && size > 0) {
            uint256 querySize = size;
            if ((from + size) > tokenCount) {
                querySize = tokenCount - from;
            }
            bidderBids = new Bid[](querySize);
            for (uint256 i = 0; i < querySize; i++) {
                bidderBids[i] = getBidderTokenBid({
                    contractAddress: contractAddress,
                    tokenId: _erc721Market[contractAddress].tokenIdWithBid.at(
                        i + from
                    ),
                    bidder: bidder
                });
            }
        }
    }

    /**
     * @dev See {TheeNFTMarketplace-numTokenWithBids}.
     */
    function numTokenWithBids(
        address contractAddress
    ) public view override returns (uint256) {
        return _erc721Market[contractAddress].tokenIdWithBid.length();
    }

    /*
     * @dev See {TheeNFTMarketplace-getTokenListing}.
     */
    function getTokenListing(
        address contractAddress,
        uint256 tokenId
    ) public view override returns (Listing memory validListing) {
        Listing memory listing = _erc721Market[contractAddress].listings[
            tokenId
        ];
        if (_isListingValid(contractAddress, listing)) {
            validListing = listing;
        }
    }

    /**
     * @dev Enable to disable Bids and Listing
     */
    function changeMarketplaceStatus(bool enabled) external onlyOwner {
        _isTradingEnabled = enabled;
    }

    /**
     * @dev See {TheeNFTMarketplace-actionTimeOutRangeMin}.
     */
    function actionTimeOutRangeMin() external view override returns (uint256) {
        return _actionTimeOutRangeMin;
    }

    /**
     * @dev See {TheeNFTMarketplace-actionTimeOutRangeMax}.
     */
    function actionTimeOutRangeMax() external view override returns (uint256) {
        return _actionTimeOutRangeMax;
    }

    /**
     * @dev See {TheeNFTMarketplace-paymentToken}.
     */
    function paymentToken() external view override returns (address) {
        return address(_paymentToken);
    }

    /**
     * @dev Change minimum listing and bid time range
     */
    function changeMinActionTimeLimit(uint256 timeInSec) external onlyOwner {
        _actionTimeOutRangeMin = timeInSec;
    }

    /**
     * @dev Change maximum listing and bid time range
     */
    function changeMaxActionTimeLimit(uint256 timeInSec) external onlyOwner {
        _actionTimeOutRangeMax = timeInSec;
    }

    /**
     * @dev See {TheeNFTMarketplace-serviceFee}.
     */
    function serviceFee() external view override returns (uint8) {
        return _serviceFeeFraction;
    }

    /**
     * @dev Change withdrawal fee percentage.
     * @param serviceFeeFraction_ Fraction of withdrawal fee based on 1000
     */
    function changeSeriveFee(uint8 serviceFeeFraction_) external onlyOwner {
        require(
            serviceFeeFraction_ <= 25,
            "Attempt to set percentage higher than 2.5%."
        );

        _serviceFeeFraction = serviceFeeFraction_;
    }
}
