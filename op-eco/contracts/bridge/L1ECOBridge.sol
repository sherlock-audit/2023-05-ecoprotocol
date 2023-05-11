// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/* Interface Imports */
import {IL1ECOBridge} from "../interfaces/bridge/IL1ECOBridge.sol";
import {IL2ECOBridge} from "../interfaces/bridge/IL2ECOBridge.sol";
import {IL2ERC20Bridge} from "@eth-optimism/contracts/L2/messaging/IL2ERC20Bridge.sol";
import {L2ECOBridge} from "../bridge/L2ECOBridge.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/* Library Imports */
import {CrossDomainEnabled} from "@eth-optimism/contracts/libraries/bridge/CrossDomainEnabled.sol";
import {Lib_PredeployAddresses} from "@eth-optimism/contracts/libraries/constants/Lib_PredeployAddresses.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IECO} from "@helix-foundation/currency/contracts/currency/IECO.sol";
import {CrossDomainEnabledUpgradeable} from "./CrossDomainEnabledUpgradeable.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

/**
 * @title L1ECOBridge
 * @dev The L1 ETH and ERC20 Bridge is a contract which stores deposited L1 funds and standard
 * tokens that are in use on L2. It synchronizes a corresponding L2 Bridge, informing it of deposits
 * and listening to it for newly finalized withdrawals.
 *
 */
