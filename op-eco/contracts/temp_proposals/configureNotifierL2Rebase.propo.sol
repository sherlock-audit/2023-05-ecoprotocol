// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@helix-foundation/currency/contracts/policy/Policy.sol";
import "@helix-foundation/currency/contracts/policy/Policed.sol";
import "@helix-foundation/currency/contracts/governance/community/proposals/Proposal.sol";
import "@helix-foundation/currency/contracts/governance/Notifier.sol";

/** @title Configure Notfier Rebasing to L2
 * A proposal to configure the rebasing each generation on the L2
 */
contract ConfigureNotifierL2Rebase is Policy, Proposal {
    // The new ID hash for the Notifier
    bytes32 public constant NOTIFIER_ID = keccak256("Notifier");

    // The encoded function signature of the rebase function
    // after Nishaad finishes setting up this function, I can put the value in a comment here
    bytes public rebaseFunctionData;

    // The L1Bridge address for passing rebase data
    address public immutable l1Bridge;

    /** Instantiate the proposal.
     *
     * @param _l1Bridge The address that will be targeted by the notifier
     * @param _rebaseFunctionData The function data that will be called on the address
     */
    constructor(address _l1Bridge, bytes memory _rebaseFunctionData) {
        l1Bridge = _l1Bridge;
        rebaseFunctionData = _rebaseFunctionData;
    }

    /** The name of the proposal.
     */
    function name() public pure override returns (string memory) {
        return "Configure Notfier Rebasing to L2";
    }

    /** A description of what the proposal does.
     */
    function description() public pure override returns (string memory) {
        return
            "This proposal configures the Notifier to pass changes in Linear Inflation to the Optimism L2";
    }

    /** A URL where more details can be found.
     */
    function url() public pure override returns (string memory) {
        return "";
    }

    /** Adds the necessary transaction to the notifier
     */
    function enacted(address self) public override {
        Notifier _notifier = Notifier(policyFor(NOTIFIER_ID));

        _notifier.addTransaction(
            l1Bridge,
            ConfigureNotifierL2Rebase(self).rebaseFunctionData()
        );
    }
}
