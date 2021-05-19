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

  it('should return some initialized exempts', async function () {
    let reserve = await this.token.getReserve()
    let uniswapv2Router02 = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D'
    expect(await this.token.getExempt(reserve)).to.be.true
    expect(await this.token.getExempt(uniswapv2Router02)).to.be.true
    expect(await this.token.getExempt(creator)).to.be.false
  })

  it('should update and return the reserve account', async function () {
    await this.token.updateReserve(other)
    expect(await this.token.getReserve()).to.be.equal(other)
  })

  it('should update and return the starting taxes', async function () {
    let startingTaxes = [1, 2, 3, 5, 10]
    let tx = await this.token.updateStartingTaxes(startingTaxes)
    await truffleAssert.eventEmitted(tx, 'UpdatedStartingTaxes', (ev) => {
      let taxes = ev.startingTaxes.map(tax => parseInt(tax.toString()))
      let reducedTaxesProduct = taxes.reduce((acc, currentValue) => acc * currentValue)
      let reducedStartingTaxesProduct = startingTaxes.reduce((acc, currentValue) => acc * currentValue)
      return reducedTaxesProduct == reducedStartingTaxesProduct
    })
  })

  it('should add an exempt', async function () {
    let tx = await this.token.addExempt(other)
    await truffleAssert.eventEmitted(tx, 'AddedExempt', (ev) => {
      return ev.exempted == other
    })
  })

  it('should remove an exempt', async function () {
    await this.token.addExempt(other)
    let tx = await this.token.removeExempt(other)
    await truffleAssert.eventEmitted(tx, 'RemovedExempt', (ev) => {
      return ev.exempted == other
    })
  })

  it('should update an exempt', async function () {
    await this.token.addExempt(other)
    let tx = await this.token.updateExempt(other, false)
    await truffleAssert.eventEmitted(tx, 'UpdatedExempt', (ev) => {
      return (
        ev.exempted == other &&
        !ev.isValid
      )
    })
  })

  it('should set a genesis tax record', async function () {
    let tx = await this.token.sandboxSetGenesisTaxRecord(other, 20)
    await truffleAssert.eventEmitted(tx, 'SandboxTaxRecordSet', (ev) => {
      return (
        ev.addr == other &&
        ev.timestamp <= Date.now() &&
        ev.tax == 20
      )
    })
  })

  it('should emit a `GotTax` event with percentageTransferred and taxPercentage', async function () {
    let sentAmount = '500000000000000000000000000'
    let tx = await this.token.transfer(other, sentAmount)

    await truffleAssert.eventEmitted(tx, 'GotTax', (ev) => {
      return (
        ev.taxPercentage < 50 &&
        ev.percentageTransferred < 10
      )
    })
  })

  it('should transfer tokens successfully', async function () {
    let initialBalCreator = await this.token.balanceOf(creator)
    let initialBalOther = await this.token.balanceOf(other)

    let { receipt } = await this.token.transfer(other, 100 * Math.pow(10, 8))

    expect(receipt.transactionHash).to.have.string('0x')
    expect(await this.token.balanceOf(creator)).to.be.bignumber.lessThan(initialBalCreator)
    expect(await this.token.balanceOf(other)).to.be.bignumber.greaterThan(initialBalOther)
  })

  it('should credit the kR after transfer is invoked', async function () {
    let reserveAddr = await this.token.getReserve()
    let initialBalOther = await this.token.balanceOf(other)
    let initialBalCreator = await this.token.balanceOf(creator)
    let initialBalReserveAddr = await this.token.balanceOf(reserveAddr)

    let { receipt } = await this.token.transfer(other, 100 * Math.pow(10, 8))

    expect(receipt.transactionHash).to.have.string('0x')
    expect(await this.token.balanceOf(other)).to.be.bignumber.greaterThan(initialBalOther)
    expect(await this.token.balanceOf(creator)).to.be.bignumber.lessThan(initialBalCreator)
    expect(await this.token.balanceOf(reserveAddr)).to.be.bignumber.greaterThan(initialBalReserveAddr)
  })

  it('should successfully approve the spender `other`', async function () {
    let { tx, receipt } = await this.token.approve(other, 100000000)
    expect(tx).to.have.string('0x')
    expect(receipt.transactionHash).to.have.string('0x')
  })

  it('should grant authority to account `other` to spend from account `creator`', async function () {
    let { receipt: transferReceipt } = await this.token.transfer(other, 100000 * Math.pow(10, 8))

    let allowedAmount = 100000
    let to = '0x73Fc15691e3F3f5322271bbB97d65D7bc456D1A1'
    let reserve = await this.token.getReserve()
    let toBal = await this.token.balanceOf(to)
    let otherBal = await this.token.balanceOf(other)
    let creatorBal = await this.token.balanceOf(creator)
    let reserveBal = await this.token.balanceOf(reserve)

    let { receipt: approvalReceiptOther } = await this.token.approve(
      other,
      allowedAmount,
      {
        from: creator
      }
    )

    let allowedOther = await this.token.allowance(creator, other)

    let { receipt: transferFromReceipt } = await this.token.transferFrom(
      creator,
      to,
      allowedAmount,
      {
        from: other
      }
    )

    let settledCreatorBal = await this.token.balanceOf(creator)

    expect(allowedOther.toNumber()).to.be.equal(allowedAmount) // `allowedOther` is greater due to the applied tax
    expect(approvalReceiptOther.transactionHash).to.have.string('0x')
    expect(transferReceipt.transactionHash).to.have.string('0x')
    expect(transferFromReceipt.transactionHash).to.have.string('0x')
    expect(await this.token.balanceOf(other)).to.be.bignumber.equal(otherBal) // unchanged
    expect(settledCreatorBal).to.be.bignumber.lessThan(creatorBal) // depreciated balance

    expect(settledCreatorBal).to.be.bignumber.lessThan(creatorBal) // depreciated balance

    expect(await this.token.balanceOf(to)).to.be.bignumber.greaterThan(toBal) // appreciated balance
    expect(await this.token.balanceOf(reserve)).to.be.bignumber.greaterThan(reserveBal) // appreciated balance due to paid taxes
  })

  it('should not tax an exempted account ', async function () {
    await this.token.addExempt(creator)

    let reserve = await this.token.getReserve()
    let initialBalCreator = await this.token.balanceOf(creator)
    let initialBalOther = await this.token.balanceOf(other)
    let initialBalReserve = await this.token.balanceOf(reserve)

    let { receipt } = await this.token.transfer(other, 100 * Math.pow(10, 8))

    expect(receipt.transactionHash).to.have.string('0x')
    expect(await this.token.balanceOf(creator)).to.be.bignumber.lessThan(initialBalCreator)
    expect(await this.token.balanceOf(other)).to.be.bignumber.greaterThan(initialBalOther)
    expect(await this.token.balanceOf(reserve)).to.be.bignumber.equal(initialBalReserve)
  })
})
