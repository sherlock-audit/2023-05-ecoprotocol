import { ethers, upgrades, artifacts } from 'hardhat'

interface FactoryABI {
  abi: any[]
  bytecode: ethers.utils.BytesLike
}

export const randomAddress = () => {
  const bytes = ethers.utils.randomBytes(20)
  const string = ethers.utils.hexlify(bytes)
  return ethers.utils.getAddress(string)
}

export const deployFromName = async (
  name: string,
  opts?: {
    args?: any[]
    signer?: any
  }
): Promise<ethers.Contract> => {
  const factory = await ethers.getContractFactory(name, opts?.signer)
  return factory.deploy(...(opts?.args || []))
}

export async function deployProxyByName(
  name: string,
  args: any[] = [],
  opts: {}
): Promise<ethers.Contract> {
  const contract = await ethers.getContractFactory(name)

  // return await upgrades.deployProxy(contract, ...(opts?.args || []), opts?.opts || {})
  // console.log(opts?.args)
  return await upgrades.deployProxy(contract, args, opts)
}

export const deployFromABI = async (
  artifact: FactoryABI,
  opts?: {
    args?: any[]
    signer?: any
  }
): Promise<ethers.Contract> => {
  const factory = await ethers.getContractFactory(
    artifact.abi,
    artifact.bytecode,
    opts?.signer
  )
  return factory.deploy(...(opts?.args || []))
}

export const getContractInterface = async (
  contractName: string
): Promise<ethers.utils.Interface> => {
  const artifact = await artifacts.readArtifact(contractName)
  return new ethers.utils.Interface(artifact.abi)
}
