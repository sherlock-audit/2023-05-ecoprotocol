import hre from 'hardhat'
import {
  L2ECO,
  L1ECOBridge,
  L2ECOBridge,
  ProxyAdmin,
} from '../../typechain-types'
import { Address } from '@eth-optimism/core-utils'
const { ethers, upgrades } = hre

export async function deployL1Test(
  l1CrossDomainMessenger: Address,
  l2Bridge: Address,
  l1Token: Address,
  l2Token: Address,
  upgrader: Address
): Promise<[L1ECOBridge, ProxyAdmin]> {
  // const proxyAdmin = (await upgrades.admin.getInstance()) as ProxyAdmin
  const l1BridgeProxyAddress = await deployBridgeProxy()
  const proxyAdmin = await getProxyAdmin()

  const l1BridgeProxy = await upgradeBridgeL1(
    l1BridgeProxyAddress,
    l1CrossDomainMessenger,
    l2Bridge,
    l1Token,
    l2Token,
    proxyAdmin.address,
    upgrader
  )

  return [l1BridgeProxy as L1ECOBridge, proxyAdmin]
}

export async function deployL2Test(
  l2CrossDomainMessenger: Address,
  l1Bridge: Address,
  l1Token: Address
  // opts: { adminBridge: boolean } = { adminBridge: true }
): Promise<[L2ECO, L2ECOBridge, ProxyAdmin]> {
  const l2BridgeProxyAddress = await deployBridgeProxy()
  const l2EcoProxyAddress = await deployTokenProxy()
  const proxyAdmin = await getProxyAdmin()

  const l2EcoProxy = await upgradeEcoL2(
    l2EcoProxyAddress,
    l1Token,
    l2BridgeProxyAddress
  )

  const l2BridgeProxy = await upgradeBridgeL2(
    l2BridgeProxyAddress,
    l2CrossDomainMessenger,
    l1Bridge,
    l1Token,
    l2EcoProxyAddress,
    proxyAdmin.address
  )

  return [l2EcoProxy as L2ECO, l2BridgeProxy as L2ECOBridge, proxyAdmin]
}

export async function upgradeBridgeL1(
  l1BridgeProxyAddress: Address,
  l1messenger: Address,
  l2BridgeAddress: Address,
  l1ECO: Address,
  l2ECO: Address,
  l1ProxyAdmin: Address,
  upgrader: Address
) {
  const L1ECOBridgeContract = await ethers.getContractFactory('L1ECOBridge')

  const l1BridgeProxy = await upgrades.upgradeProxy(
    l1BridgeProxyAddress,
    L1ECOBridgeContract,
    {
      call: {
        fn: 'initialize',
        args: [
          l1messenger,
          l2BridgeAddress,
          l1ECO,
          l2ECO,
          l1ProxyAdmin,
          upgrader,
        ],
      },
    }
  )

  return l1BridgeProxy as L1ECOBridge
}

export async function upgradeBridgeL2(
  l2BridgeProxyAddress: Address,
  l2messenger: Address,
  l1BridgeAddress: Address,
  l1Eco: Address,
  l2Eco: Address,
  l2ProxyAdmin: Address
): Promise<L2ECOBridge> {
  const L2ECOBridgeContract = await ethers.getContractFactory('L2ECOBridge')

  const l2BridgeProxy = await upgrades.upgradeProxy(
    l2BridgeProxyAddress,
    L2ECOBridgeContract,
    {
      call: {
        fn: 'initialize',
        args: [l2messenger, l1BridgeAddress, l1Eco, l2Eco, l2ProxyAdmin],
      },
    }
  )

  return l2BridgeProxy as L2ECOBridge
}

export async function upgradeEcoL2(
  l2EcoProxyAddress: Address,
  l1EcoToken: Address,
  l2BridgeAddress: Address
): Promise<L2ECO> {
  const L2ECOContract = await ethers.getContractFactory('L2ECO')

  const l2EcoProxy = await upgrades.upgradeProxy(
    l2EcoProxyAddress,
    L2ECOContract,
    {
      call: {
        fn: 'initialize',
        args: [l1EcoToken, l2BridgeAddress],
      },
    }
  )

  return l2EcoProxy as L2ECO
}

export async function deployBridgeProxy(): Promise<Address> {
  const InitialBridgeContract = await ethers.getContractFactory('InitialBridge')
  const proxyInitial = await upgrades.deployProxy(InitialBridgeContract, [], {
    initializer: 'initialize',
  })
  // const proxyInitial = await upgrades.deployProxy(InitialBridgeContract, [])

  await proxyInitial.deployed()

  return proxyInitial.address
}

export async function deployTokenProxy(): Promise<Address> {
  const TokenInitialContract = await ethers.getContractFactory('TokenInitial')
  const proxyInitial = await upgrades.deployProxy(TokenInitialContract, [], {
    initializer: 'initialize',
  })

  await proxyInitial.deployed()

  return proxyInitial.address
}

export async function getProxyAdmin(
  verbose: boolean = false
): Promise<ProxyAdmin> {
  const proxyAdmin = (await upgrades.admin.getInstance()) as ProxyAdmin
  if (verbose) {
    console.log(`address : ${proxyAdmin.address}`)
    console.log(`owner : ${await proxyAdmin.owner()}`)
  }

  await proxyAdmin.deployed()

  return proxyAdmin
}

export async function transferOwnership(
  network: string,
  proxy: Address
): Promise<void> {
  hre.changeNetwork(network)

  const proxyAdmin = await getProxyAdmin()

  const currentOwner = await proxyAdmin.owner()
  const [me] = await hre.ethers.getSigners()
  if ((await me.getAddress()) !== currentOwner) {
    throw new Error('you need to own the proxy admin to run this script')
  }

  await proxyAdmin.transferOwnership(proxy)
  console.log(`admin owner changed to ${proxy}`)
}

export async function transferOwnershipTest(
  newOwnerAddress: Address
): Promise<void> {
  const [owner] = await ethers.getSigners()
  const proxyAdmin = (await upgrades.admin.getInstance()) as ProxyAdmin
  await proxyAdmin.connect(owner).transferOwnership(newOwnerAddress)
}

export async function deployByName(name: string, ...args: any[]): Promise<any> {
  const Contract = await ethers.getContractFactory(name)
  const contract = await Contract.deploy(...args)
  await contract.deployed()
  return contract
}
