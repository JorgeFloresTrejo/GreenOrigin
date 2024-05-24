const { expect } = require("chai");
const { ethers } = require("hardhat");
const { constants } = require("@openzeppelin/test-helpers"); 

describe("GreenOrigin", function () {

  let transparency; // donde estará la instancia del contrato
  let farmer, processor, exporter, operatorEU, customer;

  // Antes de que se ejecuten todos los Test se ejecuta el before
  before(async function () {
    const greenOriginContract = await ethers.getContractFactory("GreenOrigin"); // Obtener el contrato
    transparency = await greenOriginContract.deploy();
    await transparency.waitForDeployment();
    
    [farmer, processor, exporter, operatorEU, customer] = await ethers.getSigners(); // con getSigners utilizo las cuentas que hardhat proporciona
    console.log("Farmer address: ", farmer.address);
    console.log("processor address: ", processor.address);
    console.log("exporter address: ", exporter.address);
    console.log("operatorEU address: ", operatorEU.address);
    console.log("customer address: ", customer.address);
    // console.log(Object.keys(transparency));
  });


  it("Farmer register", async function () {
    const regDate = Date.now();
    await transparency.registerUser(
      farmer.address,
      "Juan",
      "El salvador",
      regDate,
      0
    );

    const user = await transparency.getUserData(farmer.address);
    expect(user[0]).to.equal("Juan");
    expect(user[1]).to.equal("El salvador");
    expect(user[2]).to.equal(regDate.toString()); 
    expect(user[3]).to.equal(0);
  });

  it("proccesor register", async function () {
    const regDate = Date.now();
    await transparency.registerUser(
      processor.address,
      "Jorge",
      "El salvador",
      regDate,
      1
    );

  });

  it("Farmer mint", async function () {
    await transparency.connect(farmer).mint(
      0,
      1234,
      100,
      "Café",
      "Kgs"
    );

    await transparency.connect(farmer).mint(
      0,
      12345,
      200,
      "cacao",
      "Kgs"
    );

    var attr = await transparency.getTokenAttrs(1234);
    expect(attr[0]).to.equal(farmer.address);
    expect(attr[1]).to.equal(constants.ZERO_ADDRESS);
    expect(attr[2]).to.equal(100);
    expect(attr[3]).to.equal("Café");
    expect(attr[4]).to.equal("Kgs");
    expect(attr[5]).to.equal(0);

    var attr2 = await transparency.getTokenAttrs(12345);
    expect(attr2[0]).to.equal(farmer.address);
    expect(attr2[1]).to.equal(constants.ZERO_ADDRESS);
    expect(attr2[2]).to.equal(200);
    expect(attr2[3]).to.equal("cacao");
    expect(attr2[4]).to.equal("Kgs");
    expect(attr2[5]).to.equal(0);
  });

  it("Tranfer token from farmer to Processor", async function () {
    // console.log(await transparency.connect(farmer).getTokenIds());
    expect(await transparency.ownerOf(1234)).to.equal(farmer.address);
    await transparency.connect(farmer).transferToProcessor(processor.address, 1234);
    expect(await transparency.ownerOf(1234)).to.equal(processor.address);
    // console.log(await transparency.connect(farmer).getTokenIds());
  });

  it("Processor accepts token", async function () {

    await transparency.connect(processor).accept(1234);
    var attr = await transparency.getTokenAttrs(1234);
    expect(attr[5]).to.equal(2); 

  });

  it("Processor mint", async function () {

    var tokens = await transparency.connect(processor).getTokenIds();
    console.log("Token IDs:", tokens); 
    expect(tokens[0]).to.equal(1234);

    await transparency.connect(processor).mint(
      1234,
      1111,
      10,
      "Café procesado",
      "lbs"
    );

    var attr = await transparency.getTokenAttrs(1111);
    expect(attr[0]).to.equal(processor.address);
    expect(attr[1]).to.equal(1234);
    expect(attr[2]).to.equal(10);
    expect(attr[3]).to.equal("Café procesado");
    expect(attr[4]).to.equal("lbs");
    expect(attr[5]).to.equal(0);

    var tokens = await transparency.connect(processor).getTokenIds();
    expect(tokens[0]).to.equal(0);
    expect(tokens[1]).to.equal(1111);


  });


});
