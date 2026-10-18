module main

import crypto.ecdsa
import net.http

fn main() {
    public_key, private_key := ecdsa.generate_key() or { panic(err) }
    message := 'native SDK smoke'.bytes()
    signature := private_key.sign(message) or { panic(err) }
    assert public_key.verify(message, signature) or { panic(err) }
    println(http.Method.get)
    println('pinned V OpenSSL sign/verify passed')
}
