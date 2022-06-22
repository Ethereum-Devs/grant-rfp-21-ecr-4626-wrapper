import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { Contract, Signer } from "ethers";
import { ethers, upgrades } from "hardhat";
import { beforeEach, describe, it } from "mocha";
import { MockERC20 } from "../typechain";

describe("Tranche wrapper", function () {
  let admin: SignerWithAddress;
  let addr1: SignerWithAddress;
  let addr2: SignerWithAddress;
  let addr3: SignerWithAddress;
  let addrs: SignerWithAddress[];
  let IdleCDO: Contract;
  let token: MockERC20;

  beforeEach("deploy", async () => {
    [admin, addr1, addr2, addr3, ...addrs] = await ethers.getSigners();
    const Token = await ethers.getContractFactory("MockERC20");
    token = await Token.deploy("mock token", "MT");
    await token.deployed();

    await (await token.mint(addr1.address, 10000)).wait();
    await (await token.mint(addr2.address, 10000)).wait();
    await (await token.mint(addr3.address, 10000)).wait();

    const IdleCDOF = await ethers.getContractFactory("MockIdleCDO");
    const params = ["uri", token.address];
    IdleCDO = await upgrades.deployProxy(IdleCDOF, params);
    await IdleCDO.deployed();
  });

  it("deploy success with 2 vaults", async function () {
    const total = await IdleCDO.totalSupply();
    expect(total.toNumber()).to.be.eq(2);
    const vaultAA = await IdleCDO.vaults(1);
    expect(vaultAA.asset).to.be.eq(token.address);
    const vaultBB = await IdleCDO.vaults(2);
    expect(vaultBB.asset).to.be.eq(token.address);
  });

  it("depositAA", async () => {
    await (await token.connect(addr1).approve(IdleCDO.address, 10000)).wait();
    await (await IdleCDO.connect(addr1).depositAA(10000)).wait();
    let addr1Bal = await IdleCDO.balanceOf(addr1.address, 1);
    expect(addr1Bal.toNumber()).to.be.eq(10000);
  });

  it("withdrawAA", async () => {
    await (await token.connect(addr1).approve(IdleCDO.address, 10000)).wait();
    await (await IdleCDO.connect(addr1).depositAA(10000)).wait();
    let addr1Bal = await IdleCDO.balanceOf(addr1.address, 1);
    expect(addr1Bal.toNumber()).to.be.eq(10000);
    await (await IdleCDO.connect(addr1).withdrawAA(10000)).wait();
    addr1Bal = await IdleCDO.balanceOf(addr1.address, 1);
    expect(addr1Bal.toNumber()).to.be.eq(0);
    let tokenbal = await token.balanceOf(addr1.address);
    expect(tokenbal.toNumber()).to.be.eq(10000);
  });

  it("depositAA and depositBB", async () => {
    await (await token.connect(addr1).approve(IdleCDO.address, 10000)).wait();
    await (await IdleCDO.connect(addr1).depositAA(10000)).wait();
    let addr1Bal = await IdleCDO.balanceOf(addr1.address, 1);
    expect(addr1Bal.toNumber()).to.be.eq(10000);
    await (await token.connect(addr2).approve(IdleCDO.address, 10000)).wait();
    await (await IdleCDO.connect(addr2).depositBB(10000)).wait();
    let addr2Bal = await IdleCDO.balanceOf(addr2.address, 2);
    expect(addr2Bal.toNumber()).to.be.eq(10000);
    await (await token.connect(addr3).approve(IdleCDO.address, 10000)).wait();
    await (await IdleCDO.connect(addr3).depositAA(10000)).wait();
    let addr3Bal = await IdleCDO.balanceOf(addr3.address, 1);
    expect(addr3Bal.toNumber()).to.be.eq(5000);
  });
});
