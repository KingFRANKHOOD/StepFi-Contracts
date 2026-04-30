use crate::types::{DataKey, VendorInfo};
use soroban_sdk::{Address, Env};

pub fn has_admin(env: &Env) -> bool {
    env.storage().instance().has(&DataKey::Admin)
}

pub fn get_admin(env: &Env) -> Address {
    env.storage().instance().get(&DataKey::Admin).unwrap()
}

pub fn set_admin(env: &Env, admin: &Address) {
    env.storage().instance().set(&DataKey::Admin, admin);
}

pub fn has_vendor(env: &Env, vendor: &Address) -> bool {
    env.storage()
        .persistent()
        .has(&DataKey::Vendor(vendor.clone()))
}

pub fn get_vendor(env: &Env, vendor: &Address) -> Option<VendorInfo> {
    env.storage()
        .persistent()
        .get(&DataKey::Vendor(vendor.clone()))
}

pub fn set_vendor(env: &Env, vendor: &Address, info: &VendorInfo) {
    env.storage()
        .persistent()
        .set(&DataKey::Vendor(vendor.clone()), info);
}

pub fn get_vendor_count(env: &Env) -> u64 {
    env.storage()
        .persistent()
        .get(&DataKey::VendorCount)
        .unwrap_or(0)
}

pub fn increment_vendor_count(env: &Env) {
    let count = get_vendor_count(env);
    env.storage()
        .persistent()
        .set(&DataKey::VendorCount, &(count + 1));
}
