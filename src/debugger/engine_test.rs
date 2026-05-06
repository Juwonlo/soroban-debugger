use super::DebuggerEngine;

fn create_test_engine() -> DebuggerEngine {
    let wasm_bytes = include_bytes!("../../tests/fixtures/wasm/echo.wasm").to_vec();
    let executor = crate::runtime::executor::ContractExecutor::new(wasm_bytes).unwrap();
    DebuggerEngine::new(executor, vec![])
}

#[test]
fn engine_starts_unpaused() {
    let engine = create_test_engine();
    assert!(!engine.is_paused());
}

#[test]
fn no_source_location_without_instruction_state() {
    let engine = create_test_engine();
    assert!(engine.current_source_location().is_none());
}
