// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IIdleCDO} from "./interfaces/IIdleCDO.sol";
import "./interfaces/IERC4626.sol";
import "./interfaces/ITrancheWrapper.sol";

contract TrancheWrapper is ERC20, ITrancheWrapper, IERC4626 {
    address public immutable minter;

    IIdleCDO public immutable IdleCDO;
    ERC20 public immutable token;

    constructor(
        string memory _name,
        string memory _symbol,
        ERC20 token_
    ) ERC20(_name, _symbol) {
        IdleCDO = IIdleCDO(msg.sender);
        token = token_;
        minter = msg.sender;
    }

    /// @param account that should receive the tranche tokens
    /// @param amount of tranche tokens to mint
    function mint(address account, uint256 amount) external {
        require(msg.sender == minter, "TRANCHE:!AUTH");
        _mint(account, amount);
    }

    function mint(uint256 shares, address receiver)
        external
        override
        returns (uint256 assets)
    {
        assets = previewMint(shares);
        _deposit(assets, msg.sender, msg.sender);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /// @param account that should have the tranche tokens burned
    /// @param amount of tranche tokens to burn
    function burn(address account, uint256 amount) external {
        require(msg.sender == minter, "TRANCHE:!AUTH");
        _burn(account, amount);
    }

    function vault() external view override returns (address) {
        return address(IdleCDO);
    }

    function asset() external view override returns (address) {
        return address(token);
    }

    function deposit(uint256 assets, address receiver)
        public
        override
        returns (uint256 shares)
    {
        (assets, shares) = _deposit(assets, receiver, msg.sender);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public override returns (uint256 shares) {
        (uint256 _withdrawn, uint256 _burntShares) = _withdraw(
            assets,
            receiver,
            msg.sender
        );
        shares = _burntShares;
        emit Withdraw(msg.sender, receiver, owner, _withdrawn, _burntShares);
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public override returns (uint256 assets) {
        assets = previewRedeem(shares);
        (uint256 _withdrawn, uint256 _burntShares) = _withdraw(
            assets,
            receiver,
            msg.sender
        );
        emit Withdraw(msg.sender, receiver, owner, _withdrawn, _burntShares);
    }

    function _deposit(
        uint256 amount,
        address receiver,
        address depositor
    ) internal returns (uint256 deposited, uint256 mintedShares) {
        SafeERC20.safeTransferFrom(token, depositor, address(this), amount);
        token.approve(address(IdleCDO), ~uint256(0));
        if (isTrancheAA()) {
            deposited = amount;
            mintedShares = IdleCDO.depositAA(deposited);
        } else {
            deposited = amount;
            mintedShares = IdleCDO.depositBB(deposited);
        }
        SafeERC20.safeTransfer(this, receiver, mintedShares);
    }

    function _withdraw(
        uint256 amount,
        address receiver,
        address sender
    ) internal returns (uint256 withdrawn, uint256 burntShares) {
        burntShares = previewWithdraw(amount);
        SafeERC20.safeTransferFrom(this, sender, address(this), burntShares);
        if (isTrancheAA()) {
            withdrawn = IdleCDO.withdrawAA(burntShares);
        } else {
            withdrawn = IdleCDO.withdrawBB(burntShares);
        }
        SafeERC20.safeTransfer(token, receiver, withdrawn);
    }

    function totalAssets() public view override returns (uint256) {
        return token.balanceOf(address(IdleCDO));
    }

    function convertToShares(uint256 assets)
        public
        view
        override
        returns (uint256)
    {
        return
            (assets * IdleCDO.ONE_TRANCHE_TOKEN()) /
            IdleCDO.tranchePrice(address(this));
    }

    function convertToAssets(uint256 shares)
        public
        view
        override
        returns (uint256)
    {
        return ((shares * IdleCDO.tranchePrice(address(this))) /
            IdleCDO.ONE_TRANCHE_TOKEN());
    }

    function previewDeposit(uint256 assets)
        public
        view
        override
        returns (uint256)
    {
        return convertToShares(assets);
    }

    function previewMint(uint256 shares)
        public
        view
        override
        returns (uint256)
    {
        return convertToAssets(shares);
    }

    function previewWithdraw(uint256 assets)
        public
        view
        override
        returns (uint256)
    {
        return convertToShares(assets);
    }

    function previewRedeem(uint256 shares)
        public
        view
        override
        returns (uint256)
    {
        return convertToAssets(shares);
    }

    function maxDeposit(address _account)
        public
        view
        override
        returns (uint256)
    {
        _account;
        return ~uint256(0) - totalAssets();
    }

    function maxMint(address _account) public view override returns (uint256) {
        return convertToShares(maxDeposit(_account));
    }

    function maxWithdraw(address owner)
        external
        view
        override
        returns (uint256)
    {
        return convertToAssets(this.balanceOf(owner));
    }

    function maxRedeem(address owner) external view override returns (uint256) {
        return this.balanceOf(owner);
    }

    function isTrancheAA() private view returns (bool) {
        return IdleCDO.AATranche() == address(this);
    }
}
