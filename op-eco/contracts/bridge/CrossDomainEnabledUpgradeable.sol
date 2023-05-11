// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
// Heavily inspired by:
// @eth-optimism Contracts (last updated v0.5.40) (contracts/libraries/bridge/CrossDomainEnabled.sol)

/* Interface Imports */
import {ICrossDomainMessenger} from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title CrossDomainEnabledUpgradeable
 * @dev Helper contract for contracts performing cross-domain communications
 *
 * Compiler used: defined by inheriting contract
 */
contract CrossDomainEnabledUpgradeable is Initializable {
    // Messenger contract used to send and recieve messages from the other domain.
    address public messenger;

    /**
     * Enforces that the modified function is only callable by a specific cross-domain account.
     * @param _sourceDomainAccount The only account on the originating domain which is
     *  authenticated to call this function.
     */
    modifier onlyFromCrossDomainAccount(address _sourceDomainAccount) {
        require(
            msg.sender == address(getCrossDomainMessenger()),
            "OVM_XCHAIN: messenger contract unauthenticated"
        );

        require(
            getCrossDomainMessenger().xDomainMessageSender() ==
                _sourceDomainAccount,
            "OVM_XCHAIN: wrong sender of cross-domain message"
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
     * @param _messenger Address of the CrossDomainMessenger on the current layer.
     */
    function __CrossDomainEnabledUpgradeable_init(address _messenger)
        public
        onlyInitializing
    {
        messenger = _messenger;
    }

    /**
     * Gets the messenger, usually from storage. This function is exposed in case a child contract
     * needs to override.
     * @return The address of the cross-domain messenger contract which should be used.
     */
    function getCrossDomainMessenger()
        internal
        virtual
        returns (ICrossDomainMessenger)
    {
        return ICrossDomainMessenger(messenger);
    }

    /**
     * Sends a message to an account on another domain
     * @param _crossDomainTarget The intended recipient on the destination domain
     * @param _message The data to send to the target (usually calldata to a function with
     *  `onlyFromCrossDomainAccount()`)
     * @param _gasLimit The gasLimit for the receipt of the message on the target domain.
     */
    function sendCrossDomainMessage(
        address _crossDomainTarget,
        uint32 _gasLimit,
        bytes memory _message
    ) internal {
        // slither-disable-next-line reentrancy-events, reentrancy-benign
        getCrossDomainMessenger().sendMessage(
            _crossDomainTarget,
            _message,
            _gasLimit
        );
    }
}
