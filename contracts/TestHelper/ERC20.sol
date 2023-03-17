// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestERC20 is ERC20 {
    constructor() ERC20("Test ERC20", "T20") {}

    function mint(uint256 amount) external {
        _mint(msg.sender, amount);
    }
}
