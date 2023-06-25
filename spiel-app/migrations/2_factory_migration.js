const GameFactory = artifacts.require("GameFactory");
const Game = artifacts.require("Game");

module.exports = function(deployer) {
    deployer.deploy(GameFactory, Game.address);
}

