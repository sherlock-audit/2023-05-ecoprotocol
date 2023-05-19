import hre from 'hardhat'
import { L2ECOBridge } from '../typechain-types'
import { L2_NETWORK, l2BridgeProxyAddress } from './constants'

async function main() {
  hre.changeNetwork(L2_NETWORK)
  const bridge = (await hre.ethers.getContractAt(
    'L2ECOBridge',
    l2BridgeProxyAddress
  )) as L2ECOBridge

  console.log(`l1TokenBridge ${await bridge.l1TokenBridge()}`)
  console.log(`l2EcoToken ${await bridge.l2EcoToken()}`)
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
