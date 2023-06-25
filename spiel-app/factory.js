import Web3 from "web3";
import GameFactoryABI from '/build/contracts/GameFactory.json';

const provider = new Web3.providers.HttpProvider(
    "HTTP://127.0.0.1:7545"
)

const web3 = new Web3(provider)

var FactorycontractAddress = GameFactoryABI.networks['5777'].address
// wenn auf sepolia deployed, dann hier die direkte Adresse des deployeten FactoryContract hardcoded eintrage:
//var FactorycontractAddress = 0xe88b9d1992dae46967dde845550725dc8e5bdfd5

const factoryContract = new web3.eth.Contract(GameFactoryABI.abi, FactorycontractAddress)

export default factoryContract