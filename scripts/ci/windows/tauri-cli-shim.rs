use std::{env, process::{Command, exit}};
fn main() {
    let mut args: Vec<_> = env::args_os().skip(1).collect();
    if args.first().is_some_and(|value| value == "tauri") { args.remove(0); }
    let status = Command::new(env!("VTABLE_TAURI_NODE"))
        .arg(env!("VTABLE_TAURI_JS")).args(args).status()
        .expect("failed to execute the official Tauri CLI");
    exit(status.code().unwrap_or(1));
}
