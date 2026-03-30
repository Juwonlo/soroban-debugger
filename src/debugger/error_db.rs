use serde::{Deserialize, Serialize};
use soroban_env_common::xdr::ScErrorType;
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ErrorExplanation {
    pub code: u32,
    pub name: String,
    pub description: String,
    pub common_cause: String,
    pub suggested_fix: String,
}

pub struct ErrorDatabase {
    standard_errors: HashMap<u32, ErrorExplanation>,
    custom_errors: HashMap<u32, ErrorExplanation>,
}

impl ErrorDatabase {
    pub fn new() -> Self {
        let mut db = Self {
            standard_errors: HashMap::new(),
            custom_errors: HashMap::new(),
        };
        db.init_standard_errors();
        db
    }

    fn init_standard_errors(&mut self) {
        for error_type in ScErrorType::VARIANTS {
            let (desc, cause, fix) = standard_error_metadata(error_type);
            let code = error_type as u32;
            let name = error_type.name();
            self.standard_errors.insert(
                code,
                ErrorExplanation {
                    code,
                    name: name.to_string(),
                    description: desc.to_string(),
                    common_cause: cause.to_string(),
                    suggested_fix: fix.to_string(),
                },
            );
        }
    }

    pub fn lookup(&self, code: u32) -> Option<&ErrorExplanation> {
        self.custom_errors
            .get(&code)
            .or_else(|| self.standard_errors.get(&code))
    }

    pub fn add_custom_error(&mut self, error: ErrorExplanation) {
        self.custom_errors.insert(error.code, error);
    }

    pub fn load_custom_errors_from_wasm(&mut self, wasm_bytes: &[u8]) -> Result<(), String> {
        let custom_errors = crate::utils::wasm::parse_custom_errors(wasm_bytes)
            .map_err(|e| format!("Failed to parse custom errors from WASM: {:?}", e))?;

        for err in custom_errors {
            self.add_custom_error(ErrorExplanation {
                code: err.code,
                name: err.name,
                description: err.doc.clone(),
                common_cause: "Contract-specific error condition".to_string(),
                suggested_fix: "Review contract documentation or source code".to_string(),
            });
        }
        Ok(())
    }

    pub fn format_error(&self, code: u32) -> String {
        let mut output = String::new();
        if let Some(explanation) = self.lookup(code) {
            output.push_str("\n=== Error Explanation ===\n");
            output.push_str(&format!("Error Code: {}\n", explanation.code));
            output.push_str(&format!("Error Name: {}\n", explanation.name));
            output.push_str("\nDescription:\n");
            output.push_str(&format!("  {}\n", explanation.description));
            output.push_str("\nCommon Cause:\n");
            output.push_str(&format!("  {}\n", explanation.common_cause));
            output.push_str("\nSuggested Fix:\n");
            output.push_str(&format!("  {}\n", explanation.suggested_fix));
        } else {
            output.push_str(&format!("\n=== Error Code: {} ===\n", code));
            output.push_str("No explanation available for this error code.\n");
            output.push_str("This may be a custom contract error. Check contract documentation.\n");
        }
        output
    }

    pub fn display_error(&self, code: u32) {
        let formatted = self.format_error(code);
        for line in formatted.lines() {
            crate::logging::log_display(line, crate::logging::LogLevel::Info);
        }
    }
}

impl Default for ErrorDatabase {
    fn default() -> Self {
        Self::new()
    }
}

fn standard_error_metadata(error_type: ScErrorType) -> (&'static str, &'static str, &'static str) {
    match error_type {
        ScErrorType::Contract => (
            "Contract-defined error code returned from contract logic",
            "The contract intentionally returned a user-defined error (e.g. `panic_with_error!`)",
            "Inspect the contract's custom error enum/documentation and validate business rules",
        ),
        ScErrorType::WasmVm => (
            "WASM VM trap or runtime validation error",
            "Invalid WASM action, bounds violation, or VM/runtime trap",
            "Check contract bytecode assumptions, index bounds, and runtime preconditions",
        ),
        ScErrorType::Context => (
            "Host context operation failed",
            "Invalid host context state or exceeded context limits",
            "Verify call context assumptions and ensure host context limits are respected",
        ),
        ScErrorType::Storage => (
            "Storage operation failed in the Soroban host",
            "Missing key, invalid storage access pattern, or storage-layer constraint failure",
            "Validate key existence/access paths and review storage durability and limits",
        ),
        ScErrorType::Object => (
            "Host object operation failed",
            "Invalid object handle/type or object lifecycle misuse",
            "Ensure object values are valid for the operation and not stale or mismatched",
        ),
        ScErrorType::Crypto => (
            "Cryptographic operation failed",
            "Invalid signature/hash input, malformed key material, or unsupported crypto action",
            "Validate key formats and inputs, then re-check signature/hash expectations",
        ),
        ScErrorType::Events => (
            "Event emission failed",
            "Invalid event payload/topic shape or host event constraints were violated",
            "Verify event topic/data schema and ensure payload sizes/types are valid",
        ),
        ScErrorType::Budget => (
            "Execution budget was exceeded",
            "CPU instruction or memory budget limit reached during execution",
            "Optimize execution path, reduce allocations/loops, or increase available budget",
        ),
        ScErrorType::Value => (
            "Host value conversion/validation failed",
            "Type mismatch, invalid SCVal shape, or unsupported value conversion",
            "Validate argument and return-value types against the contract interface",
        ),
        ScErrorType::Auth => (
            "Authorization subsystem rejected the operation",
            "Missing/invalid authorization or failed authorization checks",
            "Provide required auth entries and verify signer/permission expectations",
        ),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_standard_error_lookup() {
        let db = ErrorDatabase::new();
        let wasm_vm = db
            .lookup(ScErrorType::WasmVm as u32)
            .expect("Should find WasmVm");
        assert_eq!(wasm_vm.name, "WasmVm");
        assert_eq!(wasm_vm.code, ScErrorType::WasmVm as u32);

        let context = db
            .lookup(ScErrorType::Context as u32)
            .expect("Should find Context");
        assert_eq!(context.name, "Context");

        let missing = db.lookup(999);
        assert!(missing.is_none());
    }

    #[test]
    fn test_standard_error_table_covers_all_sc_error_types() {
        let db = ErrorDatabase::new();

        for error_type in ScErrorType::VARIANTS {
            let code = error_type as u32;
            let explanation = db
                .lookup(code)
                .unwrap_or_else(|| panic!("Missing standard error entry for code {}", code));
            assert_eq!(explanation.name, error_type.name());
            assert_eq!(explanation.code, code);
        }
    }

    #[test]
    fn test_custom_error_addition() {
        let mut db = ErrorDatabase::new();
        db.add_custom_error(ErrorExplanation {
            code: 1001,
            name: "MyCustomError".to_string(),
            description: "Custom doc".to_string(),
            common_cause: "Cause".to_string(),
            suggested_fix: "Fix".to_string(),
        });

        let err = db.lookup(1001).expect("Should find custom error");
        assert_eq!(err.name, "MyCustomError");
    }
}
