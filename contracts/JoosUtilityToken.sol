pragma solidity ^0.4.24;

import "../node_modules/openzeppelin-solidity/contracts/token/ERC20/ERC20Mintable.sol";

contract JoosUtilityToken is ERC20Mintable {
    string public name = "JoosUtilityToken";
    string public symbol = "JUT";
    uint public decimals = 18;

    constructor(address _newMinter) public {
        addMinter(_newMinter);
        renounceMinter();
    }
}