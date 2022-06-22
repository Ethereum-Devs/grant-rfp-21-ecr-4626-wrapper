//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TrancheBaseUpgradeable is ERC1155Upgradeable {
    event Deposit(
        address indexed caller,
        address indexed owner,
        ERC20 indexed asset,
        uint256 assets,
        uint256 shares
    );

    event Withdraw(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256 vaultId,
        uint256 assets,
        uint256 shares
    );

    event Create(ERC20 indexed asset, uint256 id, bytes vaultData);

    /// @notice Vault id tracking and total supply of different Vaults
    uint256 public totalSupply;

    /// @notice Track vault underlying assets
    mapping(uint256 => Vault) public vaults;

    /// @notice Vault Data
    /// @param asset underlying token of this vaultId
    /// @param totalSupply shares tracking for each vaultId, needed for previews()
    /// @param vaultData additional logic to this vaultId, extend
    struct Vault {
        ERC20 asset;
        uint256 totalSupply;
        bytes vaultData;
    }

    function __TrancheBase_init(string memory uri_) internal initializer {
        __ERC1155_init(uri_);
    }

    /// @notice Create new Vault
    /// @param asset underlying token of new vault
    /// @param vaultData any encoded additional data for vault eg. metadata uri string
    /// @dev encoded data can be anything. implementations of other functions will need to know how to decode tho.
    function create(ERC20 asset, bytes memory vaultData)
        internal
        virtual
        returns (uint256 id)
    {
        unchecked {
            id = ++totalSupply;
        }

        vaults[id].asset = asset;

        /// @dev Structure of this encoded data is left to the child contract, can be anything
        /// (rewards, fees, metadata) = abi.decode(data, ([RewardsModule, FeeModule, string]))
        vaults[id].vaultData = vaultData;

        emit Create(asset, id, vaultData);
    }

    /*///////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function deposit(
        uint256 vaultId,
        uint256 assets,
        address receiver
    ) internal returns (uint256 shares) {
        Vault memory vault = vaults[vaultId];

        require((shares = previewDeposit(vaultId, assets)) != 0, "ZERO_SHARES");

        vault.asset.transferFrom(msg.sender, address(this), assets);

        _mint(receiver, vaultId, shares, vaults[vaultId].vaultData);

        vaults[vaultId].totalSupply += shares;

        emit Deposit(msg.sender, receiver, vault.asset, assets, shares);

        afterDeposit(vaultId, assets, shares);
    }

    function mint(
        uint256 vaultId,
        uint256 shares,
        address receiver
    ) internal returns (uint256 assets) {
        Vault memory vault = vaults[vaultId];

        assets = previewMint(vaultId, shares);

        vault.asset.transferFrom(msg.sender, address(this), assets);

        _mint(receiver, vaultId, shares, vaults[vaultId].vaultData);

        vaults[vaultId].totalSupply += shares;

        emit Deposit(msg.sender, receiver, vault.asset, assets, shares);

        afterDeposit(vaultId, assets, shares);
    }

    function withdraw(
        uint256 vaultId,
        uint256 assets,
        address receiver,
        address owner
    ) internal returns (uint256 shares) {
        Vault memory vault = vaults[vaultId];

        shares = previewWithdraw(vaultId, assets);

        if (msg.sender != owner)
            require(isApprovedForAll(owner, msg.sender), "NOT_OPERATOR");

        beforeWithdraw(vaultId, assets, shares);

        _burn(owner, vaultId, shares);

        vaults[vaultId].totalSupply -= shares;

        emit Withdraw(msg.sender, receiver, owner, vaultId, assets, shares);

        vault.asset.transfer(receiver, assets);
    }

    function redeem(
        uint256 vaultId,
        uint256 shares,
        address receiver,
        address owner
    ) internal returns (uint256 assets) {
        if (msg.sender != owner)
            require(isApprovedForAll(owner, msg.sender), "NOT_OPERATOR");
        require((assets = previewRedeem(vaultId, shares)) != 0, "ZERO_ASSETS");

        Vault memory vault = vaults[vaultId];
        beforeWithdraw(vaultId, assets, shares);

        _burn(owner, vaultId, shares);

        vaults[vaultId].totalSupply -= shares;

        emit Withdraw(msg.sender, receiver, owner, vaultId, assets, shares);

        vault.asset.transfer(receiver, assets);
    }

    /*///////////////////////////////////////////////////////////////
                           ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice can be overriden depending on the specific logic
    function totalAssets(uint256 vaultId)
        public
        view
        virtual
        returns (uint256)
    {
        return vaults[vaultId].asset.balanceOf(address(this));
    }

    /// @notice can be overriden depending on the specific logic
    function convertToShares(uint256 vaultId, uint256 assets)
        public
        view
        virtual
        returns (uint256)
    {
        uint256 supply = vaults[vaultId].totalSupply;

        return supply == 0 ? assets : (assets * supply) / totalAssets(vaultId);
    }

    /// @notice can be overriden depending on the specific logic
    function convertToAssets(uint256 vaultId, uint256 shares)
        public
        view
        virtual
        returns (uint256)
    {
        uint256 supply = vaults[vaultId].totalSupply;

        return supply == 0 ? shares : (shares * totalAssets(vaultId)) / supply;
    }

    function previewDeposit(uint256 vaultId, uint256 assets)
        public
        view
        returns (uint256)
    {
        return convertToShares(vaultId, assets);
    }

    /// @notice can be overriden depending on the specific logic
    function previewMint(uint256 vaultId, uint256 shares)
        public
        view
        virtual
        returns (uint256)
    {
        uint256 supply = vaults[vaultId].totalSupply;

        return supply == 0 ? shares : (shares * totalAssets(vaultId)) / supply;
    }

    /// @notice can be overriden depending on the specific logic
    function previewWithdraw(uint256 vaultId, uint256 assets)
        public
        view
        virtual
        returns (uint256)
    {
        uint256 supply = vaults[vaultId].totalSupply;

        return supply == 0 ? assets : (assets * supply) / totalAssets(vaultId);
    }

    function previewRedeem(uint256 vaultId, uint256 shares)
        public
        view
        returns (uint256)
    {
        return convertToAssets(vaultId, shares);
    }

    /*///////////////////////////////////////////////////////////////
                     DEPOSIT/WITHDRAWAL LIMIT LOGIC
    //////////////////////////////////////////////////////////////*/

    function maxDeposit(address) public pure returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address) public pure returns (uint256) {
        return type(uint256).max;
    }

    function maxWithdraw(uint256 vaultId, address owner)
        public
        view
        returns (uint256)
    {
        return convertToAssets(vaultId, balanceOf(owner, vaultId));
    }

    function maxRedeem(uint256 vaultId, address owner)
        public
        view
        returns (uint256)
    {
        return balanceOf(owner, vaultId);
    }

    /*///////////////////////////////////////////////////////////////
                         INTERNAL HOOKS LOGIC
    //////////////////////////////////////////////////////////////*/

    function beforeWithdraw(
        uint256 vaultId,
        uint256 assets,
        uint256 shares
    ) internal virtual {}

    function afterDeposit(
        uint256 vaultId,
        uint256 assets,
        uint256 shares
    ) internal virtual {}
}
