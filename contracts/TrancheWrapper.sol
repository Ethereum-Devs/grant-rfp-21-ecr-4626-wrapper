//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IIdleCDO} from "./interfaces/IIdleCDO.sol";
import "./interfaces/IERC4626.sol";

contract TrancheWrapper is ERC20, IERC4626 {
    IIdleCDO public immutable IdleCDO;
    ERC20 public immutable token;
    ERC20 public immutable trancheToken;

    constructor(
        string memory _name,
        string memory _symbol,
        IIdleCDO _IdleCDO,
        ERC20 _trancheToken
    ) ERC20(_name, _symbol) {
        require(address(_IdleCDO) != address(0), "zero address");
        require(
            address(_IdleCDO.AATranche()) == address(_trancheToken) ||
                address(_IdleCDO.BBTranche()) == address(_trancheToken),
            "not correct trancheToken"
        );
        IdleCDO = _IdleCDO;
        token = ERC20(IdleCDO.token());
        trancheToken = _trancheToken;
    }

    function mint(uint256 shares, address receiver)
        external
        override
        returns (uint256 assets)
    {
        uint256 amount = (shares *
            IdleCDO.tranchePrice(address(trancheToken))) /
            IdleCDO.ONE_TRANCHE_TOKEN();
        assets = deposit(amount, receiver);
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public override returns (uint256 assets) {
        require(msg.sender == owner, "only owner's can be redeemed");
        (uint256 _withdrawn, uint256 _burntShares) = _withdraw(
            shares,
            receiver,
            msg.sender
        );
        assets = _withdrawn;
        emit Withdraw(msg.sender, receiver, owner, _withdrawn, _burntShares);
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
        uint256 amount = (assets * IdleCDO.ONE_TRANCHE_TOKEN()) /
            IdleCDO.tranchePrice(address(trancheToken));
        shares = redeem(amount, receiver, owner);
    }

    function _deposit(
        uint256 amount,
        address receiver,
        address depositor
    ) internal returns (uint256 deposited, uint256 mintedShares) {
        SafeERC20.safeTransferFrom(token, depositor, address(this), amount);
        token.approve(address(IdleCDO), amount);
        deposited = amount;
        if (IdleCDO.AATranche() == address(trancheToken)) {
            mintedShares = IdleCDO.depositAA(deposited);
        } else {
            mintedShares = IdleCDO.depositBB(deposited);
        }
        _mint(receiver, mintedShares);
    }

    function _withdraw(
        uint256 amount,
        address receiver,
        address sender
    ) internal returns (uint256 withdrawn, uint256 burntShares) {
        _burn(sender, amount);
        if (IdleCDO.AATranche() == address(trancheToken)) {
            withdrawn = IdleCDO.withdrawAA(amount);
        } else {
            withdrawn = IdleCDO.withdrawBB(amount);
        }
        burntShares = amount;
        SafeERC20.safeTransfer(token, receiver, withdrawn);
    }

    function totalAssets() public view override returns (uint256) {
        return
            (IdleCDO.getContractValue() * IdleCDO.getCurrentAARatio()) /
            IdleCDO.FULL_ALLOC();
    }

    function convertToShares(uint256 assets)
        public
        view
        override
        returns (uint256)
    {
        return
            (assets * IdleCDO.ONE_TRANCHE_TOKEN()) /
            IdleCDO.virtualPrice((address(this)));
    }

    function convertToAssets(uint256 shares)
        public
        view
        override
        returns (uint256)
    {
        return ((shares * IdleCDO.virtualPrice((address(this)))) /
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
        if (IdleCDO.limit() == 0) {
            return ~uint256(0) - IdleCDO.getContractValue();
        } else {
            return IdleCDO.limit() - IdleCDO.getContractValue();
        }
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

    function asset() external view override returns (address) {
        return address(token);
    }
}
