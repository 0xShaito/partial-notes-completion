use crate::Counter;
use aztec::{
    prelude::AztecAddress, protocol_types::contract_instance::ContractInstance,
    test::helpers::test_environment::TestEnvironment,
    oracle::{
        execution::{get_contract_address},
    },
    test::helpers::cheatcodes,
};

pub unconstrained fn setup_contract(
    with_account_contracts: bool,
) -> (&mut TestEnvironment, AztecAddress, AztecAddress, AztecAddress) {
    // Setup env, generate keys
    let mut env = TestEnvironment::new();
    let (owner, user) = if with_account_contracts {
        let owner = env.create_account_contract(1);
        let user = env.create_account_contract(2);
        (owner, user)
    } else {
        let owner = env.create_account(1);
        let user = env.create_account(2);
        (owner, user)
    };

    let acontract = deploy_contract(&mut env, owner);

    (&mut env, acontract.to_address(), owner, user)
}

pub unconstrained fn deploy_contract(
    env: &mut TestEnvironment,
    owner: AztecAddress,
) -> ContractInstance {
    let initializer_call_interface = Counter::interface().constructor();
    let contract_instance = env
        .deploy("./@counter_contract", "Counter")
        .with_public_void_initializer(owner, initializer_call_interface);
    env.advance_block_by(1);

    contract_instance
}

pub unconstrained fn check_private_balance(
    token_contract_address: AztecAddress,
    address: AztecAddress,
    address_amount: u128,
) {
    let balance_of_private = get_private_balance(token_contract_address, address);
    assert(balance_of_private == address_amount, "Private balance is not correct");
}

pub unconstrained fn get_private_balance(
    counter_contract_address: AztecAddress,
    address: AztecAddress,
) -> u128 {
    let current_contract_address = get_contract_address();
    cheatcodes::set_contract_address(counter_contract_address);
    // Direct call to unconstrained
    let amt = Counter::balance_of_private(address);
    cheatcodes::set_contract_address(current_contract_address);
    amt
}
