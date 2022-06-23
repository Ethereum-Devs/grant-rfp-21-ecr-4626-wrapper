// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../TrancheWrapper.sol";

contract MockIdleCDO {
    using SafeERC20 for ERC20;

    ERC20 public immutable token;

    uint256 public constant ONE_TRANCHE_TOKEN = 10**18;
    address public AATranche;
    address public BBTranche;
    // one `token` (eg for DAI 10**18)
    uint256 public oneToken;
    // Price for minting AA tranche, in underlyings
    uint256 public priceAA;
    // Price for minting BB tranche, in underlyings
    uint256 public priceBB;

    constructor(ERC20 token_) {
        token = token_;
        string memory _symbol = token.symbol();
        AATranche = address(
            new TrancheWrapper(
                _concat(string("IdleCDO AA Tranche - "), _symbol),
                _concat(string("AA_"), _symbol),
                token_
            )
        );
        BBTranche = address(
            new TrancheWrapper(
                _concat(string("IdleCDO BB Tranche - "), _symbol),
                _concat(string("BB_"), _symbol),
                token_
            )
        );
        oneToken = 10**18;
        priceAA = oneToken;
        priceBB = oneToken;
    }

    /// @notice pausable
    /// @dev msg.sender should approve this contract first to spend `_amount` of `token`
    /// @param _amount amount of `token` to deposit
    /// @return AA tranche tokens minted
    function depositAA(uint256 _amount) external returns (uint256) {
        return _deposit(_amount, AATranche);
    }

    /// @notice pausable in _deposit
    /// @dev msg.sender should approve this contract first to spend `_amount` of `token`
    /// @param _amount amount of `token` to deposit
    /// @return BB tranche tokens minted
    function depositBB(uint256 _amount) external returns (uint256) {
        return _deposit(_amount, BBTranche);
    }

    /// @notice pausable in _deposit
    /// @param _amount amount of AA tranche tokens to burn
    /// @return underlying tokens redeemed
    function withdrawAA(uint256 _amount) external returns (uint256) {
        return _withdraw(_amount, AATranche);
    }

    /// @notice pausable
    /// @param _amount amount of BB tranche tokens to burn
    /// @return underlying tokens redeemed
    function withdrawBB(uint256 _amount) external returns (uint256) {
        return _withdraw(_amount, BBTranche);
    }

    /// @param _tranche tranche address
    /// @return tranche price
    function tranchePrice(address _tranche) external view returns (uint256) {
        return _tranchePrice(_tranche);
    }

    /// @notice method used to deposit `token` and mint tranche tokens
    /// Ideally users should deposit right after an `harvest` call to maximize profit
    /// @dev this contract must be approved to spend at least _amount of `token` before calling this method
    /// automatically reverts on lending provider default (_strategyPrice decreased)
    /// @param _amount amount of underlyings (`token`) to deposit
    /// @param _tranche tranche address
    /// @return _minted number of tranche tokens minted
    function _deposit(uint256 _amount, address _tranche)
        internal
        returns (uint256 _minted)
    {
        if (_amount == 0) {
            return _minted;
        }
        // get underlyings from sender
        token.safeTransferFrom(msg.sender, address(this), _amount);
        // mint tranche tokens according to the current tranche price
        _minted = _mintShares(_amount, msg.sender, _tranche);
    }

    /// @notice It allows users to burn their tranche token and redeem their principal + interest back
    /// @dev automatically reverts on lending provider default (_strategyPrice decreased).
    /// @param _amount in tranche tokens
    /// @param _tranche tranche address
    /// @return toRedeem number of underlyings redeemed
    function _withdraw(uint256 _amount, address _tranche)
        internal
        returns (uint256 toRedeem)
    {
        toRedeem = (_amount * _tranchePrice(_tranche)) / ONE_TRANCHE_TOKEN;
        TrancheWrapper(_tranche).burn(msg.sender, _amount);
        // send underlying to msg.sender
        token.safeTransfer(msg.sender, toRedeem);
    }

    /// @notice mint tranche tokens and updates tranche last NAV
    /// @param _amount, in underlyings, to convert in tranche tokens
    /// @param _to receiver address of the newly minted tranche tokens
    /// @param _tranche tranche address
    /// @return _minted number of tranche tokens minted
    function _mintShares(
        uint256 _amount,
        address _to,
        address _tranche
    ) internal returns (uint256 _minted) {
        // calculate # of tranche token to mint based on current tranche price: _amount / tranchePrice
        _minted = (_amount * ONE_TRANCHE_TOKEN) / _tranchePrice(_tranche);
        TrancheWrapper(_tranche).mint(_to, _minted);
    }

    /// @param _tranche tranche address
    /// @return last saved tranche price, in underlyings
    function _tranchePrice(address _tranche) internal view returns (uint256) {
        if (TrancheWrapper(_tranche).totalSupply() == 0) {
            return oneToken;
        }
        return _tranche == AATranche ? priceAA : priceBB;
    }

    /// @notice concat 2 strings in a single one
    /// @param a first string
    /// @param b second string
    /// @return new string with a and b concatenated
    function _concat(string memory a, string memory b)
        internal
        pure
        returns (string memory)
    {
        return string(abi.encodePacked(a, b));
    }
}
