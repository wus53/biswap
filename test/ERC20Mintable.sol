//SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "solmate/tokens/ERC20.sol";

contract ERC20Mintable is ERC20 {
    constructor(string memory _name, string memory _symbol, uint8 _decimals) ERC20(_name, _symbol, _decimals) {}

    function mint(address _to, uint256 amount) public {
        _mint(_to, amount);
    }
}
