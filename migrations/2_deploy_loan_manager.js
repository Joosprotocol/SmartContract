var JoosLoanManager = artifacts.require("./JoosLoanManager");

module.exports = function(deployer) {
    deployer.deploy(JoosLoanManager);
};