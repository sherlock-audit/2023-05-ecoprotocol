import { getProxyAdmin } from '../test/utils/fixtures'

const address = '0x54bBECeA38ff36D32323f8A754683C1F5433A89f'

async function main() {
  const proxyAdmin = await getProxyAdmin()

  const implAddress = await proxyAdmin.getProxyImplementation(address)

  console.log(`impl at : ${implAddress}`)
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
