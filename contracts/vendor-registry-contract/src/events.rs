use soroban_sdk::{Address, Env, String, Symbol};

pub fn publish_vendor_registered(env: &Env, vendor: Address, name: String) {
    let topics = (Symbol::new(env, "MERCHTREG"), vendor);
    env.events().publish(topics, name);
}

pub fn publish_vendor_status(env: &Env, vendor: Address, active: bool) {
    let topics = (Symbol::new(env, "MERCHTSTATUS"), vendor);
    env.events().publish(topics, active);
}
