// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.26;

contract RWAToken is ERC20 {
    address public minter;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        minter = msg.sender;
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == minter, "Only minter can mint");
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        require(msg.sender == minter, "Only minter can burn");
        _burn(from, amount);
    }
}