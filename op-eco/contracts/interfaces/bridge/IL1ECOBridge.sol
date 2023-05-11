// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IL1ERC20Bridge} from "@eth-optimism/contracts/L1/messaging/IL1ERC20Bridge.sol";

/**
 * @title IL1ECOBridge
 */
interface IL1ECOBridge is IL1ERC20Bridge {
    // Event for when the L2ECO token implementation is upgraded
    event UpgradeL2ECO(address _newEcoImpl);

    // Event for when the L2ECOBridge authority is transferred to a new bridge address
    event UpgradeSelf(address _newBridgeImpl);

    // Event for when failed withdrawal needs to be u-turned
    event WithdrawalFailed(
        address indexed _l1Token,
        address indexed _l2Token,
        address indexed _from,
        address _to,
        uint256 _amount,
        bytes _data
    );

    /**
     * @param _l1messenger L1 Messenger address being used for cross-chain communications.
     * @param _l2TokenBridge L2 standard bridge address.
     * @param _ecoAddress address of L1 ECO contract.
     * @param _l1ProxyAdmin address of ProxyAdmin contract for the L1 Bridge.
     * @param _upgrader address that can perform upgrades.
     */
    function initialize(address _l1messenger,
        address _l2TokenBridge,
        address _ecoAddress,
        address _l1ProxyAdmin,
        address _upgrader
    ) external;

    /**
     * @dev Upgrades the L2ECO token implementation address, by sending
     *      a cross domain message to the L2 Bridge via the L1 Messenger
     * @param _impl L2 contract address.
     * @param _l2Gas Gas limit for the L2 message.
     */
    function upgradeECO(address _impl, uint32 _l2Gas) external;

    /**
     * @dev Upgrades this contract implementation by passing the new implementation address to the ProxyAdmin.
     * @param _newBridgeImpl The new L1ECOBridge implementation address.
     */
    function upgradeSelf(address _newBridgeImpl) external;
    
    /**
     * @dev initiates the propagation of a linear rebase from L1 to L2
     * @param _l2Gas Gas limit for the L2 message.
     */
    function rebase(uint32 _l2Gas) external;
}
