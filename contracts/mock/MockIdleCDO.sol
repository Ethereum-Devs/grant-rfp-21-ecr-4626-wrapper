//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../TrancheBaseUpgradeable.sol";

contract MockIdleCDO is TrancheBaseUpgradeable {
    ERC20 public token;

    function initialize(string memory uri_, address token_)
        external
        initializer
    {
        __TrancheBase_init(uri_);
        token = ERC20(token_);
        create(token, bytes("0x")); // vaultId 1 : AA
        create(token, bytes("0x")); // vaultId 2 : BB
    }

    function depositAA(uint256 _amount) external {
        deposit(1, _amount, msg.sender);
    }

    function depositBB(uint256 _amount) external {
        deposit(2, _amount, msg.sender);
    }

    function withdrawAA(uint256 _amount) external {
        withdraw(1, _amount, msg.sender, msg.sender);
    }

    function withdrawBB(uint256 _amount) external {
        withdraw(2, _amount, msg.sender, msg.sender);
    }
}
