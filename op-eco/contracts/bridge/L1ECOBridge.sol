// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/* Interface Imports */
import {IL1ECOBridge} from "../interfaces/bridge/IL1ECOBridge.sol";
import {IL1ERC20Bridge} from "@eth-optimism/contracts/L1/messaging/IL1ERC20Bridge.sol";
import {IL2ECOBridge} from "../interfaces/bridge/IL2ECOBridge.sol";
import {IL2ERC20Bridge} from "@eth-optimism/contracts/L2/messaging/IL2ERC20Bridge.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IECO} from "@helix-foundation/currency/contracts/currency/IECO.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/* Contract Imports */
import {CrossDomainEnabledUpgradeable} from "./CrossDomainEnabledUpgradeable.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

/**
 * @title L1ECOBridge
 * @dev The L1 ECO Bridge is a contract which stores deposited L1 ECO
 * that is in use on L2. It synchronizes a corresponding L2 Bridge, informing it of deposits
 * and listening to it for newly finalized withdrawals.
 * It also acts as the authorized source of L1 governance decisions as seen by the L2.
 * All governance related data and decisions are passed through this contract so that the
 * L2 contracts can maintain and trust a single source of L1 messages.
 */
contract L1ECOBridge is IL1ECOBridge, CrossDomainEnabledUpgradeable {
    /**
     * @dev L2 side of the bridge
     */
    address public l2TokenBridge;

    /**
     * @dev L1 ECO address
     */
    address public l1Eco;

    /**
     * @dev L2 ECO address
     */
    address public l2Eco;

    /**
     * @dev L1 proxy admin that manages this proxy contract
     */
    ProxyAdmin public l1ProxyAdmin;

    /**
     * @dev L2 upgrader role
     */
    address public upgrader;

    /**
     * @dev Current inflation multiplier
     */
    uint256 public inflationMultiplier;

    /**
     * @dev Modifier requiring sender to be EOA.  This check could be bypassed by a malicious
     * contract via initcode, but it takes care of the user error we want to avoid.
     */
    modifier onlyEOA() {
        // Used to stop deposits from contracts (avoid accidentally lost tokens)
        require(msg.sender.code.length == 0, "L1ECOBridge: Account not EOA");
        _;
    }

    /**
     * @dev Modifier to check that the L1 token is the same as the one set in the constructor
     * @param _l1Token L1 token address to check
     */
    modifier isL1EcoToken(address _l1Token) {
        require(
            _l1Token == l1Eco,
            "L1ECOBridge: invalid L2 token address"
        );
        _;
    }

    /**
     * @dev Modifier to check that the L2 token is the same as the one set in the constructor
     * @param _l2Token L2 token address to check
     */
    modifier isL2EcoToken(address _l2Token) {
        require(
            _l2Token == l2Eco,
            "L1ECOBridge: invalid L2 token address"
        );
        _;
    }

    /**
     * @dev Modifier for gating upgrade functionality behind an authorized ECO protocol governace contract
     */
    modifier onlyUpgrader() {
        require(
            msg.sender == upgrader,
            "L1ECOBridge: caller not authorized to upgrade L2 contracts."
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
     * @inheritdoc IL1ECOBridge
     */
    function initialize(
        address _l1messenger,
        address _l2TokenBridge,
        address _l1Eco,
        address _l2Eco,
        address _l1ProxyAdmin,
        address _upgrader
    ) public initializer {
        CrossDomainEnabledUpgradeable.__CrossDomainEnabledUpgradeable_init(
            _l1messenger
        );
        l2TokenBridge = _l2TokenBridge;
        l1Eco = _l1Eco;
        l2Eco = _l2Eco;
        l1ProxyAdmin = ProxyAdmin(_l1ProxyAdmin);
        upgrader = _upgrader;
        inflationMultiplier = IECO(_l1Eco).getPastLinearInflation(
            block.number
        );
    }

    /**
     * @inheritdoc IL1ECOBridge
     * @custom:oz-upgrades-unsafe-allow-reachable delegatecall
     */
    function upgradeECO(address _impl, uint32 _l2Gas)
        external
        virtual
        onlyUpgrader
    {
        bytes memory message = abi.encodeWithSelector(
            IL2ECOBridge.upgradeECO.selector,
            _impl
        );

        sendCrossDomainMessage(l2TokenBridge, _l2Gas, message);
        emit UpgradeL2ECO(_impl);
    }

    /**
     * @inheritdoc IL1ECOBridge
     * @custom:oz-upgrades-unsafe-allow-reachable delegatecall
     */
    function upgradeL2Bridge(address _impl, uint32 _l2Gas)
        external
        virtual
        onlyUpgrader
    {
        bytes memory message = abi.encodeWithSelector(
            IL2ECOBridge.upgradeSelf.selector,
            _impl
        );

        sendCrossDomainMessage(l2TokenBridge, _l2Gas, message);
        emit UpgradeL2Bridge(_impl);
    }

     /**
     * @inheritdoc IL1ECOBridge
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
     * @inheritdoc IL1ERC20Bridge
     * @param _l1Token must be the ECO L1 token address.
     */
    function depositERC20(
        address _l1Token,
        address _l2Token,
        uint256 _amount,
        uint32 _l2Gas,
        bytes calldata _data
    ) external virtual onlyEOA isL1EcoToken(_l1Token) isL2EcoToken(_l2Token) {
        _initiateERC20Deposit(
            _l1Token,
            _l2Token,
            msg.sender,
            msg.sender,
            _amount,
            _l2Gas,
            _data
        );
    }

    /**
     * @inheritdoc IL1ERC20Bridge
     * @param _l1Token must be the ECO L1 token address.
     */
    function depositERC20To(
        address _l1Token,
        address _l2Token,
        address _to,
        uint256 _amount,
        uint32 _l2Gas,
        bytes calldata _data
    ) external virtual isL1EcoToken(_l1Token) isL2EcoToken(_l2Token) {
        _initiateERC20Deposit(
            _l1Token,
            _l2Token,
            msg.sender,
            _to,
            _amount,
            _l2Gas,
            _data
        );
    }

    /**
     * @inheritdoc IL1ERC20Bridge
     * @param _l1Token is always the ECO L1 token address.
     * @param _l2Token is always the ECO L2 token address.
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

        // equivalent to IECO(_l1Token).transfer(_to, _amount); but is revert safe
        bytes memory _ecoTransferMessage = abi.encodeWithSelector(
            IERC20.transfer.selector,
            _to,
            _amount
        );
        (bool success, bytes memory returnData) = _l1Token.call{value: 0}(
            _ecoTransferMessage
        );

        // make sure that the call to transfer didn't revert or return false
        if (success && abi.decode(returnData, (bool))) {
            // if successful, emit an event
            emit ERC20WithdrawalFinalized(
                _l1Token,
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

    /**
     * @inheritdoc IL1ECOBridge
     */
    function rebase(uint32 _l2Gas) external {
        inflationMultiplier = IECO(l1Eco).getPastLinearInflation(
            block.number
        );

        bytes memory message = abi.encodeWithSelector(
            IL2ECOBridge.rebase.selector,
            inflationMultiplier
        );

        sendCrossDomainMessage(l2TokenBridge, _l2Gas, message);
    }

    /**
     * @dev Performs the logic for deposits by informing the L2 ECO token
     * contract of the deposit and pulling in the L1 funds from the depositor
     *
     * @param _l1Token Address of the L1 ECO token contract
     * @param _l2Token Address of the L2 ECO token contract
     * @param _from Account to pull the deposit from on L1
     * @param _to Account to give the deposit to on L2
     * @param _amount Amount of ECO being deposited.
     * @param _l2Gas Gas limit required to complete the deposit on L2.
     * @param _data Optional data to forward to L2.
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
            //call parent interface IL2ERC20Bridge to get the selector
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
