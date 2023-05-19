import hre from 'hardhat'
import { L1ECOBridge, ECO } from '../typechain-types'
import {
  L1_ECO_ADDRESS,
  L1_NETWORK,
  l1BridgeProxyAddress,
  l2EcoProxyAddress,
} from './constants'

const bridgeAmount = '500000' // in full ECO

const l2gas = '10'

async function main() {
  hre.changeNetwork(L1_NETWORK)
  const bridge = (await hre.ethers.getContractAt(
    'L1ECOBridge',
    l1BridgeProxyAddress
  )) as L1ECOBridge
  const eco = (await hre.ethers.getContractAt('ECO', L1_ECO_ADDRESS)) as ECO

  const weiAmount = hre.ethers.utils.parseEther(bridgeAmount)

  const tx1 = await eco.approve(l1BridgeProxyAddress, weiAmount)
  await tx1.wait()

  const tx2 = await bridge.depositERC20(
    L1_ECO_ADDRESS,
    l2EcoProxyAddress,
    weiAmount,
    l2gas,
    hre.ethers.utils.arrayify('0x1234')
  )
  await tx2.wait()
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
