<h1 align="center">PieBank</h1>

PieBank is a modular digital banking system built for ComputerCraft. It allows servers to create a fully functional in-game economy with bank accounts, secure PIN authentication, withdraws, deposits, transfers, and physical bank cards.

The system is split into three components:

- **Services** - Handles account creation, recovery, deletion, and card issuance.
- **ATM** - Allows players to deposit, withdraw, and transfer funds.
- **Gateway** - Connects in-game machines to the external API and database.

## Installation

### Services

```
wget run https://raw.githubusercontent.com/PieTw3lve/PieBank/main/services/install.lua
```

### ATM

```
wget run https://raw.githubusercontent.com/PieTw3lve/PieBank/main/atm/install.lua
```


### Gateway


```
wget run https://raw.githubusercontent.com/PieTw3lve/PieBank/main/gateway/install.lua
```
## API

PieBank communicates with an external HTTP API to securely manage accounts, balances, and transactions. The API is used by the Gateway component to connect in-game computers to the central database.

Full API documentation can be found [here](https://docs.google.com/document/d/e/2PACX-1vRuAr3wjUE7QDe9sdiuExDcjT-5EYmrHArcYz-s5Bh2gfbqQ9tIDpz1NR20jWwmHmYEKZpUlLe5xZil/pub).