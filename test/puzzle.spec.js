const Puzzle = artifacts.require("Puzzle");
const SimpleToken = artifacts.require("SimpleToken");

const makeAccounts = numClues => [...Array(numClues).keys()].map(() => web3.eth.accounts.create());


contract('ScavengerHunt', function([creator, player, clueAccount]) {
  let token;
  before(async () => {
    token = await SimpleToken.new({ from: player });
  });

  it("should let user unlock a clue", async function() {
    const clues = makeAccounts(1);
    const puzzle = await Puzzle.new(token.address, clues.map(acc => acc.address), { from: creator });

    await token.approve(puzzle.address, web3.utils.toWei('100', 'ether'), { from: player });
    await puzzle.stake(web3.utils.toWei('1', 'ether'), { from: player });

    const signed = clues[0].sign(web3.utils.keccak256(player));
    const { receipt } = await puzzle.findClue(clues[0].address, signed.signature, { from: player });
    assert.equal(receipt.logs[0].event, 'FoundClue');
  });

  it("should unlock a clue from the clue account", async function () {
    const puzzle = await Puzzle.new(token.address, [clueAccount], { from: creator });

    await token.approve(puzzle.address, web3.utils.toWei('100', 'ether'), { from: player });
    await puzzle.stake(web3.utils.toWei('1', 'ether'), { from: player });

    const signature = await web3.eth.sign(web3.utils.keccak256(player), player);
    const { receipt } = await puzzle.reverseFind(player, signature, { from: clueAccount });
    assert.equal(receipt.logs[0].event, 'FoundClue');
  });

  it("should let a user pay for a hint", async function () {
    const puzzle = await Puzzle.new(token.address, [clueAccount], { from: creator });

    await token.approve(puzzle.address, web3.utils.toWei('100', 'ether'), { from: player });
    await puzzle.stake(web3.utils.toWei('2', 'ether'), { from: player });

    const { receipt } = await puzzle.donate(web3.utils.toWei('1', 'ether'), { from: player });
    assert.equal(receipt.logs[0].event, 'Donation');

    assert.equal(await puzzle.remainingStake(player), web3.utils.toWei('1', 'ether'));
  });

  it("should let the owner withdraw donations", async function () {
    const puzzle = await Puzzle.new(token.address, [clueAccount], { from: creator });

    await token.approve(puzzle.address, web3.utils.toWei('100', 'ether'), { from: player });
    await puzzle.stake(web3.utils.toWei('1', 'ether'), { from: player });

    await puzzle.donate(web3.utils.toWei('1', 'ether'), { from: player });

    await puzzle.withdrawDonations({ from: creator });
    assert.equal(await token.balanceOf(creator), web3.utils.toWei('1', 'ether'));

  });

  it("should let a winning team claim their stake", async function () {
    const clues = makeAccounts(1);
    const puzzle = await Puzzle.new(token.address, clues.map(acc => acc.address), { from: creator });

    const startingBalance = await token.balanceOf(player);

    await token.approve(puzzle.address, web3.utils.toWei('100', 'ether'), { from: player });
    await puzzle.stake(web3.utils.toWei('1', 'ether'), { from: player });

    const signed = clues[0].sign(web3.utils.keccak256(player));
    await puzzle.findClue(clues[0].address, signed.signature, { from: player });

    const { receipt } = await puzzle.redeem({ from: player });
    
    assert.equal(startingBalance.toString(), await token.balanceOf(player));
  });
});
