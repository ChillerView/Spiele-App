import Head from 'next/head'
import Web3 from 'web3'
import gameContract from '/game'
import factoryContract from '/factory'
import { useState, useEffect, useRef} from 'react'
import useInterval from '/Interval'
import 'bulma/css/bulma.css'
import styles from '../styles/Spiel.module.css'
import GameABI from '/build/contracts/Game.json'


const Spiel = () => {

    let web3 = new Web3("HTTP://127.0.0.1:7545");

    const [error, setError] = useState('');
    const [lobbys, setLobbys] = useState('');
    const [currentAccount, setCurrentAccount] = useState('');
    const [currentGame, setCurrentGame] = useState('');
    const [gameFinished, setGameFinished] = useState(true);
    const [prizePool, setPrizePool] = useState('');
    const [winningNumber, setWinningNumber] = useState('');
    const [winner, setWinner] = useState('');
    const [players, setPlayers] = useState([]);
    const [commit, setCommit] = useState(false);
    const [revealPhase, setRevealPhase] = useState(true);


    //Definition ALler Hooks
    //Aufruf der Funktion getAllGamesHandler (Initialler Aufruf)
    useEffect(() => {
        getAllGamesHandler();
        checkCurrentGame();
        loadAccount();
    }, 
    []);


    //Aktualliserung der Spieleliste und Spieler in der Lobby (Alle 5 Sekunden)
    useInterval(() => {
        getAllGamesHandler();
        checkCurrentGame();
        loadAccount();
    }, 5000)


    //Dieser Abschnitt (Zeile 25 bis 139 referenziert sich auf allgemeine UI Funktionen und Funktionen vom FactoryPattern/GameFactorySM)
    // Connect to MetaMask-Wallet (Account)
    const connectWalletHandler = async () => {
        if (typeof window !== "undefined" && typeof window.ethereum !== "undefined"){
            try{ 
                //identifizieren und setzen des MetaMask-Wallet Accounts
                await window.ethereum.request({method: "eth_requestAccounts"})
                const accounts = await web3.eth.getAccounts();
                setCurrentAccount(accounts[0]);
                web3 = new Web3(window.ethereum)
                //Setzen des (wechseln zum) aktuellen Accounts, der eingeloogt ist
                await window.ethereum.on('accountsChanged', function(accounts){
                    account = accounts[0];
                })
            } catch(err){
                setError(err.message)
            }
            
        }
        else {
            console.log("Please install MetaMask")
        }
    }


    //FUnktion zum ladden des Accounts (MetaMask-Wallet)
    const loadAccount = async () => {
        try {
            const web3 = new Web3(Web3.givenProvider);
            const accounts = await web3.eth.getAccounts();
            setCurrentAccount(accounts[0]);
        } catch (error) {
            setCurrentAccount(null);
            console.error(error);
        }
      };


    //Funktion zum erstellen eines Spiels (bisher Hardcode der Gebühren und GasPrice)
    const createGameHandler = async () => {
        try{
            //Checken, ob ein Spiel bereits von einem Spieler erstellt wurde
            const hasCreated = await factoryContract.methods.hasCreatedGameFunction().call({ from: currentAccount });   
            if (hasCreated === true){
                alert("You have already created a Game");
                return;
            }
        } catch (error) {
            console.error("Failed to catch game:", error);
          }

        //const entryFeeWei = web3.utils.toWei("100000",'Wei');
        const entryFee = parseInt(window.prompt("Choose EntryFee for this Lobby"), 10);
        if (!isNaN(entryFee)) {
            try {
                const weiEntryFee = web3.utils.toWei(entryFee.toString(),'Wei')
                const account = currentAccount;
                await factoryContract.methods.createGame(weiEntryFee).send({ from: account, gas: 500000 });
            }   catch (error) {
                console.error(error);
            }
        }
    };
    
    // Eine Arrow-Funktion, die alle aktuellen Spiele (die auch auf der Blockchain sind) zurückgibt
    // Erweiterung zur Lobby-Logik: mit Spielersteller und Anzahl Spieler 
    const getAllGamesHandler = async () => {
        try {
            const games = await factoryContract.methods.getGames().call();
            if (games.length === 0) {
            setLobbys("None Games");
        } else {
            const gamesWithOwner = await Promise.all(games.map(async(gameAddress) => {
                const creator = await getGameCreator(factoryContract, gameAddress);
                const entryFee = await getEntryFee(factoryContract, gameAddress);
                return {address: gameAddress, creator: creator, entryFee: entryFee}
            }))
            setLobbys(gamesWithOwner);
        }
        }   catch (error) {
          console.error("Failed to get games, gamemaster, players:", error);
        }
    };

    //Funktion zum Aufruf des Spielerstellers/Spielleiter
    const getGameCreator = async (factoryContract, gameAddress) => {
        try{
            const creator = await factoryContract.methods.getGameOwner(gameAddress).call();
            return creator;
        }   catch(error) {
            console.error("Failed to get the gameCreator", error);
            return;
        }
    }

    //Funktion zum Aufruf des Wetteinsatzes zu dieser Lobby
    const getEntryFee = async(factoryContract, gameAddress) => {
        try{
            const entryFee = await factoryContract.methods.getEntryFee(gameAddress).call();
            return entryFee;
        }   catch(error) {
            console.error("Failed to get EntryFee", error);
            return;
        }
    }

    // Überprüfen, ob der Benutzer ein Spiel erstellt hat und aktualisiert das aktuelle Spiel
    async function checkCurrentGame() {
            const games = await factoryContract.methods.getGames().call();
            const gameAddress = await Promise.all(games.map(async(gameAddress) => {
                const creator = await getGameCreator(factoryContract, gameAddress);
                const entryFee = await getEntryFee(factoryContract, gameAddress);
                return {address: gameAddress, creator: creator, entryFee: entryFee}
        }))
        const myGame = gameAddress.find(game => game.creator === currentAccount);
        if (myGame) {
            setCurrentGame(myGame);
        }
    }

    //Funktion zum Beitreten des Spiels
    const joinGame = async (gameAddress) => {
        try {
            const creator = await getGameCreator(factoryContract, gameAddress);
            const entryFee = await getEntryFee(factoryContract, gameAddress);
            setCurrentGame(prevState => {
                return {
                  ...prevState,
                  address: gameAddress,
                  creator: creator,
                  entryFee: entryFee,
                };
            });
        }   catch (error) {
            console.error("Failed to join game:", error);
        };
    };

    // Funktion, um den Commit (vom Spieler) an den Proxy-Game-Contract zu senden
    //SubmitCommit noch bearbeiten, das commit selbst kann nicht übermittelt werden
    const submitCommit = async(gameAddress) => {

        const number = parseInt(window.prompt("Choose a number between 0 and 1000"), 10);
        const salt = parseInt(window.prompt("Choose a salt (any Number) and remember it"), 10);
        if (!isNaN(number)) {
            try {
                const account = currentAccount;
                const proxyContract = new web3.eth.Contract(GameABI.abi, gameAddress);
                const entryFee = await getEntryFee(factoryContract, gameAddress);
                const commit = web3.utils.soliditySha3(number,salt);
                await proxyContract.methods.commitHash(commit).send({ from: account, gas: 500000, value: entryFee });
                setCommit(true)
            }   catch (error) {
                console.error("Failed to submit the commit:", error);
            }
        }
        else {
            console.warn("Invalid number entered.");
            }
    }

    //Funktion um die Reveal-Phase einzuleiten, nur vom Spielleiter Möglich
    const StartRevealPhase = async(gameAddress) => {
        try{
            //Account = der Spielleiter (owner), StartRevealPhase button wird nur ihm angezeigt.
            const account = currentAccount;
            const proxyContract = new web3.eth.Contract(GameABI.abi, gameAddress);
            await proxyContract.methods.RevealPhase().send({from: account});
            setRevealPhase(true);
            return {
                confirmed: true,
            };
        } catch (error){
            console.error("Failed to Start the Reveal-Phase:", error)
        };
    }

    //Funktion um die Reveal von jedem Spieler zu starten
    const revealGame = async(gameAddress) => {
        const number = parseInt(window.prompt("Type in your Number that you have commited"), 10);
        const salt = parseInt(window.prompt("Type in your salt that you have commited"), 10);
        try{
            const account = currentAccount;
            const proxyContract = new web3.eth.Contract(GameABI.abi, gameAddress);
            await proxyContract.methods.reveal(number, salt).send({from: account, gas: 500000})
            AllRevealed(gameAddress);
        }catch (error){
            console.log("Failed to reveal:", error)
        }
    }

    //FUnktion zum überprüfen, ob alle SPieler des Proxy Contract bereits revealed haben
    const AllRevealed = async(gameAddress) => {
        try {
            const proxyContract = new web3.eth.Contract(GameABI.abi, gameAddress);
            const playersRevealed = await proxyContract.methods.allPlayersReady().call;
            if(playersRevealed == 3){
                setAllRevealed(true);
                setGameFinished(true);
            }
        }catch (error){
            console.log("Not all Player revealed yet:", error);
        }
    }


    //Funktion zum Berechnen des Gewinners
    const calculateWinner = async(gameAddress) => {
        const proxyContract = new web3.eth.Contract(GameABI.abi, gameAddress);
        try{
            const account = currentAccount;
            await proxyContract.methods.play().send({from: account, gas: 500000});
            AllRevealed(gameAddress)
            gameResults(gameAddress);
        }catch (error){
            console.log("Can't calculate Winner:", error);
        }
    }


    //Spieler aus dem SC holen
    const getPlayers = async (gameAddress) => {
        try {
            const proxyContract = new web3.eth.Contract(GameABI.abi, gameAddress)
            const players = await proxyContract.methods.getPlayers().call();
                let formattedAddresses = "";
                for (let i = 0; i < players.length; i++) {
                const address = players[i];
                formattedAddresses += address + ", \n";
                }
            
            return formattedAddresses;
        }catch(error){
            console.error("Failed to get players:", error);
            return;
        }
    }

    //Spieler aus dem SC holen
    const getPrizePool = async (gameAddress) => {
        try {
            const proxyContract = new web3.eth.Contract(GameABI.abi, gameAddress)
            const priezPool = await proxyContract.methods.getPrizePool().call();
            return priezPool;
            }catch(error){
            console.error("Failed to get priezPool:", error);
            return;
          }
    }   

    //winningNumber aus dem SC holen
    const getWinningNumber = async (gameAddress) => {
        try {
            const proxyContract = new web3.eth.Contract(GameABI.abi, gameAddress)
            const winningNumber = await proxyContract.methods.getWinningNumber().call();
            return winningNumber;
            }catch(error){
            console.error("Failed to get winningNumber:", error);
            return;
          }
    }

    //Winner aus dem SC holen
    const getWinner = async (gameAddress) => {
        try {
            const proxyContract = new web3.eth.Contract(GameABI.abi, gameAddress)
            const winner = await proxyContract.methods.getWinner().call();
            return winner;
            }catch(error){
            console.error("Failed to get winner:", error);
            return;
          }
    }

    const getEntryFeeGame = async(gameAddress) => {
        try{
            const proxyContract = new web3.eth.Contract(GameABI.abi, gameAddress)
            const entryFee = await proxyContract.methods.getEntryFee().call();
            return entryFee;
        }   catch(error) {
            console.error("Failed to get EntryFee", error);
            return;
        }
    }


    // Funktion zum Abrufen der Werte aus dem Smart Contract und Anzeigen in der HTML-Seite
    const gameResults = async (gameAddress) => {
        try {
        // Abrufen und setzen des Prize Pool
        const prizePool = await getPrizePool(gameAddress);
        setPrizePool(prizePool);
        console.log(prizePool)
        // Abrufen und setzen  der Winning Number
        const winningNumber = await getWinningNumber(gameAddress);
        setWinningNumber(winningNumber);
        console.log(winningNumber)
        // Abrufen und setzen des Gewinners
        const winner = await getWinner(gameAddress);
        setWinner(winner);
        console.log(winner)
        // Abrufen und setzen der Spieler
        const players = await getPlayers(gameAddress);
        setPlayers(players);
        console.log(players)
        //Abfrage Entry des Spiels im ProxyContract
        const entreFeeGame = await getEntryFeeGame(gameAddress);
        console.log(entreFeeGame);
        }   catch (error) {
            console.error("Failed to retrieve game results:", error);
        }
    };   
    

    // Funktion zum Überprüfen, ob der aktuelle Benutzer der Spiel-Ersteller ist
    const isGameCreator = () => {
        if (currentGame && currentAccount) {
            return currentGame.creator === currentAccount;
        }
            return false;
    };
    

    // Funktion, um das Proxy-Spiel zu löschen
    const deleteGameHandler = async (gameAddress) => {
        try {
            const account = currentAccount;
            const proxyContract = new web3.eth.Contract(GameABI.abi, gameAddress)
            await proxyContract.methods.deleteGame().send({ from: account });
            
        } catch (error) {
            const owner = await gameContract.methods.getOwner().call();
            const creator = await factoryContract.methods.getCreator().call();
            const entreeeee = await gameContract.methods.getEntryFee().call()
            console.log(currentAccount, creator, owner, entreeeee)
            console.error("Failed to delete the game:", error);
        }
    };


    // Funktion, um sein Wettbetrag wieder abzuheben
    const withdraw = async (gameAddress) => {
        try {
            const account = currentAccount;
            const proxyContract = new web3.eth.Contract(GameABI.abi, gameAddress)
            await proxyContract.methods.withdraw().send({ from: account });
        } catch (error) {
            console.error('Failed to execute withdraw:', error);
         }
    };


    return (
        <div className={styles.main}>
            <Head>
                <title> Spiele App </title>
                <meta name='description' content='Ein Blockchain Spiel'></meta>
            </Head>
            <nav className='navbar mt-4 mb-4'>
                <div className=' navbar-brand'>
                    <h1>2/3-Spiel</h1>
                </div>
                <div className='navbar-end'>
                    <button onClick = {connectWalletHandler} className='button is-primary'>Connect Wallet</button>
                </div>
            </nav>
            <div className='navbar-end'>
                    <p> {error}</p>
            </div>
            <div>
                <div>
                    <p> Aktueller Account: {currentAccount ? currentAccount: "-"} </p>
                </div>
                <div>
                    <p> Informationen zum Spiel: </p>
                    <p1> Das 2/3-Spiel ist ein Spiel, in dem 3 Spieler miteinander spielen und eine geschätzte Zahl abgeben, die so nah wie 
                     möglich an 2/3 des Durchschitts der Summe aller Zahlen sein sollte. Dabei gewinnt der Spieler der am nähesten an der 2/3-Zahl ist.
                     Hierbei wählt Jeder Spieler eine Zahl und ein "Passwort/Salt". Wenn alle Spiele Ihre Zahl Abgegeben haben, leitet der Spielleiter der Lobby die
                     Reveal-Phase ein, in der Jeder Spieler seine eigene abgegebene Zahl revealed, indem der jeweilige Spieler nochmals die abgegebene Zahl und das Passwort
                     unverschlüsselt abgeben. Der Smart Contract überprüft, ob der commitete Hash mit dem neu berechneten Hash, welcher durch die Zahl und dem Passwort
                     neu generiert wird, identisch sind. Wenn alle Spieler Ihre Zahl aufgedeckt haben, wird der Gewinner bestimmt. Anschließend wird automatisch der Preispool
                     an den Gewinner gesendet. </p1>
                </div>
            </div>
            <p>Liste der Spiele:</p>
            <div className={styles.tableContainer}>
                {Array.isArray(lobbys) && lobbys.length > 0 ? (
                    <table>
                        <thead>
                            <tr>
                                <th>Spiel-Ersteller</th>
                                <th>Spiel-Adresse</th>
                                <th>Wettgebühren</th>
                            </tr>
                        </thead>
                        <tbody>
                            {lobbys.map((lobby, index) => (
                                <tr key={index}>
                                    <td>{lobby.creator}</td>
                                    <td>{lobby.address}</td>
                                    <td>{lobby.entryFee}</td>
                                    <td>
                                        <button onClick={() => joinGame(lobby.address)}>Join Game</button>
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                ) : (
                    <p>Keine Spiele vorhanden</p>
                )}
            </div>
            <div>
                <p>
                    <button onClick= {createGameHandler} className='button is-primary'>eigenes Spiel erstellen</button>
                </p>
            </div>
            <div>
                <h2>Spielbereich der lobby:</h2>
            </div>
            <div>
                <h2>Selected Game Details: </h2>
                {currentGame && (
                <div>
                    <p>Game Address: {currentGame.address}</p>
                    <p>Entry Fee: {currentGame.entryFee} Wei</p>
                    <p>Creator: {currentGame.creator}</p>
                    <p>
                    <button onClick = {() => {
                        submitCommit(currentGame.address);
                        }} className='button is-primary' >Submit Commit</button>
                    </p>
                    <p>

                        <button onClick={() => StartRevealPhase(currentGame.address)} className='button is-primary'>Start The Reveal-Phase</button>
                    </p>
                    <p>
                        <button onClick={() => deleteGameHandler(currentGame.address)} className='button'>Delete Game</button>
                    {currentGame && currentGame.creator !== currentAccount && (
                        <button onClick={() => withdraw(currentGame.address)} className='button is-primary'>Withdraw</button>
                    )}
                    </p>
                    <p>
                        {commit == true && revealPhase == true && (
                            <button onClick={() => revealGame(currentGame.address)} className='button is-primary'> Reveal the Commit</button>
                            
                        )}
                    </p>
                    <p>
                        <button onClick={() => calculateWinner(currentGame.address)} className='button is-primary'>Calculate the Winner</button>
                    </p>
                    {gameFinished && (
                        <div>
                            <p>Players: {players}</p>
                            <p>Prize Pool: {prizePool}</p>
                            <p>Winning Number: {winningNumber}</p>
                            <p>Winner: {winner}</p>
                        </div>
                    )}
                    {!gameFinished && currentGame.creator !== currentAccount && (
                        <section>
                            Warten bis das Spiel beginnt
                        </section>
                    )}
                </div>
                )}
            </div>
        </div>
    )
} 

export default Spiel