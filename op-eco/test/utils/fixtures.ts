import { ethers, upgrades } from 'hardhat'
import {
  L2ECO,
  L1ECOBridge,
  L2ECOBridge,
  ProxyAdmin,
} from '../../typechain-types'
import { Address } from '@eth-optimism/core-utils'

export async function deployL1Test(
  l1CrossDomainMessenger: Address,
  l2Bridge: Address,
  l1Token: Address,
  upgrader: Address
): Promise<[L1ECOBridge, ProxyAdmin]> {
  // const proxyAdmin = (await upgrades.admin.getInstance()) as ProxyAdmin
  const l1BridgeProxyAddress = await deployBridgeProxy()
  const proxyAdmin = await getProxyAdmin()

  const l1BridgeProxy = await initializeBridgeL1(
    l1BridgeProxyAddress,
    l1CrossDomainMessenger,
    l2Bridge,
    l1Token,
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

  const l2EcoProxy = await initializeEcoL2(
    l2EcoProxyAddress,
    l1Token,
    l2BridgeProxyAddress
  )

  const l2BridgeProxy = await initializeBridgeL2(
    l2BridgeProxyAddress,
    l2CrossDomainMessenger,
    l1Bridge,
    l2EcoProxyAddress,
    proxyAdmin.address
  )

  return [l2EcoProxy as L2ECO, l2BridgeProxy as L2ECOBridge, proxyAdmin]
}

export async function initializeBridgeL1(
  l1BridgeProxyAddress: Address,
  l1messenger: Address,
  l2BridgeAddress: Address,
  ecoAddress: Address,
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
          ecoAddress,
          l1ProxyAdmin,
          upgrader,
        ],
      },
    }
  )

  return l1BridgeProxy as L1ECOBridge
}

export async function initializeBridgeL2(
  l2BridgeProxyAddress: Address,
  l2messenger: Address,
  l1BridgeAddress: Address,
  l2EcoToken: Address,
  l2ProxyAdmin: Address
): Promise<L2ECOBridge> {
  const L2ECOBridgeContract = await ethers.getContractFactory('L2ECOBridge')

  const l2BridgeProxy = await upgrades.upgradeProxy(
    l2BridgeProxyAddress,
    L2ECOBridgeContract,
    {
      call: {
        fn: 'initialize',
        args: [l2messenger, l1BridgeAddress, l2EcoToken, l2ProxyAdmin],
      },
    }
  )

  return l2BridgeProxy as L2ECOBridge
}

export async function initializeEcoL2(
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

//   const L2ECOBridgeContract = await ethers.getContractFactory('L2ECOBridge')
//   const l2BridgeProxy = await upgrades.deployProxy(
//     L2ECOBridgeContract,
//     [
//       l2CrossDomainMessenger,
//       l1Bridge,
//       proxyInitial.address,
//       proxyAdmin.address,
//     ],
//     {
//       initializer: 'initialize',
//     }
//   )
//   await l2BridgeProxy.deployed()

//   const L2EcoContract = await ethers.getContractFactory('L2ECO')
//   const l2EcoProxy = await upgrades.upgradeProxy(
//     proxyInitial.address,
//     L2EcoContract,
//     {
//       call: {
//         fn: 'initialize',
//         args: [l1Token, l2BridgeProxy.address] as L2EcoContract,
//       },
//     }
//   )

//   if (opts.adminBridge) {
//     // transferOwnership(l2BridgeProxy.address)
//     // console.log("ProxyAdmin Owner: ", await proxyAdmin.owner())
//   }

//   return [l2EcoProxy as L2ECO, l2BridgeProxy as L2ECOBridge, proxyAdmin]
// }

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
