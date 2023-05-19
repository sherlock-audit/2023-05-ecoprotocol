import hre from 'hardhat'
import { L2ECOBridge } from '../typechain-types'
import { CrossChainMessenger, MessageStatus } from '@eth-optimism/sdk'
import { ContractTransaction } from 'ethers'
import {
  L1_NETWORK,
  L2_NETWORK,
  l2BridgeProxyAddress,
  l2EcoProxyAddress,
} from './constants'

const bridgeAmount = '50' // in full ECO

const l1gas = '1000'

async function main() {
  const { hash: withdrawalTxHash } = await initiateWithdrawal(bridgeAmount)
  console.log('withdrawal initiated, tx hash:')
  console.log(withdrawalTxHash)
  const crossChainMessenger = await setupOP()
  console.log('OP SDK initialized')
  // technically might need sleep here too, but proving takes forever anyway
  await proveWithdrawal(crossChainMessenger, withdrawalTxHash)
  console.log('withdrawal proven')
  console.log('sleeping to wait out finalization time')
  await new Promise((resolve) => setTimeout(resolve, 30000)) // sleep to wait for finalization window
  // eventually this will have to break out to its own script since mainnet has a 7 day delay
  await finalizeWithdrawal(crossChainMessenger, withdrawalTxHash)
  console.log('withdrawal finalized')
}

async function initiateWithdrawal(
  _bridgeAmount: string
): Promise<ContractTransaction> {
  hre.changeNetwork(L2_NETWORK)

  const bridge = (await hre.ethers.getContractAt(
    'L2ECOBridge',
    l2BridgeProxyAddress
  )) as L2ECOBridge

  const weiAmount = hre.ethers.utils.parseEther(_bridgeAmount)

  const tx = await bridge.withdraw(
    l2EcoProxyAddress,
    weiAmount,
    l1gas,
    hre.ethers.utils.arrayify('0x1234')
  )
  await tx.wait()
  return tx
}

async function setupOP(): Promise<CrossChainMessenger> {
  hre.changeNetwork(L2_NETWORK)
  const l2ChainId = hre.network.config.chainId
  const [l2Wallet] = await hre.ethers.getSigners()
  hre.changeNetwork(L1_NETWORK)
  const l1ChainId = hre.network.config.chainId
  const [l1Wallet] = await hre.ethers.getSigners()

  if (l2ChainId && l1ChainId) {
    return new CrossChainMessenger({
      l1ChainId,
      l2ChainId,
      l1SignerOrProvider: l1Wallet,
      l2SignerOrProvider: l2Wallet,
      bedrock: true,
    })
  } else {
    throw new Error('need chain IDs to use CrossChainMessenger')
  }
}

async function proveWithdrawal(
  crossChainMessenger: CrossChainMessenger,
  withdrawalTxHash: string
) {
  await crossChainMessenger.waitForMessageStatus(
    withdrawalTxHash,
    MessageStatus.READY_TO_PROVE
  )
  const tx = await crossChainMessenger.proveMessage(withdrawalTxHash)
  await tx.wait()
}

async function finalizeWithdrawal(
  crossChainMessenger: CrossChainMessenger,
  withdrawalTxHash: string
) {
  await crossChainMessenger.waitForMessageStatus(
    withdrawalTxHash,
    MessageStatus.READY_FOR_RELAY
  )
  const tx = await crossChainMessenger.finalizeMessage(withdrawalTxHash)
  await tx.wait()
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