contract L1ECOBridge is IL1ECOBridge, CrossDomainEnabledUpgradeable {
    // L2 side of the bridge
    address public l2TokenBridge;

    // L1 ECO address
    address public ecoAddress;

    /**
     * @dev L1 proxy admin that manages this proxy contract
     */
    ProxyAdmin public l1ProxyAdmin;

    // L2 upgrader role
    address public upgrader;

    // Current inflation multiplier
    uint256 public inflationMultiplier;

    /**
     * @dev Modifier requiring sender to be EOA.  This check could be bypassed by a malicious
     * contract via initcode, but it takes care of the user error we want to avoid.
     */
    modifier onlyEOA() {
        // Used to stop deposits from contracts (avoid accidentally lost tokens)
        require(!Address.isContract(msg.sender), "Account not EOA");
        _;
    }

    modifier onlyUpgrader() {
        require(
            msg.sender == upgrader,
            "L1ECOBridge: caller not authorized to upgrade L2 contracts."
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

    /**
     * @param _l1messenger L1 Messenger address being used for cross-chain communications.
     * @param _l2TokenBridge L2 standard bridge address.
     * @param _ecoAddress address of L1 ECO contract.
     * @param _l1ProxyAdmin address of ProxyAdmin contract for the L1 Bridge.
     * @param _upgrader address that can perform upgrades.
     */
    function initialize(
        address _l1messenger,
        address _l2TokenBridge,
        address _ecoAddress,
        address _l1ProxyAdmin,
        address _upgrader
    ) public initializer {
        CrossDomainEnabledUpgradeable.__CrossDomainEnabledUpgradeable_init(
            _l1messenger
        );
        l2TokenBridge = _l2TokenBridge;
        ecoAddress = _ecoAddress;
        l1ProxyAdmin = ProxyAdmin(_l1ProxyAdmin);
        upgrader = _upgrader;
        inflationMultiplier = IECO(_ecoAddress).getPastLinearInflation(
            block.number
        );
    }

    /**
     * @dev Upgrades the L2ECO token implementation address, by sending
     *      a cross domain message to the L2 Bridge via the L1 Messenger
     * @param _impl L2 contract address.
     * @param _l2Gas Gas limit for the L2 message.
     * @custom:oz-upgrades-unsafe-allow-reachable delegatecall
     */
    function upgradeECO(address _impl, uint32 _l2Gas)
        external
        virtual
        onlyUpgrader
    {
        bytes memory message = abi.encodeWithSelector(
            L2ECOBridge.upgradeECO.selector,
            _impl
        );

        sendCrossDomainMessage(l2TokenBridge, _l2Gas, message);
        emit UpgradeL2ECO(_impl);
    }

    /**
     * @dev Upgrades this contract implementation by passing the new implementation address to the ProxyAdmin.
     * @param _newBridgeImpl The new L1ECOBridge implementation address.
     * @custom:oz-upgrades-unsafe-allow-reachable delegatecall
     */
    function upgradeSelf(address _newBridgeImpl) external virtual onlyUpgrader {
        //cast to a payable address since l2EcoToken is the proxy address of a ITransparentUpgradeableProxy contract
        address payable proxyAddr = payable(address(this));

        ITransparentUpgradeableProxy proxy = ITransparentUpgradeableProxy(
            proxyAddr
        );
        l1ProxyAdmin.upgrade(proxy, _newBridgeImpl);

        emit UpgradeSelf(_newBridgeImpl);
    }

    /**
     */
    function depositERC20(
        address,//_l1Token
        address _l2Token,
        uint256 _amount,
        uint32 _l2Gas,
        bytes calldata _data
    ) external virtual onlyEOA {
        _initiateERC20Deposit(
            ecoAddress,
            _l2Token,
            msg.sender,
            msg.sender,
            _amount,
            _l2Gas,
            _data
        );
    }

    /**
     */
    function depositERC20To(
        address,//_l1Token
        address _l2Token,
        address _to,
        uint256 _amount,
        uint32 _l2Gas,
        bytes calldata _data
    ) external virtual {
        _initiateERC20Deposit(
            ecoAddress,
            _l2Token,
            msg.sender,
            _to,
            _amount,
            _l2Gas,
            _data
        );
    }

    /**
     * When a withdrawal is finalized on L1, the L1 Bridge transfers the funds to the withdrawer
     */
    function finalizeERC20Withdrawal(
        address _l1Token,
        address _l2Token,
        address _from,
        address _to,
        uint256 _gonsAmount,
        bytes calldata _data
    ) external onlyFromCrossDomainAccount(l2TokenBridge) {
        uint256 _amount = _gonsAmount / inflationMultiplier;

        // equivalent to IECO(ecoAddress).transfer(_to, _amount); but is revert safe
        bytes memory _ecoTransferMessage = abi.encodeWithSelector(
            IERC20.transfer.selector,
            _to,
            _amount
        );
        (bool success, bytes memory returnData) = ecoAddress.call{value: 0}(
            _ecoTransferMessage
        );

        // make sure that the call to transfer didn't revert or return false
        if (success && abi.decode(returnData, (bool))) {
            // if successful, emit an event
            emit ERC20WithdrawalFinalized(
                ecoAddress,
                _l2Token,
                _from,
                _to,
                _amount,
                _data
            );
        } else {
            // if the transfer fails, create a return tx
            bytes memory message = abi.encodeWithSelector(
                IL2ERC20Bridge.finalizeDeposit.selector,
                _l1Token,
                _l2Token,
                _to, // switched the _to and _from here to bounce back the deposit to the sender
                _from,
                _gonsAmount,
                _data
            );

            // Send message up to L1 bridge
            sendCrossDomainMessage(l2TokenBridge, 0, message);
            // Emit an event to signal success event listeners to expect failure
            emit WithdrawalFailed(
                _l1Token,
                _l2Token,
                _from,
                _to,
                _amount,
                _data
            );
        }
    }

    function rebase(uint32 _l2Gas) external {
        inflationMultiplier = IECO(ecoAddress).getPastLinearInflation(
            block.number
        );

        bytes memory message = abi.encodeWithSelector(
            L2ECOBridge.rebase.selector,
            inflationMultiplier
        );

        sendCrossDomainMessage(l2TokenBridge, _l2Gas, message);
    }

    /**
     * @dev Adds ETH balance to the account. This is meant to allow for ETH
     * to be migrated from an old gateway to a new gateway.
     * NOTE: This is left for one upgrade only so we are able to receive the migrated ETH from the
     * old contract
     */
    function donateETH() external payable {}

    /**
     * @dev Performs the logic for deposits by informing the L2 Deposited Token
     * contract of the deposit and calling a handler to lock the L1 funds. (e.g. transferFrom)
     *
     * @param _l1Token Address of the L1 ERC20 we are depositing
     * @param _l2Token Address of the L1 respective L2 ERC20
     * @param _from Account to pull the deposit from on L1
     * @param _to Account to give the deposit to on L2
     * @param _amount Amount of the ERC20 to deposit.
     * @param _l2Gas Gas limit required to complete the deposit on L2.
     * @param _data Optional data to forward to L2. This data is provided
     *        solely as a convenience for external contracts. Aside from enforcing a maximum
     *        length, these contracts provide no guarantees about its content.
     */
    function _initiateERC20Deposit(
        address _l1Token,
        address _l2Token,
        address _from,
        address _to,
        uint256 _amount,
        uint32 _l2Gas,
        bytes calldata _data
    ) internal {
        // When a deposit is initiated on L1, the L1 Bridge transfers the funds to itself for future
        // withdrawals.

        IECO(_l1Token).transferFrom(_from, address(this), _amount);
        // gons move across the bridge, with inflation multipliers on either side to correctly scale balances
        _amount = _amount * inflationMultiplier;

        // Construct calldata for _l2Token.finalizeDeposit(_to, _amount)
        bytes memory message = abi.encodeWithSelector(
            //call parent interface of IL2ERC20Bridge to get the selector
            IL2ERC20Bridge.finalizeDeposit.selector,
            _l1Token,
            _l2Token,
            _from,
            _to,
            _amount,
            _data
        );

        // Send calldata into L2
        sendCrossDomainMessage(l2TokenBridge, _l2Gas, message);

        emit ERC20DepositInitiated(
            _l1Token,
            _l2Token,
            _from,
            _to,
            _amount,
            _data
        );
    }
}
