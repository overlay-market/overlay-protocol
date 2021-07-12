// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract OverlayToken is AccessControl, ERC20("Overlay", "OVL") {

  bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");
  bytes32 public constant MINTER_ROLE = keccak256("MINTER");
  bytes32 public constant BURNER_ROLE = keccak256("BURNER");

  // debt owed by address (non-transferrable)
  mapping(address => uint256) private _debts;
  uint256 private _totalDebt;

  constructor() {
    _setupRole(ADMIN_ROLE, msg.sender);
    _setupRole(MINTER_ROLE, msg.sender);
    _setRoleAdmin(MINTER_ROLE, ADMIN_ROLE);
    _setRoleAdmin(BURNER_ROLE, ADMIN_ROLE);
    _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
  }

  modifier onlyMinter() {
    require(hasRole(MINTER_ROLE, msg.sender), "only minter");
    _;
  }

  modifier onlyBurner() {
    require(hasRole(BURNER_ROLE, msg.sender), "only burner");
    _;
  }

  /// @notice Mints tokens to total supply
  function mint(address _recipient, uint256 _amount) external onlyMinter {
      _mint(_recipient, _amount);
  }

  /// @notice Burns tokens from total supply
  function burn(address _account, uint256 _amount) external onlyBurner {
      _burn(_account, _amount);
  }

  /// @notice Mints tokens to total supply, a portion of which is debt
  function mintWithDebt(address _recipient, uint256 _amount, uint256 _debt) external onlyMinter {
      require(_debt <= _amount, "debt > amount");
      _debts[_recipient] += _debt;
      _mint(_recipient, _amount);
  }

  /// @notice Burns tokens from total supply, a portion of which is debt
  function burnWithDebt(address _account, uint256 _amount, uint256 _debt) external onlyBurner {
      require(_debt <= _amount, "debt > amount");

      uint256 debtBalance = _debts[_account];
      require(debtBalance >= _debt, "debt burn amount exceeds outstanding debt");
      _debts[_account] = debtBalance - _debt;
      _burn(_account, _amount);
  }

  /// @notice Total debt outstanding
  function totalDebt() public view returns (uint256) {
      return _totalDebt;
  }

  /// @notice Debt associated with account
  function debtOf(address _account) public view returns (uint256) {
      return _debts[_account];
  }
}
