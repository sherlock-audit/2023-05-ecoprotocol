import hre from 'hardhat'
import { getProxyAdmin } from '../test/utils/fixtures'
import { L1ECOBridge } from '../typechain-types'
import {
  L1_NETWORK,
  L2_NETWORK,
  l1BridgeProxyAddress,
  l2BridgeProxyAddress,
} from './constants'

const l2gas = '10'

async function main() {
  hre.changeNetwork(L1_NETWORK)

  const bridge = (await hre.ethers.getContractAt(
    'L1ECOBridge',
    l1BridgeProxyAddress
  )) as L1ECOBridge

  const upgraderAddress = await bridge.upgrader()
  const [me] = await hre.ethers.getSigners()
  if ((await me.getAddress()) !== upgraderAddress) {
    throw new Error('you need to be the upgrader to run this script')
  }

  // deploy new contract
  hre.changeNetwork(L2_NETWORK)

  const l2ProxyAdmin = await getProxyAdmin()

  const owner = await l2ProxyAdmin.owner()
  if (owner !== l2BridgeProxyAddress) {
    throw new Error('the bridge must own the proxy admin to run this script')
  }

  const oldImpl = await l2ProxyAdmin.getProxyImplementation(
    l2BridgeProxyAddress
  )
  console.log(`old implementation is: ${oldImpl}`)

  const L2ECOBridgeFactory = await hre.ethers.getContractFactory('L2ECOBridge')
  const newL2ECOBridgeImpl = await L2ECOBridgeFactory.deploy()
  await newL2ECOBridgeImpl.deployed()
  console.log(`new L2 Bridge deployed to ${newL2ECOBridgeImpl.address}`)

  hre.changeNetwork(L1_NETWORK)

  const tx = await bridge.upgradeL2Bridge(newL2ECOBridgeImpl.address, l2gas)
  await tx.wait()
  console.log(`L2 Bridge upgraded`)

  // cannot check updated implementation in the script because of message transmission time
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
