// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@helix-foundation/currency/contracts/policy/Policy.sol";
import "@helix-foundation/currency/contracts/policy/Policed.sol";
import "@helix-foundation/currency/contracts/governance/community/proposals/Proposal.sol";
import "../bridge/L1ECOBridge.sol";

/** @title Upgrade L2Bridge or L2ECO
 * A proposal to trigger the upgrade cycle on the L2
 */
contract TriggerL2Upgrade is Policy, Proposal {
    // The address to be targeted by the new notifier tx data
    L1ECOBridge public immutable l1Bridge;

    // The L2 address for the new implementation
    address public immutable l2Impl;

    // How much gas to pre-allocate for L2 execution
    uint32 public immutable l2Gas;

    /** Instantiate a new proposal.
     *
     * @param _l1Bridge The address of the L1 Bridge
     * @param _l2Impl The address on L2 of the new implementation contract
     * @param _l2Gas The amount of gas to pre-allocate for L2 execution
     */
    constructor(
        address _l1Bridge,
        address _l2Impl,
        uint32 _l2Gas
    ) {
        l1Bridge = L1ECOBridge(_l1Bridge);
        l2Impl = _l2Impl;
        l2Gas = _l2Gas;
    }

    /** The name of the proposal.
     */
    function name() public pure override returns (string memory) {
        return "A proposal to trigger the upgrade cycle on the L2";
    }

    /** A description of what the proposal does.
     */
    function description() public pure override returns (string memory) {
        return "This proposal upgrades the L2 ECO on Optimism"; // can be adapted to L2 bridge upgrade probably
    }

    /** A URL where more details can be found.
     */
    function url() public pure override returns (string memory) {
        return "";
    }

    /** Calls the function on the L1Bridge
     * this function only accepts calls via governance by the root policy
     */
    function enacted(address) public override {
        l1Bridge.upgradeECO(l2Impl, l2Gas);
    }
}
