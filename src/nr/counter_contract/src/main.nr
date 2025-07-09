use aztec::macros::aztec;
pub mod test;
mod types;

#[aztec]
pub contract Counter {
    // aztec library imports
    use aztec::{
        context::PrivateContext,
        macros::{functions::{initializer, internal, private, public, utility}, storage::storage},
        prelude::{AztecAddress, PublicImmutable, PublicMutable, PrivateMutable, Map},
        messages::logs::note::encode_and_encrypt_note,
    };

    use uint_note::uint_note::{PartialUintNote, UintNote};

    use crate::types::balance_set::BalanceSet;

    #[storage]
    struct Storage<Context> {
        private_balances: Map<AztecAddress, BalanceSet<Context>, Context>,
    }

    /// @dev Initialize the contract
    #[public]
    #[initializer]
    fn constructor() {}

    #[private]
    fn initialize_transfer_commitment(
        from: AztecAddress,
        to: AztecAddress,
        completer: AztecAddress,
    ) -> Field {
        let commitment = UintNote::partial(
            to,
            storage.private_balances.at(to).set.storage_slot,
            &mut context,
            to,
            from,
            completer,
        );

        commitment.commitment
    }

    #[private]
    fn transfer_private_to_commitment(
        from: AztecAddress,
        commitment: Field,
        amount: u128,
        _nonce: Field,
    ) {
        // Subtracts `amount` from the private balance of `account`
        let change = _subtract_balance(&mut context, storage.private_balances, from, amount, 2);
        // Increases `change` to the private balance of `account`, and emits a private balance note to account
        storage.private_balances.at(from).add(from, change).emit(encode_and_encrypt_note(
            &mut context,
            from,
            from,
        ));

        Counter::at(context.this_address())
            .increase_commitment_balance_internal(PartialUintNote { commitment }, from, amount)
            .enqueue(&mut context);
    }

    #[public]
    #[internal]
    fn increase_commitment_balance_internal(
        commitment: PartialUintNote,
        completer: AztecAddress,
        amount: u128,
    ) {
        let _ = commitment.compute_validity_commitment(completer);
        commitment.complete(&mut context, completer, amount);    
    }

    #[private]
    fn mint_to_private(from: AztecAddress, to: AztecAddress, amount: u128) {
        storage.private_balances.at(to).add(to, amount).emit(encode_and_encrypt_note(&mut context, to, from));
    }

    #[private]
    #[internal]
    fn recurse_subtract_balance_internal(account: AztecAddress, amount: u128) -> u128 {
        _subtract_balance(
            &mut context,
            storage.private_balances,
            account,
            amount,
            8,
        )
    }

    #[utility]
    pub unconstrained fn balance_of_private(owner: AztecAddress) -> u128 {
        storage.private_balances.at(owner).balance_of()
    }

    #[contract_library_method]
    fn _subtract_balance(
        context: &mut PrivateContext,
        private_balances: Map<AztecAddress, BalanceSet<&mut PrivateContext>, &mut PrivateContext>,
        account: AztecAddress,
        amount: u128,
        max_notes: u32,
    ) -> u128 {
        let subtracted = private_balances.at(account).try_sub(amount, max_notes);
        // Failing to subtract any amount means that the owner was unable to produce more notes that could be nullified.
        assert(subtracted > 0, "Balance too low");
        if subtracted >= amount {
            // We have achieved our goal of nullifying notes that add up to more than amount, so we return the change.
            subtracted - amount
        } else {
            // try_sub failed to nullify enough notes to reach the target amount, so we compute the amount remaining
            // and try again.
            let remaining = amount - subtracted;

            Counter::at(context.this_address())
                .recurse_subtract_balance_internal(account, remaining)
                .call(context)
        }
    }
}
