// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//Import von Ownable.sol zur Sicherheit, Owner eines Ownable Contract ist
//der Deployer des Contracts. transferOwnverhip lässt die Ownership an den
//neuen Host des Spieles übertragen. 
import "./Ownable.sol";

//Base Cotract
contract Game is Ownable {
    
    //Struktur der Spieler definieren
    struct Player {
        uint number;
        bool hasPlayed;
        bool hasWithdrawn;
        address payable addr;
    }

    //Liste der Spieler (in dem Proxy Spiel)
    Player[] public players;
    uint public winningNumber;
    bool public hasWinner;
    uint private entryFee;
    uint public prizePool;
    uint private serviceFee;
    
    //Events - Selbsterklärend
    event PlayerJoined(address player, uint number);
    event GameEnded(uint winningNumber, uint prizePool);
    event WinnerSelected(address winner, uint prize);
    event PlayerWithdrawn(address player, uint amount);
    
    /*constructor(uint _entryFee, uint _serviceFee) {
        entryFee = _entryFee;
        serviceFee = _serviceFee;
    }*/

    //prüfen, ob init Methode einmal ausgeführt wurde
    function init(uint _entryFee) public {
        entryFee = _entryFee;
    }
    
    function play(uint number, uint value) public payable {
        require(number >= 0 && number <= 1000, "Number must be between 0 and 1000.");
        require(players.length < 3, "Maximum number of players reached.");
        require(!hasWinner, "Game is already over.");
        value = value;
        /*require(msg.value >= entryFee, "Entry fee not paid.");*/
        /*for(uint i=0; i<players.length; i++) {
            require(players[i].number != number, "Number already chosen.");
        }*/
        players.push(Player(number, true, false, payable(msg.sender)));
        prizePool += value /*msg.value*/;
        emit PlayerJoined(msg.sender, number);
        /*if(players.length == 3) {
            startGame();
        }*/
    }
    
    function endGame() public /*hier eigentlich private*/ {
        uint sum = players[0].number + players[1].number + players[2].number;
        uint average = sum / 3;
        uint twoThirdsAverage = (2 * average) / 3;
        uint closestNumber = 0;
        uint closestDistance = 1000;
        for(uint i=0; i<players.length; i++) {
            uint distance = players[i].number > twoThirdsAverage ? players[i].number - twoThirdsAverage : twoThirdsAverage - players[i].number;
            if(distance < closestDistance) {
                closestNumber = players[i].number;
                closestDistance = distance;
            } else if(distance == closestDistance && players[i].number == closestNumber) {
                hasWinner = true;
                winningNumber = closestNumber;
                emit GameEnded(winningNumber, prizePool);
                selectRandomWinner();
                return;
            }
        }
        for(uint i=0; i<players.length; i++) {
            if(players[i].number == closestNumber) {
                hasWinner = true;
                winningNumber = closestNumber;
                emit GameEnded(winningNumber, prizePool);
                selectRandomWinner();
                return;
            }
        }
    }
    
    function getRandomNumber(uint max) private view returns (uint) {
        return uint(keccak256(abi.encodePacked(block.timestamp, players.length))) % max;
    }
    
    function selectRandomWinner() private {
        uint count = 0;
        for(uint i=0; i<players.length; i++) {
            if(players[i].number == winningNumber) {
                count++;
            }
        }       
        if(count == 1) {
            address payable winner;
            for (uint i = 0; i < players.length; i++) {
                if (players[i].number == winningNumber) {
                    winner = payable(players[i].addr);
                    winner.transfer(prizePool);
                    emit WinnerSelected(players[i].addr, prizePool);
                }
            }
                payable(owner()).transfer(serviceFee);
            } else {
                uint randomIndex = getRandomNumber(count);
                uint currentIndex = 0;
                for (uint i = 0; i < players.length; i++) {
                    if (players[i].number == winningNumber) {
                        if (currentIndex == randomIndex) {
                            address payable winner = payable(players[i].addr);
                            winner.transfer(prizePool);
                            emit WinnerSelected(players[i].addr, prizePool);
                            break;
                        } else {
                            currentIndex++;
                        }
                    }
                }
                payable(owner()).transfer(serviceFee);
            }
    }

    function withdraw() public {
        for(uint i=0; i<players.length; i++) {
            if(players[i].hasPlayed && !players[i].hasWithdrawn && players[i].addr != msg.sender) {
                players[i].hasPlayed = false;
                players[i].hasWithdrawn = true;
                payable(players[i].addr).transfer(entryFee);
                emit PlayerWithdrawn(players[i].addr, entryFee);
            }
        }
        for(uint i=0; i<players.length; i++) {
            if(players[i].hasPlayed && !players[i].hasWithdrawn && players[i].addr == msg.sender) {
                players[i].hasPlayed = false;
                players[i].hasWithdrawn = true;
                payable(msg.sender).transfer(entryFee + (prizePool / 2));
                emit PlayerWithdrawn(msg.sender, entryFee + (prizePool / 2));
                prizePool = prizePool / 2;
            }
        }
    }

    function cancelGame() public onlyOwner {
        for(uint i=0; i<players.length; i++) {
            if(players[i].hasPlayed && !players[i].hasWithdrawn) {
                players[i].hasPlayed = false;
                players[i].hasWithdrawn = true;
                payable(players[i].addr).transfer(entryFee);
                emit PlayerWithdrawn(players[i].addr, entryFee);
            }
        }
    }

    function getPlayers() public view returns (Player[] memory) {
        return players;
    }

    function getPrizePool() public view returns (uint) {
        return prizePool;
    }

    function getServiceFee() public view returns (uint) {
        return serviceFee;
    }
}


