// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title TaxaToken
/// @notice Non-transferable ERC-20 governance token for the Smart Tax Allocation platform.
///
///   TAXA represents voting power derived from off-chain tax payments.
///   It is **not** a currency — tokens cannot be transferred between users.
///   The only allowed operations are:
///
///     Mint  — Owner (admin) mints tokens to a taxpayer after verifying
///             their off-chain tax payment.
///     Burn  — The allocation contract burns tokens when a user casts
///             votes in a governance round.
///     Re-mint — The allocation contract re-mints tokens when a user
///               reclaims from a cancelled round.
///
///   All peer-to-peer transfers are permanently blocked.
contract TaxaToken is ERC20, Ownable {

    /// @notice The SmartTaxAllocation contract authorized to burn and re-mint.
    address public allocationContract;

    event AllocationContractSet(address indexed contractAddress);

    /// @param _owner The admin address that can mint tokens and configure the contract.
    constructor(address _owner) ERC20("TAXA", "TAXA") Ownable(_owner) {}

    // ─── Configuration ───────────────────────────

    /// @notice Set the SmartTaxAllocation contract address. Only callable by owner.
    ///         This contract gets burn and re-mint authority.
    /// @param _contract Address of the deployed SmartTaxAllocation contract.
    function setAllocationContract(address _contract) external onlyOwner {
        require(_contract != address(0), "Invalid address");
        allocationContract = _contract;
        emit AllocationContractSet(_contract);
    }

    // ─── Mint (admin only) ───────────────────────

    /// @notice Mint TAXA tokens to a taxpayer after off-chain tax verification.
    ///         Only callable by the owner (admin).
    /// @param _to     Recipient (taxpayer) address.
    /// @param _amount Amount of tokens to mint (in wei, 18 decimals).
    function mint(address _to, uint256 _amount) external onlyOwner {
        require(_to != address(0), "Invalid recipient");
        require(_amount > 0, "Amount must be > 0");
        _mint(_to, _amount);
    }

    // ─── Burn (allocation contract only) ─────────

    /// @notice Burn TAXA tokens from a voter. Only callable by the allocation contract.
    ///         Used when a user allocates votes in a governance round.
    /// @param _from   Address whose tokens will be burned.
    /// @param _amount Amount of tokens to burn.
    function burn(address _from, uint256 _amount) external {
        require(msg.sender == allocationContract, "Not authorized");
        _burn(_from, _amount);
    }

    /// @notice Re-mint TAXA tokens to a user. Only callable by the allocation contract.
    ///         Used when a user reclaims tokens from a cancelled round.
    /// @param _to     Address to receive the re-minted tokens.
    /// @param _amount Amount of tokens to re-mint.
    function mintFromAllocation(address _to, uint256 _amount) external {
        require(msg.sender == allocationContract, "Not authorized");
        _mint(_to, _amount);
    }

    // ─── Transfer restriction ────────────────────

    /// @dev Block all transfers. Only minting (from == 0) and burning (to == 0) are allowed.
    function _update(address from, address to, uint256 value) internal override {
        bool isMint = (from == address(0));
        bool isBurn = (to == address(0));
        require(isMint || isBurn, "Transfers disabled");
        super._update(from, to, value);
    }
}
