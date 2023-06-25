// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//import des Games
import "./Game.sol";
//import der Funktionen für das Factory-Pattern: Erstellung von Proxy-Contracts
import "./CloneFactory.sol";

contract GameFactory is CloneFactory{
    //Bestimmung des Eigentümers
    address private owner;
    // Adresse aller Spiele
    address[] public games;  
    //Adresse des Master-Contracts, Grundlage für die Proxys
    address gameContract; 
    //Servicefee mit bestimmten Betrag
    uint public serviceFee; 
    //Eintrittsgebühren und gleichzeitg Wetteinsatz 
    uint[] public entryFees;
    //Event, dass Spiel kreiert wurde
    event GameCreated(address gameAdress);
    //Mapping-Variable, Spielersteller wird hier gespeichert (wichtig für das anzeigen des besitzers der Lobby)
    mapping(address => address) public gameOwners; 
    //Mapping-Variable, Wetteinsatz wird hier gespeichert (wichtig für das anzeigen des Wetteinsatzes in der Lobbyliste)
    mapping(address => uint256) public entryFeesMapper;
    //Mapping-Variable, um sicherzustellen, dass ein Spieler ein Spiel erstellt hat - oder eben nicht.
    mapping(address => bool) private hasCreatedGame;
    //Addresse des Spielerstellers
    address creator;
    

    //Modifier zur Prüfung, ob der Sender der Besitzer des Contracts ist
    modifier onlyOwner() {
        require(msg.sender == owner);                
        _;
    }


    //Adresse des deployten Game-Contract wird automatisch übergeben. siehe Migration, factory.js und game.js Files
    constructor(address _gamecontract){
        //setzen des Contract-Besitzers
        owner = msg.sender;
        //Adresse des Base-Contcrats in die globale Variable masterContract
        gameContract = _gamecontract;
    }

    //Funktion zum Erstellen des Spiels
    function createGame(uint _entryFee) public {
        //Ein Spieler kann immer nur eine Spiele-Instanz generieren
        require(!hasCreatedGame[msg.sender], "You have already created a Game" );
        //Zugriff auf den Base-Contract und Erstellung eines Clones des Spiels
        Game game = Game(createClone(gameContract));
        // Initialisieren des Spiels
        games.push(address(game));
        creator = msg.sender;
        game.init(_entryFee, creator);
        //Spielersteller(Spielleiter wird gespeichert 
        gameOwners[address(game)] = msg.sender;
        //Wetteinsatz wird gespeichert
        entryFeesMapper[address(game)] = _entryFee;
        hasCreatedGame[msg.sender] = true;
    }

    //Anzeigen des Spielleiters
    function getGameOwner(address gameAddress) public view returns (address) {
        return gameOwners[gameAddress];
    }

    //Anzeigen aller existierenden Spiele
    function getGames() public view returns (address[] memory) {
        return games;
    }

    //Anpassung der Servicegebühr, noch nötig?
    function adjustServiceFee(uint256 newServiceFee) public onlyOwner {
        serviceFee = newServiceFee;
    }
    
    function getEntryFee(address gameAdress) public view returns(uint256){
        return entryFeesMapper[gameAdress];
    }

    //Funktion, damit ein Spieler immer nur eine Spiellobby erstellen kann
    function hasCreatedGameFunction() public view returns (bool) {
        return hasCreatedGame[msg.sender];
    }

    function getCreator() public view returns (address) {
        return owner; 
    }    
}