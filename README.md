
# Eco Protocol contest details

- Join [Sherlock Discord](https://discord.gg/MABEWyASkp)
- Submit findings using the issue page in your private contest repo (label issues as med or high)
- [Read for more details](https://docs.sherlock.xyz/audits/watsons)

# Q&A

### Q: On what chains are the smart contracts going to be deployed?
mainnet, Optimism, Base
___

### Q: Which ERC20 tokens do you expect will interact with the smart contracts? 
ECO token at 0x8dBF9A4c99580fC7Fd4024ee08f3994420035727
___

### Q: Which ERC721 tokens do you expect will interact with the smart contracts? 
none
___

### Q: Which ERC777 tokens do you expect will interact with the smart contracts? 
none
___

### Q: Are there any FEE-ON-TRANSFER tokens interacting with the smart contracts?

non
___

### Q: Are there any REBASING tokens interacting with the smart contracts?

Yes, both the ECO token and the token in the repo. Rebases are EOA triggered and infrequent.
___

### Q: Are the admins of the protocols your contracts integrate with (if any) TRUSTED or RESTRICTED?
There is a trusted admin contract given access to the L1ECOBridge contract as the upgrader. There is also trusted contracts in the Optimism (and Base) contract system that have certain privileges, but whatsons should have an understanding of these.
___

### Q: Is the admin/owner of the protocol/contracts TRUSTED or RESTRICTED?
as part of deploy, any ownership roles are given away to the contracts themselves
___

### Q: Are there any additional protocol roles? If yes, please explain in detail:
The ECO token (on mainnet) has a pausing role that allows the triggering of a pause (reverting all transfers). This action should not cause the permanent loss of user funds. Funds must be recoverable once the pause is lifted.
___

### Q: Is the code/contract expected to comply with any EIPs? Are there specific assumptions around adhering to those EIPs that Watsons should be aware of?
EIP 712
___

### Q: Please list any known issues/acceptable risks that should not result in a valid finding.
AMM (or any external contract) arbitrage due to rebasing is not a valid finding.

The audit is meant to be focused heavily on High/Medium issues that affect L2ECOBridge.sol, L1ECOBridge.sol and L2ECO.sol. If there is a Medium issue found in ECO.sol but it does not affect the three contracts above, then it may not be considered in scope and rewarded. ECO.sol and other contracts were put in scope simply to allow Watsons to find any issues in those contracts that would also affect the main 3 contracts (L2ECOBridge.sol, L1ECOBridge.sol and L2ECO.sol).
___

### Q: Please provide links to previous audits (if any).
none
___

### Q: Are there any off-chain mechanisms or off-chain procedures for the protocol (keeper bots, input validation expectations, etc)?
no relevant mechanisms
___

### Q: In case of external protocol integrations, are the risks of external contracts pausing or executing an emergency withdrawal acceptable? If not, Watsons will submit issues related to these situations that can harm your protocol's functionality.
yes
___



# Audit scope


[op-eco @ 39f205fb46eea3df770f0119a890ffdc1ac8f382](https://github.com/eco-association/op-eco/tree/39f205fb46eea3df770f0119a890ffdc1ac8f382)
- [op-eco/contracts/bridge/L2ECOBridge.sol](op-eco/contracts/bridge/L2ECOBridge.sol)
- [op-eco/contracts/bridge/L1ECOBridge.sol](op-eco/contracts/bridge/L1ECOBridge.sol)
- [op-eco/contracts/bridge/InitialBridge.sol](op-eco/contracts/bridge/InitialBridge.sol)
- [op-eco/contracts/token/L2ECO.sol](op-eco/contracts/token/L2ECO.sol)
- [op-eco/contracts/token/TokenInitial.sol](op-eco/contracts/token/TokenInitial.sol)
- [op-eco/contracts/bridge/CrossDomainEnabledUpgradeable.sol](op-eco/contracts/bridge/CrossDomainEnabledUpgradeable.sol)
- [op-eco/contracts/token/ERC20Upgradeable.sol](op-eco/contracts/token/ERC20Upgradeable.sol)


