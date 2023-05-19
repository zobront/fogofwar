use dep::std;

fn main(
    secret: Field,
    secret_hash: pub Field,
    move: u32,
    move_commitment: pub Field,
    op_card: pub u32,
    exp_result: pub u32
) -> pub Field {
    assert(secret_hash == std::hash::pedersen([secret])[0]);
    assert(move_commitment == std::hash::pedersen([move as Field])[0]);

    let mut card = move % 6;
    if (card == 0) {
        card = 6;
    }

    let mut nullifier_input = [0; 2];
    nullifier_input[0] = card as Field;
    nullifier_input[1] = secret;
    let nullifier = std::hash::pedersen(nullifier_input)[0];

    let mut result = 0;
    if (card > op_card) {
        result = 1;
    } else if (card < op_card) {
        result = 2;
    }
    assert(result == exp_result);

    nullifier
}
