use dep::std;

fn main(
    secret: Field,
    secret_hash: pub Field,
    agent_cards: [u8; 6],
    nullifiers: pub [Field; 6],
    soldier_cards: pub [u8; 6]
) -> pub [u8; 2] {
    assert(std::hash::pedersen([secret])[0] == secret_hash);

    let mut soldier_score = 0;
    let mut agent_score = 0;
    let mut pending_score = 0;

    for i in 0..6 {
        let mut nullifier_input = [0; 2];
        nullifier_input[0] = agent_cards[i] as Field;
        nullifier_input[1] = secret;
        assert(std::hash::pedersen(nullifier_input)[0] == nullifiers[i]);

        if agent_cards[i] > soldier_cards[i] {
            agent_score += (agent_cards[i] + soldier_cards[i] + pending_score);
            pending_score = 0;
        } else if agent_cards[i] < soldier_cards[i] {
            soldier_score += (agent_cards[i] + soldier_cards[i] + pending_score);
            pending_score = 0;
        } else {
            pending_score += (agent_cards[i] + soldier_cards[i]);
        }
    }

    [agent_score, soldier_score]
}
