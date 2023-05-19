import hre from 'hardhat'
import { L1ECOBridge } from '../typechain-types'
import { L1_NETWORK, l1BridgeProxyAddress } from './constants'

const l2gas = '10'

async function main() {
  hre.changeNetwork(L1_NETWORK)
  const bridge = (await hre.ethers.getContractAt(
    'L1ECOBridge',
    l1BridgeProxyAddress
  )) as L1ECOBridge

  const tx = await bridge.rebase(l2gas)
  await tx.wait()
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
