import { ethers } from 'hardhat'
import { L2ECOBridge } from '../typechain-types'

async function main() {
  const L2ECOBridgeContract = await ethers.getContractFactory('L2ECOBridge')
  const bridge = (await L2ECOBridgeContract.attach(
    process.env.L2_BRIDGE_ADDRESS || ''
  )) as L2ECOBridge

  console.log(`l1TokenBridge ${await bridge.l1TokenBridge()}`)
  console.log(`l2EcoToken ${await bridge.l2EcoToken()}`)
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
