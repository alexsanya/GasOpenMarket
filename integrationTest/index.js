import { ethers, Contract, ContractFactory, Wallet } from "ethers";
import priceOracleArtifact from "../out/PriceOracle.sol/PriceOracle.json" assert { type: 'json' };
import gasBrokerArtifact from "../out/GasBroker.sol/GasBroker.json" assert { type: 'json' };
import fundUSDCArtifact from "../out/FundUSDC.sol/FundUSDC.json" assert { type: 'json' };

const { PROVIDER_URL, SIGNER_PRIVATE_KEY } = config;

const provider = new ethers.providers.JsonRpcProvider(PROVIDER_URL);
const signer = new Wallet(SIGNER_PRIVATE_KEY, provider);
const customer = new Wallet("08d11cc57eca3df70d53ad570de0f2c6926c33fb93bc16fb9b9dcd25d54818bf", provider);

const USDC = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48";

async function setUp() {
  const chainId = (await provider.getNetwork()).chainId;
  // deploy contracts
  const priceOracleContract = await deployContract('PriceOracle', priceOracleArtifact);
  const priceOracleAddress = await priceOracleContract.address;
  const gasBrokerContract = await deployContract('GasBroker', gasGatewayArtifact, chainId, priceOracleAddress);
  const gasBrokerAddress = await gasBrokerContract.address;

  const fundUSDCcontract = await deployContract('FundUSDC', fundUSDCArtifact);
  const tx = await fundUSDCcontract.connect(signer).swapExactOutputSingle(100e6, 10n ** 18n, { value: 10n ** 18n });
  await tx.wait();

  console.log(`Deployer USDC ballance is ${await usdcContract.balanceOf(signer.address)}`);
  tx = await usdcContract.connect(signer).transfer(customer.address, 100e6);
  await tx.wait();
  console.log(`Customer USDC ballance is ${await usdcContract.balanceOf(customer.address)}`);
  console.log(`Customer ETH ballance is ${await provider.getBalance(customer.address)}`);

  //prepare signature
  const { r: permitR, v: permitV, s: permitS, deadline } = await getPermitSignature(gasBrokerAddress);
  const abiCoder = ethers.utils.defaultAbiCoder;
  console.log({ permitR, permitV, permitS, deadline });
  const permitHash = ethers.utils.keccak256(
    abiCoder.encode(
      ["uint8", "bytes32", "bytes32"],
      [ permitR, permitV, permitS ]
    )
  );
  const { r: rewardR, v: rewardV, s: rewardS } = await getRewardSignature(10e6, permitHash);
  console.log({ rewardR, rewardV, rewardS });

  const value = await gasBroker.getEthAmount(USDC, 90e6);

  console.log("Value to sent to customer: ", value);

  await gasBroker.connect(signer).swap(
    customer.address,
    USDC,
    100e6,
    deadline,
    10e6,
    permitV,
    permitR,
    permitS,
    rewardV,
    rewardR,
    rewardS,
    { value }
  );
}

async function deployContract(name, artifact, ...constructorArgs) {
  const { abi, bytecode } = artifact
  const factory = new ContractFactory(abi, bytecode, signer);
  const contract = await factory.deploy(...constructorArgs);
  await contract.deployTransaction.wait();
  console.log(`Contract ${name} deployed at address ${await contract.address}`);
  return contract;
}


async function getPermitSignature(gasBrokerAddress) {

  const chainId = (await provider.getNetwork()).chainId;
  // set the domain parameters
  const domain = {
    name: await usdcContract.name(),
    version: await usdcContract.version(),
    chainId: chainId,
    verifyingContract: USDC
  };

  console.log(domain);

  // set the Permit type parameters
  const types = {
    Permit: [{
        name: "owner",
        type: "address"
      },
      {
        name: "spender",
        type: "address"
      },
      {
        name: "value",
        type: "uint256"
      },
      {
        name: "nonce",
        type: "uint256"
      },
      {
        name: "deadline",
        type: "uint256"
      },
    ],
  };
  const deadline = (await provider.getBlock("latest")).timestamp + 3600000;
  const values = {
    owner: customer.address,
    spender: gasBrokerAddress,
    value: 100e6,
    nonce: await usdcContract.nonces(customer.address),
    deadline
  };
  console.log("Values: ", values);
  const signature = await customer._signTypedData(domain, types, values);

  const { v, r, s } = ethers.utils.splitSignature(signature);
  console.log({ v, r, s});

  const nonce = await usdcContract.nonces(customer.address);
  console.log({ nonce });

  return { r, v, s, deadline};
}


async function getRewardSignature(value, permitHash) {

  const chainId = (await provider.getNetwork()).chainId;
  // set the domain parameters
  const domain = {
    name: await gasBrokerContract.name(),
    version: await gasBrokerContract.version(),
    chainId: chainId,
    verifyingContract: gasBrokerAddress
  };

  console.log(domain);

  // set the Permit type parameters
  const types = {
    Reward: [{
        name: "value",
        type: "uint256"
      },
      {
        name: "permitHash",
        type: "bytes32"
      }
    ],
  };
  const deadline = (await provider.getBlock("latest")).timestamp + 3600000;
  const values = {
    value,
    permitHash
  };
  console.log("Values: ", values);
  const signature = await customer._signTypedData(domain, types, values);

  const { v, r, s } = ethers.utils.splitSignature(signature);

  return { r, v, s };
}


