#![no_std]
use soroban_sdk::{contract, contractimpl, Env, Val};

#[contract]
pub struct Echo;

#[contractimpl]
impl Echo {
    fn helper(v: Val) -> Val {
        // BREAKPOINT_MARKER: non-exported-helper
        v
    }

    pub fn echo(_env: Env, v: Val) -> Val {
        // BREAKPOINT_MARKER: exported-echo
        Self::helper(v)
    }
}
