import { ethers, upgrades } from 'hardhat'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { AddressZero } from '@ethersproject/constants'
import { expect } from './utils/setup'
import { NON_ZERO_ADDRESS } from './utils/constants'
import { ERROR_STRINGS } from './utils/errors'
import { L2ECO } from '../typechain-types/contracts/token/L2ECO'

describe('L2ECO tests', () => {
  let alice: SignerWithAddress
  let bob: SignerWithAddress
  let l2BridgeImpersonator: SignerWithAddress
  let eco: L2ECO

  const baseInflationMult = 10

  beforeEach(async () => {
    ;[alice, bob, l2BridgeImpersonator] = await ethers.getSigners()
    const ecoFactory = await ethers.getContractFactory('L2ECO')
    eco = (await upgrades.deployProxy(
      ecoFactory,
      [AddressZero, l2BridgeImpersonator.address],
      {
        initializer: 'initialize',
      }
    )) as L2ECO
    await eco.deployed()
    // set rebase to 10 so our numbers arent crazy big
    await eco.connect(l2BridgeImpersonator).rebase(baseInflationMult)
  })

  // test initialize reverting
  describe('initialize', () => {
    it('Should only be callable once', async () => {
      await expect(
        eco.initialize(AddressZero, NON_ZERO_ADDRESS)
      ).to.be.revertedWith(ERROR_STRINGS.UPGRADES.ALREADY_INITIALIZED)
    })
  })

  describe('optimism standards', () => {
    it('should return the correct interface support', async () => {
      // ERC165
      expect(await eco.supportsInterface('0x01ffc9a7')).to.be.true

      // L2StandardERC20
      expect(await eco.supportsInterface('0x1d1d8b63')).to.be.true

      expect(await eco.supportsInterface('0xffffffff')).to.be.false
    })
  })

  describe('minting', () => {
    const mintAmount = 1000

    it('reverts if unauthed', async () => {
      await expect(
        eco.connect(alice).mint(alice.address, mintAmount)
      ).to.be.revertedWith(ERROR_STRINGS.L2ECO.UNAUTHORIZED_MINTER)
    })

    it('increases balance', async () => {
      expect(await eco.balanceOf(alice.address)).to.equal(0)
      await expect(
        eco.connect(l2BridgeImpersonator).mint(alice.address, mintAmount)
      )
        .to.emit(eco, 'Transfer')
        .withArgs(AddressZero, alice.address, mintAmount)

      expect(await eco.balanceOf(alice.address)).to.equal(mintAmount)
    })
  })

  describe('burning', () => {
    const burnAmount = 1000

    it('reverts if unauthed', async () => {
      await expect(
        eco.connect(bob).burn(alice.address, burnAmount)
      ).to.be.revertedWith(ERROR_STRINGS.L2ECO.UNAUTHORIZED_BURNER)
    })

    describe('decreases balance', () => {
      beforeEach(async () => {
        await eco.connect(l2BridgeImpersonator).mint(alice.address, burnAmount)
        expect(await eco.balanceOf(alice.address)).to.eq(burnAmount)
      })

      it('on self call', async () => {
        await eco.connect(alice).burn(alice.address, burnAmount)
        expect(await eco.balanceOf(alice.address)).to.eq(0)
      })

      it('on admin call', async () => {
        await eco.connect(l2BridgeImpersonator).burn(alice.address, burnAmount)
        expect(await eco.balanceOf(alice.address)).to.eq(0)
      })
    })
  })

  describe('rebasing', () => {
    const newInflationMult = 2
    const newInflationScale = baseInflationMult / newInflationMult

    it('reverts if unauthed', async () => {
      await expect(
        eco.connect(bob).rebase(newInflationMult)
      ).to.be.revertedWith(ERROR_STRINGS.L2ECO.UNAUTHORIZED_REBASER)
    })

    describe('on rebase', () => {
      const aliceBalance = 1000

      beforeEach(async () => {
        await eco
          .connect(l2BridgeImpersonator)
          .mint(alice.address, aliceBalance)
        expect(await eco.balanceOf(alice.address)).to.eq(aliceBalance)
      })

      it('emits an event', async () => {
        await expect(eco.connect(l2BridgeImpersonator).rebase(newInflationMult))
          .to.emit(eco, 'NewInflationMultiplier')
          .withArgs(newInflationMult)
      })

      it('changes balance', async () => {
        expect(await eco.balanceOf(alice.address)).to.eq(aliceBalance)
        await eco.connect(l2BridgeImpersonator).rebase(newInflationMult)

        expect(await eco.balanceOf(alice.address)).to.eq(
          newInflationScale * aliceBalance
        )
      })
    })
  })

  describe('transfers', () => {
    const initialAliceBalance = 1000

    beforeEach(async () => {
      await eco
        .connect(l2BridgeImpersonator)
        .mint(alice.address, initialAliceBalance)
      expect(await eco.balanceOf(alice.address)).to.eq(initialAliceBalance)
    })

    it('emits base value event', async () => {
      await expect(
        eco.connect(alice).transfer(bob.address, initialAliceBalance)
      )
        .to.emit(eco, 'BaseValueTransfer')
        .withArgs(
          alice.address,
          bob.address,
          initialAliceBalance * baseInflationMult
        )
    })
  })

  // test role logic
  describe('role management', () => {
    describe('reverts', () => {
      it('reverts on unauthed minter change', async () => {
        await expect(eco.updateMinters(alice.address, true)).to.be.revertedWith(
          ERROR_STRINGS.L2ECO.UNAUTHORIZED_TOKEN_ROLE_ADMIN
        )
      })

      it('reverts on unauthed burner change', async () => {
        await expect(eco.updateBurners(alice.address, true)).to.be.revertedWith(
          ERROR_STRINGS.L2ECO.UNAUTHORIZED_TOKEN_ROLE_ADMIN
        )
      })

      it('reverts on unauthed rebaser change', async () => {
        await expect(
          eco.updateRebasers(alice.address, true)
        ).to.be.revertedWith(ERROR_STRINGS.L2ECO.UNAUTHORIZED_TOKEN_ROLE_ADMIN)
      })

      it('reverts on unauthed role admin change', async () => {
        await expect(
          eco.updateTokenRoleAdmin(alice.address)
        ).to.be.revertedWith(ERROR_STRINGS.L2ECO.UNAUTHORIZED_TOKEN_ROLE_ADMIN)
      })
    })

    describe('minting', () => {
      const mintAmount = 1000

      it('can add permission', async () => {
        expect(await eco.balanceOf(alice.address)).to.eq(0)

        await expect(
          eco.connect(alice).mint(alice.address, mintAmount)
        ).to.be.revertedWith(ERROR_STRINGS.L2ECO.UNAUTHORIZED_MINTER)

        await eco
          .connect(l2BridgeImpersonator)
          .updateMinters(alice.address, true)

        await eco.connect(alice).mint(alice.address, mintAmount)
        expect(await eco.balanceOf(alice.address)).to.eq(mintAmount)
      })

      it('can remove permission', async () => {
        expect(await eco.balanceOf(alice.address)).to.eq(0)
        await eco.connect(l2BridgeImpersonator).mint(alice.address, mintAmount)
        expect(await eco.balanceOf(alice.address)).to.eq(mintAmount)

        await eco
          .connect(l2BridgeImpersonator)
          .updateMinters(l2BridgeImpersonator.address, false)

        await expect(
          eco.connect(l2BridgeImpersonator).mint(alice.address, mintAmount)
        ).to.be.revertedWith(ERROR_STRINGS.L2ECO.UNAUTHORIZED_MINTER)
      })
    })

    describe('burning', () => {
      const burnAmount = 1000

      beforeEach(async () => {
        await eco.connect(l2BridgeImpersonator).mint(alice.address, burnAmount)
        expect(await eco.balanceOf(alice.address)).to.eq(burnAmount)
      })

      it('can add permission', async () => {
        await expect(
          eco.connect(bob).burn(alice.address, burnAmount)
        ).to.be.revertedWith(ERROR_STRINGS.L2ECO.UNAUTHORIZED_BURNER)

        await eco.connect(l2BridgeImpersonator).updateBurners(bob.address, true)

        await eco.connect(bob).burn(alice.address, burnAmount)
        expect(await eco.balanceOf(alice.address)).to.eq(0)
      })

      it('can remove permission', async () => {
        await eco.connect(l2BridgeImpersonator).mint(alice.address, burnAmount)
        expect(await eco.balanceOf(alice.address)).to.eq(2 * burnAmount)
        await eco.connect(l2BridgeImpersonator).burn(alice.address, burnAmount)
        expect(await eco.balanceOf(alice.address)).to.eq(burnAmount)

        await eco
          .connect(l2BridgeImpersonator)
          .updateBurners(l2BridgeImpersonator.address, false)

        await expect(
          eco.connect(l2BridgeImpersonator).burn(alice.address, burnAmount)
        ).to.be.revertedWith(ERROR_STRINGS.L2ECO.UNAUTHORIZED_BURNER)
      })
    })

    describe('rebasing', () => {
      const newInflationMult = 2
      const newInflationScale = baseInflationMult / newInflationMult
      const aliceBalance = 1000

      beforeEach(async () => {
        await eco
          .connect(l2BridgeImpersonator)
          .mint(alice.address, aliceBalance)
        expect(await eco.balanceOf(alice.address)).to.eq(aliceBalance)
      })

      it('can add permission', async () => {
        await expect(
          eco.connect(alice).rebase(newInflationMult)
        ).to.be.revertedWith(ERROR_STRINGS.L2ECO.UNAUTHORIZED_REBASER)

        await eco
          .connect(l2BridgeImpersonator)
          .updateRebasers(alice.address, true)

        await eco.connect(alice).rebase(newInflationMult)
        expect(await eco.balanceOf(alice.address)).to.eq(
          newInflationScale * aliceBalance
        )
      })

      it('can remove permission', async () => {
        await eco.connect(l2BridgeImpersonator).rebase(newInflationMult)
        expect(await eco.balanceOf(alice.address)).to.eq(
          newInflationScale * aliceBalance
        )

        await eco
          .connect(l2BridgeImpersonator)
          .updateRebasers(l2BridgeImpersonator.address, false)

        await expect(
          eco.connect(l2BridgeImpersonator).rebase(newInflationMult)
        ).to.be.revertedWith(ERROR_STRINGS.L2ECO.UNAUTHORIZED_REBASER)
      })
    })

    describe('admin', () => {
      it('can change admin', async () => {
        // can edit roles
        await eco
          .connect(l2BridgeImpersonator)
          .updateMinters(alice.address, true)

        await eco
          .connect(l2BridgeImpersonator)
          .updateTokenRoleAdmin(alice.address)

        // can no longer edit roles
        await expect(
          eco.connect(l2BridgeImpersonator).updateMinters(alice.address, false)
        ).to.be.revertedWith(ERROR_STRINGS.L2ECO.UNAUTHORIZED_TOKEN_ROLE_ADMIN)
      })
    })
  })
})
