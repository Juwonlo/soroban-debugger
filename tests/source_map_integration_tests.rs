#[path = "fixtures/mod.rs"]
mod fixtures;

use soroban_debugger::debugger::source_map::SourceMap;

#[test]
fn source_map_missing_debug_info_is_graceful() {
    let wasm = fixtures::get_fixture_path(fixtures::names::COUNTER);
    if !wasm.exists() {
        eprintln!(
            "Skipping test: fixture not found at {}. Run tests/fixtures/build.sh to build fixtures.",
            wasm.display()
        );
        return;
    }

    let bytes = std::fs::read(&wasm).unwrap();
    let mut sm = SourceMap::new();
    sm.load(&bytes).expect("load should not fail");
    assert!(
        sm.is_empty(),
        "expected no DWARF mappings in stripped fixture"
    );
}

#[test]
fn source_map_debug_fixture_resolves_locations() {
    let Some(wasm) = fixtures::try_artifact_path(fixtures::names::COUNTER, "debug") else {
        eprintln!(
            "Skipping test: debug artifact missing from {}. Run tests/fixtures/build.sh to generate debug fixtures.",
            fixtures::manifest_path().display()
        );
        return;
    };

    if !wasm.exists() {
        eprintln!(
            "Skipping test: debug fixture not found at {}. Run tests/fixtures/build.sh to generate *_debug.wasm fixtures.",
            wasm.display()
        );
        return;
    }

    let bytes = std::fs::read(&wasm).unwrap();
    let mut sm = SourceMap::new();
    sm.load(&bytes).expect("load should not fail");

    assert!(!sm.is_empty(), "expected DWARF mappings in debug fixture");

    let (first_offset, first_loc) = sm.mappings().next().expect("at least one mapping");
    assert!(first_loc.line > 0, "expected non-zero line numbers");

    let looked_up = sm.lookup(first_offset).expect("lookup should succeed");
    assert_eq!(&looked_up, first_loc);

    assert!(sm.lookup(first_offset.saturating_add(1)).is_some());
}

fn uleb128(mut v: usize) -> Vec<u8> {
    let mut out = Vec::new();
    loop {
        let mut b = (v & 0x7F) as u8;
        v >>= 7;
        if v != 0 {
            b |= 0x80;
        }
        out.push(b);
        if v == 0 {
            break;
        }
    }
    out
}

fn wasm_with_custom_section(name: &str, payload: &[u8]) -> Vec<u8> {
    let mut bytes: Vec<u8> = Vec::new();
    bytes.extend_from_slice(&[0x00, 0x61, 0x73, 0x6d]);
    bytes.extend_from_slice(&[0x01, 0x00, 0x00, 0x00]);
    bytes.push(0x00); // custom section id

    let mut section = Vec::new();
    section.extend_from_slice(&uleb128(name.len()));
    section.extend_from_slice(name.as_bytes());
    section.extend_from_slice(payload);

    bytes.extend_from_slice(&uleb128(section.len()));
    bytes.extend_from_slice(&section);
    bytes
}

#[test]
fn source_map_partial_dwarf_is_graceful() {
    // A WASM with a completely malformed debug_info section.
    let malicious_dwarf = wasm_with_custom_section(".debug_info", &[0xde, 0xad, 0xbe, 0xef]);
    let mut sm = SourceMap::new();
    let res = sm.load(&malicious_dwarf);
    
    // The load should succeed but produce no mappings and one or more diagnostics.
    assert!(res.is_ok(), "load should not fail on partial/malformed DWARF units");
    assert!(sm.is_empty(), "expected no mappings for garbage DWARF");
    assert!(!sm.diagnostics.is_empty(), "expected diagnostics explaining the failure");
    
    let diag = &sm.diagnostics[0];
    assert!(diag.message.contains("Failed to read"), "Diagnostics should mention read failure: {}", diag.message);
}
