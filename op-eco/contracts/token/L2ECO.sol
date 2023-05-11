// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20Upgradeable} from "./ERC20Upgradeable.sol";
import {DelegatePermitUpgradeable} from "../cryptography/DelegatePermitUpgradeable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IL2StandardERC20} from "@eth-optimism/contracts/standards/IL2StandardERC20.sol";

contract L2ECO is ERC20Upgradeable, DelegatePermitUpgradeable, IERC165 {
    uint256 public constant INITIAL_INFLATION_MULTIPLIER = 1e18;

    uint256 public linearInflationMultiplier;

    address public tokenRoleAdmin;

    // address of the L1 token contract
    address public l1Token;

    // roles to be managed by tokenRoleAdmin
    mapping(address => bool) public minters;
    mapping(address => bool) public burners;
    mapping(address => bool) public rebasers;

    // to be used to record the transfer amounts after _beforeTokenTransfer
    // these values are the base (unchanging) values the currency is stored in
    event BaseValueTransfer(
        address indexed from,
        address indexed to,
        uint256 value
    );

    // event for minted tokens
    // required for IL2StandardERC20 compliance
    event Mint(address indexed _account, uint256 _amount);

    // event for burned tokens
    // required for IL2StandardERC20 compliance
    event Burn(address indexed _account, uint256 _amount);

    /** Fired when notified by L1 of a new inflation multiplier.
     * Used to calculate values for the rebased token.
     */
    event NewInflationMultiplier(uint256 inflationMultiplier);

    modifier uninitialized() {
        require(
            linearInflationMultiplier == 0,
            "L2ECO: contract has already been initialized"
        );
        _;
    }

    modifier onlyMinterRole() {
        require(minters[msg.sender], "L2ECO: not authorized to mint");
        _;
    }

    modifier onlyBurnerRoleOrSelf(address _from) {
        require(
            _from == msg.sender || burners[msg.sender],
            "L2ECO: not authorized to burn"
        );
        _;
    }

    modifier onlyRebaserRole() {
        require(rebasers[msg.sender], "L2ECO: not authorized to rebase");
        _;
    }

    modifier onlyTokenRoleAdmin() {
        require(
            msg.sender == tokenRoleAdmin,
            "L2ECO: not authorized to edit roles"
        );
        _;
    }

    /**
     * Disable the implementation contract
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _l1Token,
        address _l2Bridge
    ) public initializer uninitialized {
        ERC20Upgradeable.__ERC20_init(
            "ECO",
            "ECO"
        );
        linearInflationMultiplier = INITIAL_INFLATION_MULTIPLIER;
        minters[_l2Bridge] = true;
        burners[_l2Bridge] = true;
        rebasers[_l2Bridge] = true;
        l1Token = _l1Token;
        tokenRoleAdmin = _l2Bridge;
    }

    /** Access function to determine the token balance held by some address.
     */
    function balanceOf(address _owner) public view override returns (uint256) {
        return super.balanceOf(_owner) / linearInflationMultiplier;
    }

    /** Returns the total (inflation corrected) token supply
     */
    function totalSupply() public view override returns (uint256) {
        return super.totalSupply() / linearInflationMultiplier;
    }

    function updateMinters(address _key, bool _value)
        public
        onlyTokenRoleAdmin
    {
        minters[_key] = _value;
    }

    function updateBurners(address _key, bool _value)
        public
        onlyTokenRoleAdmin
    {
        burners[_key] = _value;
    }

    function updateRebasers(address _key, bool _value)
        public
        onlyTokenRoleAdmin
    {
        rebasers[_key] = _value;
    }

    function updateTokenRoleAdmin(address _newAdmin) public onlyTokenRoleAdmin {
        tokenRoleAdmin = _newAdmin;
    }

    function mint(address _to, uint256 _amount) external onlyMinterRole {
        _mint(_to, _amount);
        emit Mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount)
        external
        onlyBurnerRoleOrSelf(_from)
    {
        _burn(_from, _amount);
        emit Burn(_from, _amount);
    }

    function rebase(uint256 _newLinearInflationMultiplier)
        external
        onlyRebaserRole
    {
        _rebase(_newLinearInflationMultiplier);
        emit NewInflationMultiplier(_newLinearInflationMultiplier);
    }

    function supportsInterface(bytes4 _interfaceId)
        external
        pure
        returns (bool)
    {
        bytes4 firstSupportedInterface = type(IERC165).interfaceId; // ERC165
        bytes4 secondSupportedInterface = type(IL2StandardERC20).interfaceId; // compliant to OP's IL2StandardERC20
        return
            _interfaceId == firstSupportedInterface ||
            _interfaceId == secondSupportedInterface;
    }

    function _rebase(uint256 _newLinearInflationMultiplier) internal {
        linearInflationMultiplier = _newLinearInflationMultiplier;
    }

    // this function converts to gons for the sake of transferring
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override returns(uint256) {
        amount = super._beforeTokenTransfer(from, to, amount);
        amount = amount * linearInflationMultiplier;

        emit BaseValueTransfer(from, to, amount);
        return amount;
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {}
}
