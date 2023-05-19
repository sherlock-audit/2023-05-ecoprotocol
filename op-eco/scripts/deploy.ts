import hre from 'hardhat'
import {
  deployBridgeProxy,
  deployTokenProxy,
  getProxyAdmin,
  upgradeBridgeL1,
  upgradeBridgeL2,
  upgradeEcoL2,
} from '../test/utils/fixtures'
import {
  L1_ECO_ADDRESS,
  L1_NETWORK,
  L1_OP_MESSANGER_ADDRESS,
  L2_NETWORK,
  L2_OP_MESSANGER_ADDRESS,
  UPGRADER_ADDRESS,
} from './constants'

async function main() {
  hre.changeNetwork(L1_NETWORK)

  const l1BridgeProxyAddress = await deployBridgeProxy()
  console.log(`L1 Bridge deployed to: ${l1BridgeProxyAddress}`)

  const l1ProxyAdmin = await getProxyAdmin(true)
  console.log(`Proxy Admin L1 deployed to: ${l1ProxyAdmin.address}`)

  hre.changeNetwork(L2_NETWORK)

  const l2BridgeProxyAddress = await deployBridgeProxy()
  console.log(`L2 Bridge deployed to: ${l2BridgeProxyAddress}`)

  const l2EcoProxyAddress = await deployTokenProxy()
  console.log(`L2ECO deployed to: ${l2EcoProxyAddress}`)

  const l2ProxyAdmin = await getProxyAdmin(true)
  console.log(`Proxy Admin L2 deployed to: ${l2ProxyAdmin.address}`)

  await upgradeEcoL2(l2EcoProxyAddress, L1_ECO_ADDRESS, l2BridgeProxyAddress)
  console.log(`L2 ECO initialized`)

  await upgradeBridgeL2(
    l2BridgeProxyAddress,
    L2_OP_MESSANGER_ADDRESS,
    l1BridgeProxyAddress,
    L1_ECO_ADDRESS,
    l2EcoProxyAddress,
    l2ProxyAdmin.address
  )
  console.log(`L2 Bridge initialized`)

  hre.changeNetwork(L1_NETWORK)

  await upgradeBridgeL1(
    l1BridgeProxyAddress,
    L1_OP_MESSANGER_ADDRESS,
    l2BridgeProxyAddress,
    L1_ECO_ADDRESS,
    l2EcoProxyAddress,
    l1ProxyAdmin.address,
    UPGRADER_ADDRESS
  )
  console.log(`L1 Bridge initialized`)
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
