import Web3 from "web3";
import GameABI from '/build/contracts/Game.json';

const provider = new Web3.providers.HttpProvider(
	"HTTP://127.0.0.1:7545"
)

const web3 = new Web3(provider)

var GamecontractAddress = GameABI.networks['5777'].address
// wenn auf sepolia deployed, dann hier die direkte Adresse des deployeten GameContract hardcoded eintrage:
// var GamecontractAddress = 0x908dfe9183178b0e2c0c1c20b3cbca6246140857

const gameContract = new web3.eth.Contract(GameABI.abi, GamecontractAddress )

export default gameContract