// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/* Interface Imports */
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IL2StandardERC20} from "@eth-optimism/contracts/standards/IL2StandardERC20.sol";

/* Contract Imports */
import {ERC20Upgradeable} from "./ERC20Upgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";

/**
 * @title L2ECO
 * @dev The L2 ECO token is all tokens that have been bridge via the L1ECOBridge and L2ECOBridge
 * It differens in a few key ways from the L1 ECO token:
 * Balances are not checkpointed.
 * There is no voting on the L2 and therefore significant gas is saved by not saving balances.
 * Obviously with no voting, there is no delegation.
 * Permissions are handled differently.
 * Instead of updated via governance, there are granular roles gating minting, burning, and rebasing
 * These roles are stored on the contract instead of managed through ERC1820
 * Because of this there is no root policy address.
 * No generational timing.
 * The token contract trusts the sources of admin actions and doesn't keep any internal timing.
 */
contract L2ECO is ERC20Upgradeable, EIP712Upgradeable, IERC165 {
    /**
     * @dev Constant for setting the initial inflation multiplier
     */
    uint256 public constant INITIAL_INFLATION_MULTIPLIER = 1e18;

    /**
     * @dev Stores the current inflation multiplier
     */
    uint256 public linearInflationMultiplier;

    /**
     * @dev Address which has the ability to change permission roles
     */
    address public tokenRoleAdmin;

    /**
     * @dev Address of the L1 token contract
     */
    address public l1Token;

    /**
     * @dev Mapping storing contracts able to mint tokens
     */
    mapping(address => bool) public minters;
    /**
     * @dev Mapping storing contracts able to burn tokens
     */
    mapping(address => bool) public burners;
    /**
     * @dev Mapping storing contracts able to rebase the token
     */
    mapping(address => bool) public rebasers;

    /**
     * @dev Event for recording the transfer amounts after _beforeTokenTransfer applies the inflation multiplier
     * @param from Address sending tokens
     * @param to Address receive tokens
     * @param value This is in the base (unchanging) amounts the currency is stored in (gons)
     */
    event BaseValueTransfer(
        address indexed from,
        address indexed to,
        uint256 value
    );

    /**
     * @dev Event for minted tokens
     * @param _account Address receive tokens
     * @param _amount Amount of tokens being created
     */
    event Mint(address indexed _account, uint256 _amount);

    /**
     * @dev Event for burned tokens
     * @param _account Address losing tokens
     * @param _amount Amount of tokens being destroyed
     */
    event Burn(address indexed _account, uint256 _amount);

    /** 
     * @dev Emitted when notified by L1 of a new inflation multiplier.
     * does not necessarily mean the multiplier changes (can be same as before)
     * @param inflationMultiplier new inflation multiplier used to calculate values for the rebased token.
     */
    event NewInflationMultiplier(uint256 inflationMultiplier);

    /**
     * @dev Modifier for checking if the sender is a minter
     */
    modifier onlyMinterRole() {
        require(minters[msg.sender], "L2ECO: not authorized to mint");
        _;
    }

    /**
     * @dev Modifier for checking if the sender is allowed to burn
     * both burners and the message sender can burn
     * @param _from the address burning tokens
     */
    modifier onlyBurnerRoleOrSelf(address _from) {
        require(
            _from == msg.sender || burners[msg.sender],
            "L2ECO: not authorized to burn"
        );
        _;
    }

    /**
     * @dev Modifier for checking if the sender is a rebaser
     */
    modifier onlyRebaserRole() {
        require(rebasers[msg.sender], "L2ECO: not authorized to rebase");
        _;
    }

    /**
     * @dev Modifier for checking if the sender is able to edit roles
     */
    modifier onlyTokenRoleAdmin() {
        require(
            msg.sender == tokenRoleAdmin,
            "L2ECO: not authorized to edit roles"
        );
        _;
    }

    /**
     * Disable the implementation contract
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializer that sets token information as well as the inital role values and the L1 Token address
     * @param _l1Token sets the L1 token address that is able to process withdrawals (available for convenience and interface compliance)
     * @param _l2Bridge sets the bridge to give all permissions to
     */
    function initialize(
        address _l1Token,
        address _l2Bridge
    ) public initializer {
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

    /** 
     * @dev Access function to determine the token balance held by some address.
     */
    function balanceOf(address _owner) public view override returns (uint256) {
        return super.balanceOf(_owner) / linearInflationMultiplier;
    }

    /**
     * @dev Returns the total (inflation corrected) token supply
     */
    function totalSupply() public view override returns (uint256) {
        return super.totalSupply() / linearInflationMultiplier;
    }

    /**
     * @dev change the minting permissions for an address
     * only callable by tokenRoleAdmin
     * @param _key the address to change permissions for
     * @param _value the new permission. true = can mint, false = cannot mint
     */
    function updateMinters(address _key, bool _value)
        public
        onlyTokenRoleAdmin
    {
        minters[_key] = _value;
    }

    /**
     * @dev change the burning permissions for an address
     * only callable by tokenRoleAdmin
     * @param _key the address to change permissions for
     * @param _value the new permission. true = can burn, false = cannot burn
     */
    function updateBurners(address _key, bool _value)
        public
        onlyTokenRoleAdmin
    {
        burners[_key] = _value;
    }

    /**
     * @dev change the rebasing permissions for an address
     * only callable by tokenRoleAdmin
     * @param _key the address to change permissions for
     * @param _value the new permission. true = can rebase, false = cannot rebase
     */
    function updateRebasers(address _key, bool _value)
        public
        onlyTokenRoleAdmin
    {
        rebasers[_key] = _value;
    }

    /**
     * @dev give the role admin privilege to another address
     * only callable by tokenRoleAdmin
     * @param _newAdmin the address to be the new admin
     */
    function updateTokenRoleAdmin(address _newAdmin) public onlyTokenRoleAdmin {
        tokenRoleAdmin = _newAdmin;
    }

    /**
     * @dev Mint tokens for an address. Only callable by minter role addresses
     * @param _to the address to receive tokens
     * @param _amount the amount of tokens to be created
     */
    function mint(address _to, uint256 _amount) external onlyMinterRole {
        _mint(_to, _amount);
        emit Mint(_to, _amount);
    }

    /**
     * @dev Burn tokens for an address. Only callable by burner role addresses
     * @param _from the address to lose tokens
     * @param _amount the amount of tokens to be destroyed
     */
    function burn(address _from, uint256 _amount)
        external
        onlyBurnerRoleOrSelf(_from)
    {
        _burn(_from, _amount);
        emit Burn(_from, _amount);
    }

    /**
     * @dev Rebase tokens for all addresses. Done by changing the inflation multiplier. Only callable by rebaser role addresses
     * @param _newLinearInflationMultiplier the new inflation multiplier to replace the current one
     */
    function rebase(uint256 _newLinearInflationMultiplier)
        external
        onlyRebaserRole
    {
        _rebase(_newLinearInflationMultiplier);
        emit NewInflationMultiplier(_newLinearInflationMultiplier);
    }

    /**
     * @dev function to utilize ERC165 to signal compliance to an Optimism network system
     * IERC165 and IL2StandardERC20 are the supported interfaces
     * @param _interfaceId the ID hash of the interface
     */
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

    /**
     * @dev helper function for rebases. overwrites the old inflation multiplier with the new one
     * @param _newLinearInflationMultiplier the new inflation multiplier to replace the current one
     */
    function _rebase(uint256 _newLinearInflationMultiplier) internal {
        linearInflationMultiplier = _newLinearInflationMultiplier;
    }

    /**
     * @dev overrides the ERC20 hook to account for the rebasing factor in all transactions
     * emits an event showing the base value (ERC20 emits the inputted value)
     * @param from address sending the tokens
     * @param to address receive the tokens
     * @param amount the amount of tokens to be transferred
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override returns(uint256) {
        amount = super._beforeTokenTransfer(from, to, amount);
        // overwrite for efficiency
        amount = amount * linearInflationMultiplier;

        emit BaseValueTransfer(from, to, amount);
        return amount;
    }
}
