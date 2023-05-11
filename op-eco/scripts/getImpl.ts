import { ethers } from 'hardhat'

async function main() {
  const ProxyAdminContract = await ethers.getContractFactory('ProxyAdmin')
  const proxyAdmin = await ProxyAdminContract.attach(
    process.env.PROXY_ADMIN_ADDRESS || ''
  )

  const bridgeAddress = await proxyAdmin.getProxyImplementation(
    process.env.L1_BRIDGE_ADDRESS || ''
    // process.env.L2_BRIDGE_ADDRESS || ""
  )

  console.log(`Bridge deployed to: ${bridgeAddress}`)
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
