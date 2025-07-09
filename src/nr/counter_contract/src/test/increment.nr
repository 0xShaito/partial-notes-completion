use crate::{Counter, test::utils};

#[test]
unconstrained fn partial_note_completion_with_change() {
    let (env, contract_address, owner, recipient) = utils::setup_contract(false);
    
    ///////////////////// SUCCESS CASE /////////////////////
    env.impersonate(owner);
    let transfer_amount: u128 = 500_000;

    // Mint exactly the amounts we plan to transfer
    Counter::at(contract_address).mint_to_private(owner, owner, transfer_amount).call(
        &mut env.private(),
    );
    env.advance_block_by(1);

    env.impersonate(owner);
    let commitment_1 = Counter::at(contract_address)
        .initialize_transfer_commitment(owner, recipient, owner)
        .call(&mut env.private());

    // This should work because we have a note of exactly this amount
    // No change note will be created since subtracted == amount
    Counter::at(contract_address)
        .transfer_private_to_commitment(owner, commitment_1, transfer_amount, 0)
        .call(&mut env.private());
    env.advance_block_by(1);

    // This works when we have a note of exactly the amount we want to transfer
    utils::check_private_balance(contract_address, owner, 0);
    utils::check_private_balance(contract_address, recipient, transfer_amount);
    
    ///////////////////// FAILURE CASE /////////////////////
    // Now we mint an amount that would result in change
    // Mint more than the amount we want to transfer
    Counter::at(contract_address).mint_to_private(owner, owner, transfer_amount + 1).call(
        &mut env.private(),
    );
    env.advance_block_by(1);

    env.impersonate(owner);
    let commitment_2 = Counter::at(contract_address)
        .initialize_transfer_commitment(owner, recipient, owner)
        .call(&mut env.private());

    // This should fail because we don't have a note of exactly the amount we want to transfer
    Counter::at(contract_address)
        .transfer_private_to_commitment(owner, commitment_2, transfer_amount, 0)
        .call(&mut env.private());
    env.advance_block_by(1);

    // This fails now that the transfer to commitment emits a new note with the change
    utils::check_private_balance(contract_address, owner, 1);
    utils::check_private_balance(contract_address, recipient, transfer_amount + transfer_amount);
}
