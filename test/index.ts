import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { beforeEach, describe, it } from "mocha";
import { MockERC20, MockIdleCDO, TrancheWrapper } from "../typechain";

describe("Tranche", function () {
  let admin: SignerWithAddress;
  let addr1: SignerWithAddress;
  let addr2: SignerWithAddress;
  let addrs: SignerWithAddress[];
  let addr3: SignerWithAddress;
  let IdleCDO: MockIdleCDO;
  let token: MockERC20;
  let AATranche: TrancheWrapper;
  let BBTranche: TrancheWrapper;

  beforeEach("deploy", async () => {
    [admin, addr1, addr2, addr3, ...addrs] = await ethers.getSigners();
    const Token = await ethers.getContractFactory("MockERC20");
    token = await Token.deploy("mock token", "MT");
    await token.deployed();

    await (await token.mint(addr1.address, 10000)).wait();
    await (await token.mint(addr2.address, 10000)).wait();
    await (await token.mint(addr3.address, 10000)).wait();

    const IdleCDOF = await ethers.getContractFactory("MockIdleCDO");
    IdleCDO = await IdleCDOF.deploy(token.address);
    await IdleCDO.deployed();

    AATranche = await ethers.getContractAt(
      "TrancheWrapper",
      await IdleCDO.AATranche()
    );
    BBTranche = await ethers.getContractAt(
      "TrancheWrapper",
      await IdleCDO.BBTranche()
    );

    await (await token.connect(addr1).approve(IdleCDO.address, 10000)).wait();
    await (await token.connect(addr2).approve(IdleCDO.address, 10000)).wait();
    await (await token.connect(addr3).approve(IdleCDO.address, 10000)).wait();

    await (await token.connect(addr1).approve(AATranche.address, 10000)).wait();
    await (await token.connect(addr2).approve(AATranche.address, 10000)).wait();
    await (await token.connect(addr3).approve(AATranche.address, 10000)).wait();

    await (
      await AATranche.connect(addr1).approve(AATranche.address, 10000)
    ).wait();
    await (
      await AATranche.connect(addr2).approve(AATranche.address, 10000)
    ).wait();
    await (
      await AATranche.connect(addr3).approve(AATranche.address, 10000)
    ).wait();

    await (await token.connect(addr1).approve(BBTranche.address, 10000)).wait();
    await (await token.connect(addr2).approve(BBTranche.address, 10000)).wait();
    await (await token.connect(addr3).approve(BBTranche.address, 10000)).wait();

    await (
      await BBTranche.connect(addr1).approve(BBTranche.address, 10000)
    ).wait();
    await (
      await BBTranche.connect(addr2).approve(BBTranche.address, 10000)
    ).wait();
    await (
      await BBTranche.connect(addr3).approve(BBTranche.address, 10000)
    ).wait();
  });

  it("depositAA to IdleCDO", async function () {
    let beforeAAbal = await AATranche.balanceOf(addr1.address);
    let beforetokenbal = await token.balanceOf(addr1.address);
    await (await IdleCDO.connect(addr1).depositAA(10000)).wait();
    let afterAAbal = await AATranche.balanceOf(addr1.address);
    let aftertokenbal = await token.balanceOf(addr1.address);
    expect(afterAAbal).to.be.eq(beforeAAbal.add(10000));
    expect(aftertokenbal).to.be.eq(beforetokenbal.sub(10000));
  });

  it("withdrawAA from IdleCDO", async () => {
    await (await IdleCDO.connect(addr1).depositAA(10000)).wait();
    let beforeAAbal = await AATranche.balanceOf(addr1.address);
    let beforetokenbal = await token.balanceOf(addr1.address);
    await (await IdleCDO.connect(addr1).withdrawAA(10000)).wait();
    let afterAAbal = await AATranche.balanceOf(addr1.address);
    let aftertokenbal = await token.balanceOf(addr1.address);
    expect(afterAAbal).to.be.eq(beforeAAbal.sub(10000));
    expect(aftertokenbal).to.be.eq(beforetokenbal.add(10000));
  });

  it("depositAA to AATranche", async () => {
    let beforeAAbal = await AATranche.balanceOf(addr1.address);
    let beforetokenbal = await token.balanceOf(addr1.address);
    await (await AATranche.connect(addr1).deposit(10000, addr1.address)).wait();
    let afterAAbal = await AATranche.balanceOf(addr1.address);
    let aftertokenbal = await token.balanceOf(addr1.address);
    expect(afterAAbal).to.be.eq(beforeAAbal.add(10000));
    expect(aftertokenbal).to.be.eq(beforetokenbal.sub(10000));
  });

  it("withdrawAA from AATranche", async () => {
    await (await AATranche.connect(addr1).deposit(10000, addr1.address)).wait();
    let beforeAAbal = await AATranche.balanceOf(addr1.address);
    let beforetokenbal = await token.balanceOf(addr1.address);
    await (
      await AATranche.connect(addr1).withdraw(
        10000,
        addr1.address,
        addr1.address
      )
    ).wait();
    let afterAAbal = await AATranche.balanceOf(addr1.address);
    let aftertokenbal = await token.balanceOf(addr1.address);
    expect(afterAAbal).to.be.eq(beforeAAbal.sub(10000));
    expect(aftertokenbal).to.be.eq(beforetokenbal.add(10000));
  });

  it("mint from AATranche", async () => {
    let beforeAAbal = await AATranche.balanceOf(addr1.address);
    let beforetokenbal = await token.balanceOf(addr1.address);
    // await(await AATranche.connect(addr1).mint(10000, addr1.address)).wait();
    await (
      await AATranche.connect(addr1)["mint(uint256,address)"](
        10000,
        addr1.address
      )
    ).wait();
    let afterAAbal = await AATranche.balanceOf(addr1.address);
    let aftertokenbal = await token.balanceOf(addr1.address);
    expect(afterAAbal).to.be.eq(beforeAAbal.add(10000));
    expect(aftertokenbal).to.be.eq(beforetokenbal.sub(10000));
  });

  it("redeem from AATranche", async () => {
    await (
      await AATranche.connect(addr1)["mint(uint256,address)"](
        10000,
        addr1.address
      )
    ).wait();
    let beforeAAbal = await AATranche.balanceOf(addr1.address);
    let beforetokenbal = await token.balanceOf(addr1.address);
    await (
      await AATranche.connect(addr1).redeem(10000, addr1.address, addr1.address)
    ).wait();
    let afterAAbal = await AATranche.balanceOf(addr1.address);
    let aftertokenbal = await token.balanceOf(addr1.address);
    expect(afterAAbal).to.be.eq(beforeAAbal.sub(10000));
    expect(aftertokenbal).to.be.eq(beforetokenbal.add(10000));
  });
});
