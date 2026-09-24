package foo.nosus.app.security

import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.math.BigInteger
import java.security.KeyFactory
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import java.security.interfaces.ECPublicKey
import java.security.spec.ECGenParameterSpec
import java.security.spec.ECPoint
import java.security.spec.ECPublicKeySpec
import java.security.spec.PKCS8EncodedKeySpec
import javax.crypto.Cipher
import javax.crypto.KeyAgreement
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Device key for Drop and Group drops (P-256 ECDH).
 *
 * API 31+: the private key is generated inside Android Keystore with
 * PURPOSE_AGREE_KEY and never leaves it. Only the 32-byte shared secret
 * comes back to Dart.
 *
 * API < 31: Keystore cannot do ECDH, so a software P-256 key is kept in
 * app prefs, encrypted with a Keystore AES-GCM key. Dart reports this as
 * kind "software" so the UI can say so.
 */
object DeviceKeyAgreement {
    private const val KEYSTORE = "AndroidKeyStore"
    private const val AGREE_ALIAS = "nosus_device_ecdh_v1"
    private const val WRAP_ALIAS = "nosus_device_wrap_v1"
    private const val PREFS = "nosus_device_keys"
    private const val PREF_PRIV = "sw_priv"
    private const val PREF_PUB = "sw_pub"

    val usesKeystore: Boolean get() = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S

    fun kind(): String = if (usesKeystore) "keystore" else "software"

    /** Uncompressed 65-byte public point. Creates the key on first call. */
    fun publicKey(context: Context): ByteArray {
        return if (usesKeystore) keystorePublic() else softwarePublic(context)
    }

    /** ECDH X coordinate, 32 bytes, left-padded. */
    fun agree(context: Context, peerRaw: ByteArray): ByteArray {
        publicKey(context) // make sure the key exists
        val peer = decodePublic(peerRaw)
        val priv: PrivateKey = if (usesKeystore) {
            val ks = KeyStore.getInstance(KEYSTORE).apply { load(null) }
            ks.getKey(AGREE_ALIAS, null) as PrivateKey
        } else {
            softwarePrivate(context)
        }
        val ka = if (usesKeystore) KeyAgreement.getInstance("ECDH", KEYSTORE) else KeyAgreement.getInstance("ECDH")
        ka.init(priv)
        ka.doPhase(peer, true)
        return fixed(ka.generateSecret(), 32)
    }

    /** Forget the key (sign-out / reset). A new one is made on next use. */
    fun reset(context: Context) {
        val ks = KeyStore.getInstance(KEYSTORE).apply { load(null) }
        if (ks.containsAlias(AGREE_ALIAS)) ks.deleteEntry(AGREE_ALIAS)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
    }

    // ── Keystore path (API 31+) ────────────────────────────────────────────

    private fun keystorePublic(): ByteArray {
        val ks = KeyStore.getInstance(KEYSTORE).apply { load(null) }
        if (!ks.containsAlias(AGREE_ALIAS)) {
            val gen = KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, KEYSTORE)
            gen.initialize(
                KeyGenParameterSpec.Builder(AGREE_ALIAS, KeyProperties.PURPOSE_AGREE_KEY)
                    .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
                    .build()
            )
            gen.generateKeyPair()
        }
        val cert = ks.getCertificate(AGREE_ALIAS)
        return encodePublic(cert.publicKey as ECPublicKey)
    }

    // ── Software fallback (API < 31) ───────────────────────────────────────

    private fun softwarePublic(context: Context): ByteArray {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.getString(PREF_PUB, null)?.let { return Base64.decode(it, Base64.NO_WRAP) }
        val gen = KeyPairGenerator.getInstance("EC")
        gen.initialize(ECGenParameterSpec("secp256r1"))
        val pair = gen.generateKeyPair()
        val pub = encodePublic(pair.public as ECPublicKey)
        val wrapped = wrap(pair.private.encoded)
        prefs.edit()
            .putString(PREF_PRIV, Base64.encodeToString(wrapped, Base64.NO_WRAP))
            .putString(PREF_PUB, Base64.encodeToString(pub, Base64.NO_WRAP))
            .apply()
        return pub
    }

    private fun softwarePrivate(context: Context): PrivateKey {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val wrapped = Base64.decode(prefs.getString(PREF_PRIV, null) ?: error("no device key"), Base64.NO_WRAP)
        val pkcs8 = unwrap(wrapped)
        return KeyFactory.getInstance("EC").generatePrivate(PKCS8EncodedKeySpec(pkcs8))
    }

    private fun wrapKey(): SecretKey {
        val ks = KeyStore.getInstance(KEYSTORE).apply { load(null) }
        (ks.getKey(WRAP_ALIAS, null) as? SecretKey)?.let { return it }
        val gen = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE)
        gen.init(
            KeyGenParameterSpec.Builder(WRAP_ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build()
        )
        return gen.generateKey()
    }

    private fun wrap(plain: ByteArray): ByteArray {
        val c = Cipher.getInstance("AES/GCM/NoPadding")
        c.init(Cipher.ENCRYPT_MODE, wrapKey())
        return c.iv + c.doFinal(plain)
    }

    private fun unwrap(box: ByteArray): ByteArray {
        val c = Cipher.getInstance("AES/GCM/NoPadding")
        c.init(Cipher.DECRYPT_MODE, wrapKey(), GCMParameterSpec(128, box.copyOfRange(0, 12)))
        return c.doFinal(box.copyOfRange(12, box.size))
    }

    // ── Encoding ───────────────────────────────────────────────────────────

    private fun encodePublic(key: ECPublicKey): ByteArray {
        val x = fixed(key.w.affineX.toByteArray(), 32)
        val y = fixed(key.w.affineY.toByteArray(), 32)
        return byteArrayOf(0x04) + x + y
    }

    private val p256Params: java.security.spec.ECParameterSpec by lazy {
        val gen = KeyPairGenerator.getInstance("EC")
        gen.initialize(ECGenParameterSpec("secp256r1"))
        (gen.generateKeyPair().public as ECPublicKey).params
    }

    private fun decodePublic(raw: ByteArray): ECPublicKey {
        require(raw.size == 65 && raw[0] == 0x04.toByte()) { "public key" }
        val point = ECPoint(BigInteger(1, raw.copyOfRange(1, 33)), BigInteger(1, raw.copyOfRange(33, 65)))
        return KeyFactory.getInstance("EC").generatePublic(ECPublicKeySpec(point, p256Params)) as ECPublicKey
    }

    private fun fixed(bytes: ByteArray, len: Int): ByteArray {
        val trimmed = if (bytes.size > len) bytes.copyOfRange(bytes.size - len, bytes.size) else bytes
        return ByteArray(len - trimmed.size) + trimmed
    }
}
