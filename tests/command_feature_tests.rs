use assert_cmd::Command;
use predicates::prelude::*;
use std::fs;
use tempfile::NamedTempFile;

fn fixture_wasm(name: &str) -> std::path::PathBuf {
    std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("tests")
        .join("fixtures")
        .join("wasm")
        .join(format!("{name}.wasm"))
}

fn base_cmd() -> Command {
    let mut cmd = Command::new(env!("CARGO_BIN_EXE_soroban-debug"));
    cmd.env("NO_COLOR", "1");
    cmd.env("NO_BANNER", "1");
    cmd
}

#[test]
fn symbolic_runs_against_counter_fixture() {
    let wasm = fixture_wasm("counter");

    base_cmd()
        .args([
            "symbolic",
            "--contract",
            wasm.to_str().unwrap(),
            "--function",
            "increment",
        ])
        .assert()
        .success()
        .stdout(predicate::str::contains("Function: increment"))
        .stdout(predicate::str::contains("Paths explored:"));
}

#[test]
fn symbolic_writes_scenario_toml() {
    let wasm = fixture_wasm("counter");
    let output = NamedTempFile::new().unwrap();

    base_cmd()
        .args([
            "symbolic",
            "--contract",
            wasm.to_str().unwrap(),
            "--function",
            "increment",
            "--output",
            output.path().to_str().unwrap(),
        ])
        .assert()
        .success();

    let written = fs::read_to_string(output.path()).unwrap();
    assert!(written.contains("[[scenario]]"));
    assert!(written.contains("function = \"increment\""));
}

#[test]
fn analyze_json_outputs_findings_array() {
    let wasm = fixture_wasm("counter");

    base_cmd()
        .args([
            "analyze",
            "--contract",
            wasm.to_str().unwrap(),
            "--format",
            "json",
        ])
        .assert()
        .success()
        .stdout(predicate::str::contains("\"findings\""));
}

#[test]
fn analyze_dynamic_execution_reports_function_metadata() {
    let wasm = fixture_wasm("counter");

    base_cmd()
        .args([
            "analyze",
            "--contract",
            wasm.to_str().unwrap(),
            "--function",
            "increment",
            "--args",
            "[]",
        ])
        .assert()
        .success()
        .stdout(predicate::str::contains(
            "Dynamic analysis function: increment",
        ));
}

#[test]
fn scenario_runs_counter_steps() {
    let wasm = fixture_wasm("counter");
    let scenario = NamedTempFile::new().unwrap();
    fs::write(
        scenario.path(),
        r#"
[[steps]]
name = "Increment"
function = "increment"
args = "[]"
expected_return = "I64(1)"

[[steps]]
name = "Read Counter"
function = "get"
expected_return = "I64(1)"
"#,
    )
    .unwrap();

    base_cmd()
        .args([
            "scenario",
            "--scenario",
            scenario.path().to_str().unwrap(),
            "--contract",
            wasm.to_str().unwrap(),
        ])
        .assert()
        .success()
        .stdout(predicate::str::contains(
            "All scenario steps passed successfully!",
        ));
}

#[test]
fn repl_accepts_commands_and_exits() {
    let wasm = fixture_wasm("counter");
    let output = Command::new(env!("CARGO_BIN_EXE_soroban-debug"))
        .env("NO_COLOR", "1")
        .args(["repl", "--contract", wasm.to_str().unwrap()])
        .write_stdin("help\ncall increment\nexit\n")
        .output()
        .unwrap();

    assert!(
        output.status.success(),
        "stdout: {}\nstderr: {}",
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );

    let combined = format!(
        "{}{}",
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );

    assert!(combined.contains("soroban-debug repl ["));
}
