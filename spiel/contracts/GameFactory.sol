// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//import des Games
import "./Game.sol";
//import der Funktionen für das Factory-Pattern: Erstellung von Proxy-Contracts
import "./CloneFactory.sol";

import "./Ownable.sol";


contract GameFactory is CloneFactory, Ownable {
    //Bestimmung des Eigentümers                 
    //address private owner;
    // Adresse aller Spiele
    address[] public games;  
    //mapping der Adressen an die Eintrittsgebühren/Wettgebühren
    //mapping(entryFee => address) aMapping;
    //Adresse des Master-Contracts, Grundlage für die Proxys
    address masterContract = 0x130B771b54BA4498F19ecBddA42Bb6584493422F; 
    //Servicefee mit bestimmten Betrag
    uint public serviceFee; 
    //Eintrittsgebühren und gleichzeitg Wetteinsatz 
    uint public entryFee;
    //Event zum starten eines neuen Proxy-Contracts des Spiels
    event GameStarted(uint entryFee);
    //Adresse des öffentlich Spiels
    address public PublicGame;



    //Adresse des deployten Game-Contract wird manuell übergeben
    constructor(address _masterContract) public{
        //setzen des Contract-Besitzers
        //owner = msg.sender;
        //Adresse des Base-Contcrats in die globale Variable masterContract
        masterContract = _masterContract;
    }


    //Funktion zum Erstellen des Spiels
    function createGame(uint _entryFee) public {
        //Zugriff auf den Base-Contract und Erstellung eines Clones des Spiels
        Game game = Game(createClone(masterContract));
        // Initialisieren des Spiels, (noch zu Bearbeiten), übergabe von entryFee und ServiceFee (wenn nicht Hardgecoded)
        games.push(address(game));
        game.transferOwnership(msg.sender);
        game.init(_entryFee);
        PublicGame = address(game);
    }


    //Anzeigen aller existierenden Spiele
    function getGames() public view returns (address[] memory) {
        return games;
    }

    //Anpassung der Servicegebühr
    function adjustServiceFee(uint256 newServiceFee) public onlyOwner {
        serviceFee = newServiceFee;
    }
    
    //Funktion um Spiel zu starten
    function startGame() public{
        emit GameStarted(entryFee);
    }

}