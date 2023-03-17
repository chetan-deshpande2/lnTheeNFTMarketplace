// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract TestERC721 is ERC721Enumerable, Ownable {
    constructor() ERC721("Test ERC721", "T721") {}

    function mint(uint256 _tokenId) external {
        _safeMint(msg.sender, _tokenId);
    }
}
