import { transferOwnership } from '../test/utils/fixtures'
import {
  L1_NETWORK,
  L2_NETWORK,
  l1BridgeProxyAddress,
  l2BridgeProxyAddress,
} from './constants'

// this script is for transferring ownership of the proxy admin to the proxy

// set chain here
const chain = 'L1'

const network = chain === 'L1' ? L1_NETWORK : L2_NETWORK
const proxy = chain === 'L1' ? l1BridgeProxyAddress : l2BridgeProxyAddress

async function main() {
  await transferOwnership(network, proxy)
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
