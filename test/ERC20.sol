pragma solidity >=0.4.21 <0.6.0;
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract SimpleToken is ERC20 {
  constructor() public {
    _mint(msg.sender, 100 ether);
  }
}
