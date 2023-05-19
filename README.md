# Fog of War

Fog of War is a 2 player card game, played on the EVM using *~ZK*~ for a sprinkle of mystery.

The core game engine is built in Solidity, with the ZK circuits written in Noir.

## Rules

There are two players in the game — the soldier and the undercover agent. Both players start the game with the same six cards: 1, 2, 3, 4, 5 and 6.

Each turn, each player plays a card.
- The player who plays the higher card wins the round and gets points equal to the sum of both cards.
- If there is a tie, the cards remain in the middle and contribute to the next round's available points.

The game ends when all cards have been played. The player with the most points wins.

But the players have different experiences of the game.

For the undercover agent, all cards are played in the open. They know each card the soldier plays, and can deduce from that information which cards are left in their hand. They are playing a game with complete information.

For the soldier, they only know whether they won, lost or tied each round. The card played by the undercover agent is hidden from them. They are playing a game with incomplete information.

## How It Works

To start the game, the undercover agent commits to a `secretHash`, which is a hash of a random value they have selected. This is posted on chain.

The game flow for each turn is as follows:

1) The undercover agent commits to a hash of their move on chain. Rather than commiting to the card itself (which could be brute forced by testing the hashes of each of the 6 cards), they can commit to any number N where `N % 6 = their move`.

2) The soldier plays their card, directly calling a function to pass the card on chain.

3) The agent submits a ZK proof that attests to the following:
- They have a `secret` that hashes to the `secretHash` posted on chain
- They have a `move` that hashes to the `moveHash` posted on chain
- `card = move % 6` (adjusted to 6 if the result is 0)
- There is a nullifier that equals the hash of the `secret` and `move`
- That nullifier has not been used before
- Given the opponent's move posted on chain, their `card` is higher, lower, or the same

This cycle repeats for each turn. Fortunately, because the agent is going first and last, these two transactions are batched together into one function (`agentMove()`) which proves turn N and commits to turn N+1.

At the end of the game, the agent is responsible for submitting another proof of the results of the game. This proof attests to the following:
- They have a `secret` that hashes to the `secretHash` posted on chain
- An array of `agent moves` each hashed with the `secret` results in the array of `nullifiers` posted on chain
- The `agent score` is the sum of turns where the agent's card was higher (plus cards in the middle from previous ties)
- The `soldier score` is the sum of turns where the soldier's card was higher (plus cards in the middle from previous ties)

The contract then checks which score is higher, and updates ELO rankings accordingly.

## ELO Rankings

Ongoing rankings are maintained using an ELO ranking system. [You can read more about the ELO rating system and its formula here](https://en.wikipedia.org/wiki/Elo_rating_system).

To incentivize playing as the soldier (even though it is a disadvantaged position), ELO rating updates take into account the role of the player. The current implementation hardcodes the handicap to 400 points, but this will be made dynamic (based on the ratio of total games won by soldiers vs agents) in the future.

To protect against sybil attacks on the ELO system, a small fee is charged to register for the game and receive the starting rating of 1000.

## Testing

You can see a flow of the "happy path" in `test/FogOfWar.t.sol`. The test uses proofs that have been generated manually from the Noir circuit and saved in order to read in the values and prove each move. The full game runs properly and generates a winner.

Note that this is still in "hacked together" phase and hasn't been thought through from a stability or security perspective at all. I'm sure it's riddled with bugs.

## Future Work

There are some small improvements to make to the contracts and circuits, but they are close to complete.

The next phase is to built the front end that can facilitate gameplay, while generating proofs and submitting them on chain.

Frankly, this is not my wheelhouse. I may spend some time learning, or pause the project here.

If you're someone with front end skills and an interest in ZK, I'd love to work together on getting this completed and live. DM me on Twitter [@zachobront](http://twitter.com/zachobront).
