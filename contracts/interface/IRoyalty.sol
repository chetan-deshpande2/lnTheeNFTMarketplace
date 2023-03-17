// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

interface IRoyalty {
    struct CollectionRoyalty {
        address recipient;
        uint256 feeFraction;
        address setBy;
    }

    // Who can set: ERC721 owner
    event SetRoyalty(
        address indexed contractAddress,
        address indexed recipient,
        uint256 feeFraction
    );

    /**
     * @dev Royalty fee
     * @param contractAddress to read royalty
     * @return royalty information
     */
    function royalty(
        address contractAddress
    ) external view returns (CollectionRoyalty memory);

    /**
     * @dev Royalty fee
     * @param contractAddress to read royalty
     */
    function setRoyalty(
        address contractAddress,
        address recipient,
        uint256 feeFraction
    ) external;
}
