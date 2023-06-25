// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//Base Cotract
contract Game {
    
    //Struktur der Spieler definieren
    struct Player {
        uint number;
        bool hasPlayed;
        bool hasWithdrawn;
        address payable addr;
    }

    struct Commits {
        bytes32 commit;
        bool revealed;
    }

    enum Phase {
        Commit,
        Reveal,
        Complete
    }

    //Liste der Spieler (in dem Proxy Spiel)
    Player[] public players;
    Phase public phase;
    //wichtige Variablen für die Spiellogik
    uint public winningNumber;
    bool public hasWinner;
    uint private entryFee;
    uint public prizePool;
    uint private serviceFee = 10000000;
    address payable winner;
    address payable withdrawAdress;
    address private owner;
    bool private initialized = false;
    uint8 public max = 100;
    uint8 public playersRevealedCount;
    uint8 public playersCommitCount;
    uint public sum;
    uint256 public revealDeadline;
    uint256 public additionalTime = 600; //600 Sekunden /10 Minuten, Zeit für die REveal-Phase
    uint256 public gameExpiredTimeForGameMasterbeingAFK = 3600; //1 Stunde, Um REveal-Phase einzuleiten, sonst können andere Spieler Withdrawn
    uint256 public waitTime;

    //Mapping der Commits zu den Adressen;
    mapping (address => Commits) private commits;

    //Events 
    // PlayerJoined: Ausgelöst, wenn Spieler dem Spiel beitritt. Übermittelt Adresse und Zahl des Spielers
    event PlayerJoined(address player, uint number);
    // GameEnded: Ausgelöst, wenn Spiel beendet ist. Übermittelt Gewinneradresse, Gewinnerzahl und Preisgeld
    event GameEnded(address addr, uint winningNumber, uint prizePool);
    // PlayerWithdrawn: Ausgelöst, wenn ein Spieler aus dem Spiel aussteigen möchte, Übermittelt: Adresse des Spielers, und den Betrag (Wetteinsatz)
    event PlayerWithdrawn(address player, uint amount);
    // GameDeleted: Ausgelöst, wenn der Spielleiter das game löschen möchte
    event GameDeleted(address indexed gameAdress); 
    //Event, um den Hash zu revealen
    event RevealHash(address sender, bytes32 revealHash, uint8 random);
    //Event, um den Hash zu commiten 
    event CommitHash(address player, bytes32 _hash);
    //Antowrten der Spieler revealen
    event RevealHash(address player, uint256 guess);
    //Event zum Starten der Reveal Phase
    event StartReveal(address owner, uint256 revealDeadline);

    
    // Funktion zum einmaligen Initialisieren des Wettbetrages, dass für alle Spieler gilt, Reduziert auf einmalig Ausführung.
    function init(uint _entryFee, address _owner) public {
        require(!initialized, "Already initialized");
        entryFee = _entryFee;
        owner = _owner;
        initialized = true;
        waitTime = block.timestamp + gameExpiredTimeForGameMasterbeingAFK;
    }

    // Funktion um den Hash bzw den Guess zu Committen 
    function commitHash(bytes32 _hash) public payable {
        require(phase == Phase.Commit, "Commit Phase is Over");
        require(commits[msg.sender].commit == 0, "Guess has been already entered" );
        require(msg.value == entryFee, "EntryFee needs to be paid");
        players.push(Player(0, true, false, payable(msg.sender)));
        commits[msg.sender].commit = _hash;
        // Hier werden von jedem Spieler die ServiceFee an den Owner/Spielersteller gezahlt.
        if (owner != msg.sender) {
            (bool success, bytes memory data)=  owner.call{value: serviceFee}("");
        }
        playersCommitCount +=1;
        prizePool += entryFee;
        emit CommitHash(msg.sender, _hash);
    }

    //Funktion, um Hash bzw den Guess zu revealen
    function reveal(uint256 guess, uint256 salt) public {
        bytes32 commit = keccak256(abi.encodePacked(guess, salt));
        require(phase == Phase.Reveal, "Still in the Commit-Phase");
        require(commits[msg.sender].revealed == false, "Guess is already revealed");
        require(commits[msg.sender].commit == commit, "Commits have to be equal");
        require(block.timestamp > revealDeadline, "Time limit for reveal has expired");
        for (uint256 i = 0; i < players.length; i++){
            if(msg.sender == players[i].addr){
                players[i].number = guess;
            }
            else{
                continue;
            }
        }
        //Setzen des Commit-Status auf True
        commits[msg.sender].revealed = true;
        sum += guess;
        playersRevealedCount += 1;
        emit RevealHash(msg.sender, guess);
    }
    
    //Funktion um die Reveal_phase einzuleiten, mit gewisser zeitlicher Begrenzung
    function RevealPhase() public {
        require(phase == Phase.Commit, "Reveal-Phase already started");
        require(playersCommitCount ==3, "Not all Players commitet yet");
        //setzen auf den Reveal Status
        phase = Phase.Reveal;
        //DEadline bestimmen
        revealDeadline = block.timestamp + additionalTime;
        emit StartReveal(owner, revealDeadline);
    }

    //Funktion, um das Spiel nach dem Revealen auszuführen oder Ablauf der Reveal Zeit uu starten
    function play() public {
        require(block.timestamp > revealDeadline || playersRevealedCount == players.length, "Cannot start the game yet");
        require(!hasWinner, "Game is already over.");
        winner = calculateWinner();
        prizePool = 3*entryFee;
        for (uint256 i = 0; i < players.length; i++){
            if(winner == players[i].addr){
                winningNumber = players[i].number;
            }
            else{
                continue;
            }
        }
        (bool success, bytes memory data)=  winner.call{value: prizePool}("");
        hasWinner = true;
        emit GameEnded(winner, winningNumber, prizePool);
    }


    //Funktion um Gewinner zu bestimmen.
    function calculateWinner() public returns (address payable) {
        //Durchschnittszahl
        uint256 average = sum / 3;
        
        //Bestimmung der variablen = übergebe Zahlen der SPieler zum berechnen der Gewinnerzahlen
        uint a;
        uint b;
        uint c;
        for (uint256 i = 0; i < 1; i++){
            a = players[i].number;
            b = players[i+1].number;
            c = players[i+2].number;
        }

        //Berechnung der Distanz der Zahlen zur Durchscnittszahl (2/3 Zahl)
        uint256 distanceA = calculateDistance(a, average);
        uint256 distanceB = calculateDistance(b, average);
        uint256 distanceC = calculateDistance(c, average);

        // Case 1: Alle Zahlen sind gleich: Bestimmt zufälligen Gewinner
        if (distanceA == distanceB && distanceB == distanceC){
            uint playIndex = getRandomNumber(3);
            winner = players[playIndex].addr;
        }
        // Case 2: a und b sind theoretisch Siegerzahlen: Bestimmt zugälligen Sieger ziwschen den beiden
        else if (distanceA == distanceB){
            uint playIndex = getRandomNumber(2);
            winner = players[playIndex].addr;
        }
        // Case 3: a und c sind theoretisch Siegerzahlen: Bestimmt zugälligen Sieger ziwschen den beiden
        else if (distanceA == distanceC) {
            for (uint256 i = 0; i < 1000000; i++) {
                uint playIndex = getRandomNumber(3); 
                if (playIndex != 1){
                break;
                }
            winner = players[playIndex].addr;
            }
        }
        // Case 4: b und c sind theoretisch Siegerzahlen: Bestimmt zugälligen Sieger ziwschen den beiden
        else if (distanceB == distanceC) {
            for (uint256 i = 0; i < 1000000; i++) {
                uint playIndex = getRandomNumber(3); 
                if (playIndex != 0){
                break;
                }
            winner = players[playIndex].addr;
            }
        }
        //Case 5: a ist Siegerzahl
        else if (distanceA < distanceB && distanceA < distanceC) {
            uint playIndex = 0;
            winner = players[playIndex].addr;
        } 
        //Case 6: b ist Siegerzahl
        else if (distanceB < distanceA && distanceB < distanceC) {
            uint playIndex = 1;
            winner = players[playIndex].addr;
        } 
        //Case 7: c ist Siegerzahl
        else {
            uint playIndex = 2;
            winner = players[playIndex].addr;
        }
        return winner;  
    }


    // Funktion, um die Distanz zwischen den Spielerzaheln und dem Durchschnitt zu berechen, als postive Zahl
    function calculateDistance(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a > b) {
            return a - b;
        } else {
            return b - a;
        }
    }


    // Funktion zum ermitteln einer zufälligen Zahl 
    function getRandomNumber(uint maximum) private view returns (uint) {
        return uint(keccak256(abi.encodePacked(block.timestamp, players.length))) % maximum;
    }

    
    // Funktion zum Abheben des Wettbetrages
    function withdraw() public {
        require(phase == Phase.Commit, "It still has to be the Commit Phase");
        require(block.timestamp > waitTime, "You need to wait till the WaitTime ends.");
        require(commits[msg.sender].commit != 0, "There is nothing to Withdraw" );
        require(msg.sender != owner, "GameMaster not allowed to Withdraw" );
        for(uint i=0; i<players.length; i++) {
            if(players[i].hasPlayed && !players[i].hasWithdrawn && players[i].addr == msg.sender) {
                withdrawAdress = players[i].addr;
                players[i].hasPlayed = false;
                players[i].hasWithdrawn = true;
                (bool success, bytes memory data)=  withdrawAdress.call{value: entryFee}("");
                
                emit PlayerWithdrawn(msg.sender, entryFee);
            }
        }
    }

    function getPlayers() public view returns (address[] memory) {
        address[] memory justPlayerAddresses = new address[](players.length);
        for (uint256 i = 0; i < players.length; i++) {
            justPlayerAddresses[i] = players[i].addr;
        }
        return justPlayerAddresses;
    }
    
    function getPrizePool() public view returns (uint) {
        return prizePool;
    }

    function getServiceFee() public view returns (uint) {
        return serviceFee;
    }
    
    function getWinner() public view returns (address) {
        return winner;
    }

    function getWinningNumber() public view returns (uint) {
        return winningNumber; 
    }
    
    function getEntryFee() public view returns (uint) {
        return entryFee; 
    }
    
    function getOwner() public view returns (address) {
        return owner; 
    }

    function allPlayersReady() public view returns (uint){
        require(playersRevealedCount == 3, "Not All players revealed yet");
        return playersRevealedCount;
    }
}