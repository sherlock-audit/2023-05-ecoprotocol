/**
 * @notice Contains all error strings used in the contracts.
 * Should be exported in package
 */
export const ERROR_STRINGS = {
  OVM: {
    INVALID_MESSENGER: 'OVM_XCHAIN: messenger contract unauthenticated',
    INVALID_X_DOMAIN_MSG_SENDER:
      'OVM_XCHAIN: wrong sender of cross-domain message',
  },
  L1ECOBridge: {
    INVALID_L2_ADDRESS: 'L1ECOBridge: invalid L2 token address',
    INVALID_L1_ADDRESS: 'L1ECOBridge: invalid L1 token address',
    UNAUTHORIZED_UPGRADER:
      'L1ECOBridge: caller not authorized to upgrade L2 contracts.',
  },
  L2ECOBridge: {
    INVALID_L2_ADDRESS: 'L2ECOBridge: invalid L2 token address',
    INVALID_L1_ADDRESS: 'L2ECOBridge: invalid L1 token address',
    INVALID_INFLATION_MULTIPLIER: 'L2ECOBridge: invalid inflation multiplier',
  },
  L2ECO: {
    UNAUTHORIZED_MINTER: 'L2ECO: not authorized to mint',
    UNAUTHORIZED_BURNER: 'L2ECO: not authorized to burn',
    UNAUTHORIZED_REBASER: 'L2ECO: not authorized to rebase',
    UNAUTHORIZED_TOKEN_ROLE_ADMIN: 'L2ECO: not authorized to edit roles',
  },
  UPGRADES: {
    ALREADY_INITIALIZED: 'Initializable: contract is already initialized',
  },
  OWNABLE: {
    NOT_OWNER: 'Ownable: caller is not the owner',
  },
}
