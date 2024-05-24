// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract GreenOrigin is ERC721, Ownable {
    // Mapping para llevar el control de las cuentas
    mapping (address => Person) private accounts;

    // Mapping para los atributos del token por medio de su ID
    mapping (uint256 => Attr) public attributes;

    // Mapping para verificar los tokens que tiene un address
    mapping (address => uint256[]) public ownedTokens;

    // Mapping para el índice del token en ownedTokens
    mapping (uint256 => uint8) private index;

    // Mapping para llevar el control de las parcelas
    mapping (uint256 => Parcel) public parcels;

    // Mapping para llevar el control de las parcelas por usuario
    mapping (address => uint256[]) public ownedParcels;

    // Contador de parcelas
    uint256 public parcelCount;

    // Evento que se emite en cada transacción
    event Transaction(
        address indexed _from,  // Indexed permite buscar en blockchain por cualquiera de las 3 variables declaradas
        uint256 indexed _tokenId,
        State indexed _state
    );

    event ParcelRegistered(
        uint256 indexed id,
        address indexed owner,
        string indexed coordinates 
    );

    struct Parcel {
        uint id;
        string coordinates;
        address owner;
        bool compliant;
        string[] auditHistory;
    }

    // Estructura para definir los atributos del token
    struct Attr {
        address createdBy;
        uint256 origin;
        uint8 quantity;
        string product;
        string unit;
        State state;
        uint256 parcelId;
    }

    // Estructura de datos para personas registradas
    struct Person {
        bool registered;
        string name;
        string location;
        uint256 registered_date;
        Role role;
    }

    // Roles de la cadena de suministro
    enum Role {
        Farmer, 
        Processor, 
        Exporter,
        OperatorEU,
        Customer
    }

    // Estados del Token
    enum State {
        NEW,
        DELIVERED,
        ACCEPTED,
        REJECTED,
        USED,
        ONSALE,
        BOUGHT
    }

    constructor() ERC721("Origin", "ORG") Ownable(msg.sender) {}

    // Modificador para verificar que el usuario esté registrado
    modifier userRegistered() {
        require(accounts[msg.sender].registered, "Debe estar registrado");
        _;
    }

    modifier onlyFarmer() {
        require(accounts[msg.sender].role == Role.Farmer, "Solo el Farme puede registrar una parcela");
        _;
    }

    // Función para registrar un usuario
    function registerUser(
        address _userAddress, 
        string memory _name, 
        string memory _location, 
        uint256 _reg_date, 
        Role _role
    ) public onlyOwner {
        require(!accounts[_userAddress].registered, "Ya existe una cuenta con esta direccion");
        accounts[_userAddress] = Person(true, _name, _location, _reg_date, _role);
    }

    // Función para minar los tokens
    function mint(
        uint256 _fromTokenId, 
        uint256 _toTokenId,
        uint256 _parcelId,
        uint8 _quantity, 
        string memory _product, 
        string memory _unit
    ) external userRegistered {
        if (getUserRole(msg.sender) == Role.Processor) {
            require(attributes[_fromTokenId].state == State.ACCEPTED, "El token debe estar en estado ACCEPTED");
            _removeTokenFromOwnerEnumeration(msg.sender, _fromTokenId);
            attributes[_fromTokenId].state = State.USED;
            _burn(_fromTokenId);
            emit Transaction(msg.sender, _fromTokenId, State.USED);
        }

        require(parcels[_parcelId].id == _parcelId, "Parcela no encontrada");
        // require(parcels[_parcelId].compliant, " Parcela no esta en cumplimiento");
        _safeMint(msg.sender, _toTokenId);
        attributes[_toTokenId] = Attr(msg.sender, _fromTokenId, _quantity, _product, _unit, State.NEW, _parcelId);
        _addTokenToOwnerEnumeration(msg.sender, _toTokenId);
        emit Transaction(msg.sender, _toTokenId, State.NEW);
    }

    // Función para que el Farmer pueda refistrar una nueva parcela
    function registerParcel(string memory _coordinates) public onlyFarmer {
        parcelCount++;
        parcels[parcelCount] = Parcel({
            id: parcelCount,
            coordinates: _coordinates,
            owner: msg.sender,
            compliant: false,
            auditHistory: new string[](0)
        });
        
        // Se asigna la parcela al address del Farmer
        ownedParcels[msg.sender].push(parcelCount);
        emit ParcelRegistered(parcelCount, msg.sender, _coordinates);
    }

    // Función para transferir tokens
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) public override {
        _transfer(_from, _to, _tokenId);
        _removeTokenFromOwnerEnumeration(_from, _tokenId);
        _addTokenToOwnerEnumeration(_to, _tokenId);
    }

    // Función para transferir el token al Processor
    function transferToProcessor(address _processor, uint256 _tokenId) external userRegistered {
        safeTransferFrom(msg.sender, _processor, _tokenId);
        attributes[_tokenId].state = State.DELIVERED;
        emit Transaction(_processor, _tokenId, State.DELIVERED);
    }

    // Función para aceptar el token
    function accept(uint256 _tokenId) external {
        require(ownerOf(_tokenId) == msg.sender && attributes[_tokenId].state == State.DELIVERED, "No es owner de este token");
        attributes[_tokenId].state = State.ACCEPTED;
        emit Transaction(msg.sender, _tokenId, State.ACCEPTED);
    }

    // Función para rechazar el token
    function reject(uint256 _tokenId) external {
        require(ownerOf(_tokenId) == msg.sender && attributes[_tokenId].state == State.DELIVERED, "No es owner de este token");
        safeTransferFrom(msg.sender, attributes[_tokenId].createdBy, _tokenId);
        attributes[_tokenId].state = State.REJECTED;
        emit Transaction(msg.sender, _tokenId, State.REJECTED);
    }

    // Función para obtener los datos del usuario
    function getUserData(address _userAddress) external view returns (string memory, string memory, uint256, Role) {
        Person memory user = accounts[_userAddress];
        return (user.name, user.location, user.registered_date, user.role);
    }

    // Función para obtener los atributos del token
    function getTokenAttrs(uint _tokenId) external view returns (address, uint256, uint8, string memory, string memory, State) {
        Attr memory attr = attributes[_tokenId];
        return (attr.createdBy, attr.origin, attr.quantity, attr.product, attr.unit, attr.state);
    }

    // Función para obtener los tokenIds por cada address
    function getTokenIds() external view returns (uint256[] memory) {
        return ownedTokens[msg.sender];
    }

    // Obtener el rol por el address del usuario
    function getUserRole(address _userAddress) public view returns (Role) {
        return accounts[_userAddress].role;
    }

    // Función para obtener las parcelas por usuario
    function getParcelsByOwner(address _owner) external view returns (uint256[] memory) {
        return ownedParcels[_owner];
    }

    // Funciones internas para manejar la enumeración de tokens
    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        ownedTokens[to].push(tokenId);
        index[tokenId] = uint8(ownedTokens[to].length - 1);
    }

    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        uint8 tokenIndex = index[tokenId];
        uint256 lastTokenId = ownedTokens[from][ownedTokens[from].length - 1];
        ownedTokens[from][tokenIndex] = lastTokenId;
        index[lastTokenId] = tokenIndex;
        ownedTokens[from].pop();
    }
}
