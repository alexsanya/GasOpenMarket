import { ethers, Contract, ContractFactory, Wallet } from "ethers";
import priceOracleArtifact from "../out/PriceOracle.sol/PriceOracle.json" assert { type: 'json' };
import gasBrokerArtifact from "../out/GasBroker.sol/GasBroker.json" assert { type: 'json' };
import fundUSDCArtifact from "../out/FundUSDC.sol/FundUSDC.json" assert { type: 'json' };
import config from "./config.js";

const { PROVIDER_URL, SIGNER_PRIVATE_KEY, CUSTOMER_ADDRESS } = config;


const CHAIN_ID = 137;
const ONE_ETH = 10n ** 18n;

const provider = new ethers.providers.JsonRpcProvider(PROVIDER_URL);
const signer = new Wallet(SIGNER_PRIVATE_KEY, provider);
const USDC = "0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359";

const ERC20abi = [
  "function balanceOf(address) external view returns (uint256)",
  "function transfer(address, uint256) external returns (bool)"
]
const usdcContract = new Contract(USDC, ERC20abi, provider);


async function setUp() {
  const priceOracleContract = await deployContract('PriceOracle', priceOracleArtifact);
  const priceOracleAddress = priceOracleContract.address;
  
  await deployContract('GasBroker', gasBrokerArtifact, CHAIN_ID, priceOracleAddress);

  const fundUSDCcontract = await deployContract('FundUSDC', fundUSDCArtifact);
  
  //fund wallet with USDC
  let tx = await fundUSDCcontract.swapExactOutputSingle(10e6, 100n*ONE_ETH, { value: 100n*ONE_ETH });
  await tx.wait();

  console.log(`Deployer USDC ballance is ${await usdcContract.balanceOf(signer.address)}`);
  tx = await usdcContract.connect(signer).transfer(CUSTOMER_ADDRESS, 10e6);
  await tx.wait();
  console.log(`Customer USDC ballance is ${await usdcContract.balanceOf(CUSTOMER_ADDRESS)}`);
  console.log(`Customer ETH ballance is ${await provider.getBalance(CUSTOMER_ADDRESS)}`);

}

async function deployContract(name, artifact, ...constructorArgs) {
  const { abi, bytecode } = artifact
  const factory = new ContractFactory(abi, bytecode, signer);
  const contract = await factory.deploy(...constructorArgs);
  await contract.deployTransaction.wait();
  console.log(`Contract ${name} deployed at address ${await contract.address}`);
  return contract;
}

setUp();

