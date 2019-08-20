const Puzzle = artifacts.require("Puzzle");
const ECVerify = artifacts.require("ECVerify");

module.exports = function(deployer) {
  deployer.deploy(ECVerify);
  deployer.link(ECVerify, Puzzle);
};
