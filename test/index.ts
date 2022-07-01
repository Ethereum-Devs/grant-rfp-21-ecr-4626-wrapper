import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers } from "hardhat";
import * as helpers from "@nomicfoundation/hardhat-network-helpers";
import { ERC20, IIdleCDO, TrancheWrapper } from "../typechain";

describe("tranche wrapper", function () {
  const IdleCDOAddress = "0xd0DbcD556cA22d3f3c142e9a3220053FD7a247BC";
  const DaiHolderAddress = "0x4967EC98748EFB98490663A65b16698069A1Eb35";

  let signers: SignerWithAddress[];
  let DaiHolder: SignerWithAddress;
  let TrancheWrapperAA: TrancheWrapper;
  let TrancheWrapperBB: TrancheWrapper;
  let Dai: ERC20;
  let TranchAA: ERC20;
  let TranchBB: ERC20;
  let IdleCDO: IIdleCDO;

  beforeEach("deploy tranche", async () => {
    signers = await ethers.getSigners();
    IdleCDO = await ethers.getContractAt("IIdleCDO", IdleCDOAddress);
    Dai = await ethers.getContractAt("ERC20", await IdleCDO.token());
    TranchAA = await ethers.getContractAt("ERC20", await IdleCDO.AATranche());
    TranchBB = await ethers.getContractAt("ERC20", await IdleCDO.BBTranche());
    const AATrancheAddress = await IdleCDO.AATranche();
    const BBTrancheAddress = await IdleCDO.BBTranche();
    const TrancheWrapperFactory = await ethers.getContractFactory(
      "TrancheWrapper"
    );
    TrancheWrapperAA = await TrancheWrapperFactory.deploy(
      "IdleCDO Dai trancheAA wrapper",
      "DaiAA",
      IdleCDOAddress,
      AATrancheAddress
    );
    await TrancheWrapperAA.deployed();
    TrancheWrapperBB = await TrancheWrapperFactory.deploy(
      "IdleCDO Dai trancheBB wrapper",
      "DaiBB",
      IdleCDOAddress,
      BBTrancheAddress
    );
    await TrancheWrapperBB.deployed();
    // console.log(
    //   "TrancheWrapperAA, BB = ",
    //   TrancheWrapperAA.address,
    //   TrancheWrapperBB.address
    // );
    await helpers.impersonateAccount(DaiHolderAddress);
    DaiHolder = await ethers.getSigner(DaiHolderAddress);
  });

  it("deposit()", async () => {
    // await setBalance(DaiHolderAddress, ethers.utils.parseEther("100"));
    await (
      await Dai.connect(DaiHolder).approve(
        TrancheWrapperAA.address,
        ethers.utils.parseEther("10")
      )
    ).wait();
    let _IdleCDODaiBal = await Dai.balanceOf(IdleCDO.address);
    let _WrapperAABal = await TranchAA.balanceOf(TrancheWrapperAA.address);
    let _holderAAWapperBal = await TrancheWrapperAA.balanceOf(
      signers[0].address
    );
    let _DaiHolerDaiBal = await Dai.balanceOf(IdleCDO.address);
    let tranchePrice = await IdleCDO.tranchePrice(TranchAA.address);
    let virtualPrice = await IdleCDO.virtualPrice(TranchAA.address);
    console.log("t, v = ", tranchePrice.toString(), virtualPrice.toString());
    await (
      await TrancheWrapperAA.connect(DaiHolder).deposit(
        ethers.utils.parseEther("10"),
        signers[0].address
      )
    ).wait();
    let IdleCDODaiBal = await Dai.balanceOf(IdleCDO.address);
    let WrapperAABal = await TranchAA.balanceOf(TrancheWrapperAA.address);
    let holderAAWapperBal = await TrancheWrapperAA.balanceOf(
      signers[0].address
    );
    let DaiHolerDaiBal = await Dai.balanceOf(IdleCDO.address);
    expect(IdleCDODaiBal).to.be.eq(
      _IdleCDODaiBal.add(ethers.utils.parseEther("10"))
    );
    expect(DaiHolerDaiBal).to.be.eq(
      _DaiHolerDaiBal.add(ethers.utils.parseEther("10"))
    );
    expect(holderAAWapperBal).to.be.eq(_holderAAWapperBal.add(WrapperAABal));
    console.log("AA bal = ", WrapperAABal.toString());
  });

  it("withdraw()", async () => {
    await (
      await Dai.connect(DaiHolder).approve(
        TrancheWrapperAA.address,
        ethers.utils.parseEther("10")
      )
    ).wait();
    await (
      await TrancheWrapperAA.connect(DaiHolder).deposit(
        ethers.utils.parseEther("10"),
        signers[0].address
      )
    ).wait();
    await (
      await TrancheWrapperAA.connect(signers[0]).withdraw(
        ethers.utils.parseEther("10"),
        signers[0].address,
        signers[0].address
      )
    ).wait();
  });
});
