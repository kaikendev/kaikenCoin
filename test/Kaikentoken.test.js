// SPDX-License-Identifier: MIT

// Based on https://github.com/OpenZeppelin/openzeppelin-solidity/blob/v2.5.1/test/examples/Kaiken.test.js

const { expect } = require('chai')
const truffleAssert = require('truffle-assertions')

// Import utilities from Test Helpers
const { BN } = require('@openzeppelin/test-helpers')

// Load compiled artifacts
const KaikenToken = artifacts.require('KaikenToken')

// Start test block
contract('KaikenToken', async function ([creator, other]) {
  const NAME = 'Kaiken Coin'
  const SYMBOL = 'KAIKEN'
  const TOTAL_SUPPLY = new BN('100000000000000000000000000000')

  beforeEach(async function () {
    this.token = await KaikenToken.new(NAME, SYMBOL, { from: creator })
  })

  it('retrieve returns a value previously stored', async function () {
    // Use large integer comparisons
    expect(await this.token.totalSupply()).to.be.bignumber.equal(TOTAL_SUPPLY)
  })

  it('has a name', async function () {
    expect(await this.token.name()).to.be.equal(NAME)
  })

  it('has a symbol', async function () {
    expect(await this.token.symbol()).to.be.equal(SYMBOL)
  })

  it('assigns the initial total supply to the creator', async function () {
    expect(await this.token.balanceOf(creator)).to.be.bignumber.equal(TOTAL_SUPPLY)
  })

  it('should return the token balance of an address', async function () {
    expect(await this.token.getBalance(creator)).to.be.bignumber.equal(TOTAL_SUPPLY)
  })

  it('should fail in an attempt to return the taxPercentage since amount is zero', async function () {
    await truffleAssert.fails(
      this.token._getTaxPercentage(creator, 0),
      truffleAssert.ErrorType.REVERT
    )
  })

  it('should not fail in an attempt to return the taxPercentage since amount is tangible', async function () {
    await truffleAssert.passes(
      this.token._getTaxPercentage(creator, 10000)
    )
  })

  it('should emit an event with percentageTransferred and taxPercentage', async function () {
    let sentAmount = 10000
    let tx = await this.token._getTaxPercentage(creator, sentAmount)

    await truffleAssert.eventEmitted(tx, 'GotTax', (ev) => {
      return (
        ev.taxPercentage == 8 &&
        ev.percentageTransferred < 5
      )
    })
  })

  it('creator balance should equal balance from emitted event before transfer', async function () {
    let sentAmount = 100000000
    let creatorBalance = await this.token.getBalance(creator)

    let tx = await this.token._getTaxPercentage(
      creator,
      sentAmount
    )

    await truffleAssert.eventEmitted(tx, 'GotTax', (ev) => {
      return ev.balanceOfSender.toString() == creatorBalance.toString()
    })
  })

  it('should have the correct tax applied to an amount potentially sent ', async function () {
    let sentAmount = '50000000000000000000000000000'
    let creatorBalance = await this.token.getBalance(creator)
    let tx = await this.token._getTaxPercentage(creator, sentAmount)

    await truffleAssert.eventEmitted(tx, 'GotTax', (ev) => {
      return (
        ev.taxPercentage == 40 &&
        ev.percentageTransferred == (sentAmount * 100) / creatorBalance
      )
    })
  })

  it('should apply a 90% tax to an amount that is potentially sent ', async function () {
    let sentAmount = '80000000000000000000000000000'
    let tx = await this.token._getTaxPercentage(creator, sentAmount)

    await truffleAssert.eventEmitted(tx, 'GotTax', (ev) => {
      return (
        ev.taxPercentage == 90 &&
        ev.percentageTransferred > 50
      )
    })
  })

  it('should transfer tokens successfully', async function () {
    let initialBalCreator = await this.token.getBalance(creator)
    let initialBalOther = await this.token.getBalance(other)

    let obj = await this.token.transfer(other, 1000)

    expect(obj).to.have.any.keys('tx', 'receipts')
    expect(obj.tx).to.have.string('0x')
    expect(obj.receipt.transactionHash).to.have.string('0x')
    expect(await this.token.getBalance(creator)).to.be.bignumber.lessThan(initialBalCreator)
    expect(await this.token.getBalance(other)).to.be.bignumber.greaterThan(initialBalOther)
  })

  it('should not credit the KAIKEN reserve after transfer is invoked', async function () {
    let reserveAddr = await this.token.getReserveAddress()
    let initialBalOther = await this.token.getBalance(other)
    let initialBalCreator = await this.token.getBalance(creator)
    let initialBalReserveAddr = await this.token.getBalance(reserveAddr)

    let obj = await this.token.transfer(other, 1000)

    expect(obj).to.have.any.keys('tx', 'receipts')
    expect(obj.receipt.transactionHash).to.have.string('0x')
    expect(await this.token.getBalance(other)).to.be.bignumber.greaterThan(initialBalOther)
    expect(await this.token.getBalance(creator)).to.be.bignumber.lessThan(initialBalCreator)
    expect(await this.token.getBalance(reserveAddr)).to.be.bignumber.equal(initialBalReserveAddr)
  })

  it('should successfully approve the spender `other`', async function () {
    let { tx, receipt } = await this.token.approve(other, 1000)
    expect(tx).to.have.string('0x')
    expect(receipt.transactionHash).to.have.string('0x')
  })

  it('should grant authority to account `other` to spend from account `creator`', async function () {
    let allowedAmount = 100000
    let to = '0x4cbbA18De7DEEBbb370B360932b64767626CEBfD'
    let reserve = await this.token.getReserveAddress()

    let toBal = await this.token.getBalance(to)
    let otherBal = await this.token.getBalance(other)
    let creatorBal = await this.token.getBalance(creator)
    let reserveBal = await this.token.getBalance(reserve)

    let { receipt: approvalReceiptOther } = await this.token.approve(other, allowedAmount)

    let allowedOther = await this.token.allowance(creator, other)

    let { receipt: transferFromReceipt } = await this.token.transferFrom(
      creator,
      to,
      allowedAmount,
      {
        from: other
      }
    )

    expect(allowedOther.toNumber()).to.be.greaterThan(allowedAmount) // `allowedOther` is greater due to the applied tax
    expect(approvalReceiptOther.transactionHash).to.have.string('0x')
    expect(transferFromReceipt.transactionHash).to.have.string('0x')
    expect(await this.token.getBalance(other)).to.be.bignumber.equal(otherBal) // unchanged
    expect(await this.token.getBalance(creator)).to.be.bignumber.lessThan(creatorBal) // depreciated balance
    expect(await this.token.getBalance(to)).to.be.bignumber.greaterThan(toBal) // appreciated balance
    expect(await this.token.getBalance(reserve)).to.be.bignumber.greaterThan(reserveBal) // appreciated balance
  })
})
