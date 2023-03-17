// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/IRoyalty.sol";

contract Royalty is IRoyalty, Ownable {
    uint256 public defaultRoyaltyFraction = 20; // By the factor of 1000, 2%
    uint256 public royaltyUpperLimit = 80; // By the factor of 1000, 8%

    mapping(address => CollectionRoyalty) private _collectionRoyalty;

    function _nftOwner(address contractAddress) private view returns (address) {
        try Ownable(contractAddress).owner() returns (address _contractOwner) {
            return _contractOwner;
        } catch {
            return address(0);
        }
    }

    function royalty(
        address contractAddress
    ) public view override returns (CollectionRoyalty memory) {
        if (_collectionRoyalty[contractAddress].setBy != address(0)) {
            return _collectionRoyalty[contractAddress];
        }

        address nftOwner = _nftOwner(contractAddress);
        if (nftOwner != address(0)) {
            return
                CollectionRoyalty({
                    recipient: nftOwner,
                    feeFraction: defaultRoyaltyFraction,
                    setBy: address(0)
                });
        }

        return
            CollectionRoyalty({
                recipient: address(0),
                feeFraction: 0,
                setBy: address(0)
            });
    }

    function setRoyalty(
        address contractAddress,
        address newRecipient,
        uint256 feeFraction
    ) external override {
        require(
            feeFraction <= royaltyUpperLimit,
            "Please set the royalty percentange below allowed range"
        );

        require(
            msg.sender == royalty(contractAddress).recipient,
            "Only ERC721 royalty recipient is allowed to set Royalty"
        );

        _collectionRoyalty[contractAddress] = CollectionRoyalty({
            recipient: newRecipient,
            feeFraction: feeFraction,
            setBy: msg.sender
        });

        emit SetRoyalty({
            contractAddress: contractAddress,
            recipient: newRecipient,
            feeFraction: feeFraction
        });
    }

    function setRoyaltyForCollection(
        address contractAddress,
        address newRecipient,
        uint256 feeFraction
    ) external onlyOwner {
        require(
            feeFraction <= royaltyUpperLimit,
            "Please set the royalty percentange below allowed range"
        );

        require(
            royalty(contractAddress).setBy == address(0),
            "Collection royalty recipient already set"
        );

        _collectionRoyalty[contractAddress] = CollectionRoyalty({
            recipient: newRecipient,
            feeFraction: feeFraction,
            setBy: msg.sender
        });

        emit SetRoyalty({
            contractAddress: contractAddress,
            recipient: newRecipient,
            feeFraction: feeFraction
        });
    }

    function updateRoyaltyUpperLimit(
        uint256 _newUpperLimit
    ) external onlyOwner {
        royaltyUpperLimit = _newUpperLimit;
    }
}
