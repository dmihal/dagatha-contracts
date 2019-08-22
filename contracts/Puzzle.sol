pragma solidity >=0.4.21 <0.6.0;

import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./ECVerify.sol";

contract Puzzle is Ownable {
  using SafeMath for uint256;

  IERC20 private stakingToken;
  uint256 public donated;
  uint256 public withdrawn;

  struct State {
    uint256 staked;
    uint256 donated;
    bool[] foundClues;
    uint256 startTime;
  }

  mapping(address => State) private state;
  mapping(address => uint8) public clueToClueNum;

  uint256 public numClues;

  event FoundClue(address user, uint8 clueNum);
  event Donation(address user, uint256 amount);

  constructor(address _stakingToken, address[] memory clues) public {
    stakingToken = IERC20(_stakingToken);
    numClues = clues.length;
    for(uint8 i = 0; i < clues.length; i++) {
      clueToClueNum[clues[i]] = i + 1;
    }
  }

  function stake(uint256 amount) public {
    stakingToken.transferFrom(msg.sender, address(this), amount);
    state[msg.sender].staked = state[msg.sender].staked.add(amount);
    state[msg.sender].foundClues.length = numClues + 1;
    state[msg.sender].startTime = now;
  }

  function remainingStake(address user) public view returns (uint256) {
    return state[user].staked - state[user].donated;
  }

  function addressHash(address user) public pure returns (bytes32) {
    return keccak256(abi.encodePacked(user));
  }

  function didWin(address user) public view returns (bool) {
    State memory userState = state[user];
    for (uint256 i = 1; i <= numClues; i++) {
      if (!userState.foundClues[i]) {
        return false;
      }
    }
    return true;
  }

  function foundClue(address user, uint8 clueNum) public view returns (bool) {
    return state[user].foundClues[clueNum];
  }

  function foundAllClues(address user) public view returns (bool) {
    State memory userState = state[user];
    for (uint256 i = 1; i <= numClues; i++) {
      if (!userState.foundClues[i]) {
        return false;
      }
    }
    return true;
  }

  function isSignatureValid(address clue, bytes memory signature) public view returns (uint256) {
    if (!ECVerify.ecverify(addressHash(msg.sender), signature, clue)) {
      return 1;
    }

    return 0;
  }

  function isSignatureValidVRS(address clue, uint8 v, bytes32 r, bytes32 s) public view returns (uint256) {
    bytes memory prefix = "\x19Ethereum Signed Message:\n32";
    bytes32 hash = keccak256(abi.encodePacked(prefix, addressHash(msg.sender)));

    if (!(ecrecover(hash, v, r, s) == clue)) {
      return 1;
    }

    return 0;
  }

  function findClues(address[] memory clues, uint8[] memory vs, bytes32[] memory rs, bytes32[] memory ss) public {
    require(clues.length == vs.length);
    require(clues.length == rs.length);
    require(clues.length == ss.length);

    for (uint i = 0; i < clues.length; i++) {
      findClueVRS(clues[i], vs[i], rs[i], ss[i]);
    }
  }

  function findClue(address clue, bytes memory signature) public {
    require(state[msg.sender].staked > 0, 'Must stake');
    require(clueToClueNum[clue] > 0, 'Invalid clue');
    require(ECVerify.ecverify(addressHash(msg.sender), signature, clue), 'Invalid signature');

    uint8 clueNum = clueToClueNum[clue];
    state[msg.sender].foundClues[clueNum] = true;

    emit FoundClue(msg.sender, clueNum);
  }

  function findClueVRS(address clue, uint8 v, bytes32 r, bytes32 s) public {
    require(state[msg.sender].staked > 0, 'Must stake');
    require(clueToClueNum[clue] > 0, 'Invalid clue');
    bytes memory prefix = "\x19Ethereum Signed Message:\n32";
    bytes32 hash = keccak256(abi.encodePacked(prefix, addressHash(msg.sender)));

    require(ecrecover(hash, v, r, s) == clue, 'Invalid signature');

    uint8 clueNum = clueToClueNum[clue];
    state[msg.sender].foundClues[clueNum] = true;

    emit FoundClue(msg.sender, clueNum);
  }

  function reverseFind(address user, bytes memory signature) public {
    require(state[user].staked > 0, 'Must stake');
    require(clueToClueNum[msg.sender] > 0);
    require(ECVerify.ecverify(addressHash(user), signature, user), 'Invalid signature');

    uint8 clueNum = clueToClueNum[msg.sender];
    state[user].foundClues[clueNum] = true;

    emit FoundClue(user, clueNum);
  }

  function findCluesAndDonate(address[] memory clues, uint8[] memory vs, bytes32[] memory rs, bytes32[] memory ss, uint amount) public {
    findClues(clues, vs, rs, ss);
    donate(amount);
  }

  function findCluesAndRedeem(address[] memory clues, uint8[] memory vs, bytes32[] memory rs, bytes32[] memory ss) public {
    findClues(clues, vs, rs, ss);
    redeem();
  }

  function donate(uint amount) public {
    require(amount <= remainingStake(msg.sender));
    state[msg.sender].donated = state[msg.sender].donated.add(amount);
    donated = donated.add(amount);
    emit Donation(msg.sender, amount);
  }

  function forceDonate(address user) public onlyOwner {
    require(now - state[user].startTime > 24 hours);
    uint256 amount = remainingStake(user);
    state[msg.sender].donated = state[msg.sender].donated.add(amount);
    donated = donated.add(amount);
  }

  function redeem() public {
    require(didWin(msg.sender));

    uint256 remaining = remainingStake(msg.sender);
    require(remaining > 0);

    stakingToken.transfer(msg.sender, remaining);
  }

  function withdrawDonations() public onlyOwner {
    uint256 amount = donated.sub(withdrawn);
    stakingToken.transfer(owner(), amount);
    withdrawn = donated;
  }
}
