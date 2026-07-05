use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use lazy_static::lazy_static;

lazy_static! {
    static ref KEY_STORE: Arc<Mutex<HashMap<String, Vec<u8>>>> = Arc::new(Mutex::new(HashMap::new()));
}

pub fn register_key(key_id: String, payload: Vec<u8>) {
    let mut store = KEY_STORE.lock().unwrap();
    store.insert(key_id, payload);
}

pub fn get_key(key_id: &str) -> Option<Vec<u8>> {
    let store = KEY_STORE.lock().unwrap();
    store.get(key_id).cloned()
}

pub fn contains_key(key_id: &str) -> bool {
    let store = KEY_STORE.lock().unwrap();
    store.contains_key(key_id)
}
