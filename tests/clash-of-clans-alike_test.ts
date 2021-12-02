// @ts-ignore
// prettier-ignore
import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v0.14.0/index.ts';
// @ts-ignore
import { assertEquals } from "https://deno.land/std@0.90.0/testing/asserts.ts";

Clarinet.test({
  name: "player-mgmt -- contract owner can add a new player",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    let deployer = accounts.get("deployer")!;
    let eUser = accounts.get("wallet_1")!;
    let block = chain.mineBlock([
      Tx.contractCall(
        "clash-of-clans-alike",
        "add-player",
        [types.principal(eUser.address)],
        deployer.address
      ),
      Tx.contractCall(
        "clash-of-clans-alike",
        "add-player",
        [types.principal(eUser.address)],
        eUser.address
      ),
    ]);
    block.receipts[0].result.expectOk().expectBool(true);
    block.receipts[1].result.expectErr().expectUint(100);
  },
});

Clarinet.test({
  name: "player-mgmt -- player can only be added once",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    let deployer = accounts.get("deployer")!;
    let eUser = accounts.get("wallet_1")!;
    let block = chain.mineBlock([
      Tx.contractCall(
        "clash-of-clans-alike",
        "add-player",
        [types.principal(eUser.address)],
        deployer.address
      ),

      Tx.contractCall(
        "clash-of-clans-alike",
        "add-player",
        [types.principal(eUser.address)],
        deployer.address
      ),
    ]);
    block.receipts[0].result.expectOk().expectBool(true);
    block.receipts[1].result.expectErr().expectUint(103);
  },
});

Clarinet.test({
  name: "token-mgmt -- set token supply",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    let deployer = accounts.get("deployer")!;
    let supply = 1000;
    let token_id = 1;
    let block = chain.mineBlock([
      Tx.contractCall(
        "clash-of-clans-alike",
        "set-subtoken-total-supply",
        [types.uint(token_id), types.uint(supply)],
        deployer.address
      ),

      Tx.contractCall(
        "clash-of-clans-alike",
        "get-subtoken-total-supply",
        [types.uint(token_id)],
        deployer.address
      ),
    ]);
    block.receipts[0].result.expectOk().expectBool(true);
    block.receipts[1].result.expectUint(supply);
  },
});

Clarinet.test({
  name: "token-mgmt -- send tokens to player",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    let deployer = accounts.get("deployer")!;
    let player = accounts.get("wallet_1")!;
    let amount = 1000;
    let token_id = 1;
    let block = chain.mineBlock([
      Tx.contractCall(
        "clash-of-clans-alike",
        "send-tokens",
        [
          types.uint(token_id),
          types.uint(amount),
          types.principal(player.address),
        ],
        deployer.address
      ),

      Tx.contractCall(
        "clash-of-clans-alike",
        "get-balance",
        [types.uint(token_id), types.principal(player.address)],
        deployer.address
      ),
    ]);
    block.receipts[0].result.expectOk().expectBool(true);
    block.receipts[1].result.expectOk().expectUint(amount);
  },
});

Clarinet.test({
  name: "game-play -- player can upgrade commodities by spending currencies",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    let deployer = accounts.get("deployer")!;
    let player = accounts.get("wallet_1")!;
    let amount = 5000;
    let gold = 0;
    let elixir = 1;
    let townhall = 10;
    let block = chain.mineBlock([
      // add player
      Tx.contractCall(
        "clash-of-clans-alike",
        "add-player",
        [types.principal(player.address)],
        deployer.address
      ),
      // send token 1 (gold)
      Tx.contractCall(
        "clash-of-clans-alike",
        "send-tokens",
        [types.uint(gold), types.uint(amount), types.principal(player.address)],
        deployer.address
      ),
      // send token 2 (elixir)
      Tx.contractCall(
        "clash-of-clans-alike",
        "send-tokens",
        [
          types.uint(elixir),
          types.uint(amount),
          types.principal(player.address),
        ],
        deployer.address
      ),
      // upgrade townhall to level 2
      Tx.contractCall(
        "clash-of-clans-alike",
        "upgrade",
        [types.uint(townhall), types.uint(2)],
        player.address
      ),
      // verify townhall level
      Tx.contractCall(
        "clash-of-clans-alike",
        "get-player-level",
        [types.principal(player.address), types.uint(townhall)],
        player.address
      ),
    ]);
    block.receipts[0].result.expectOk().expectBool(true);
    block.receipts[1].result.expectOk().expectBool(true);
    block.receipts[2].result.expectOk().expectBool(true);
    block.receipts[3].result.expectOk().expectBool(true);
    block.receipts[4].result.expectUint(2);
  },
});
