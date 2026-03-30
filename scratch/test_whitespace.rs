fn main() {
    let command = "run   my_func   {\"a\":  1}";
    let parts: Vec<&str> = command.split_whitespace().collect();
    
    let function = parts[1].to_string();
    let args = if parts.len() > 2 {
        let mut current_pos = 0;
        let tokens = [parts[0], parts[1]];
        for token in tokens {
            if let Some(pos) = command[current_pos..].find(token) {
                current_pos += pos + token.len();
            }
        }
        let raw_args = command[current_pos..].trim();
        if raw_args.is_empty() {
            None
        } else {
            Some(raw_args.to_string())
        }
    } else {
        None
    };
    
    println!("Function: {}", function);
    println!("Args: {:?}", args);
    assert_eq!(args, Some("{\"a\":  1}".to_string()));
}
