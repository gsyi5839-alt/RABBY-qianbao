import XCTest

@testable import RabbyMobile

final class CorrectnessVectorsTests: XCTestCase {
    func testBIP44DerivationVectors() throws {
        let mnemonic = "test test test test test test test test test test test junk"
        let seed = try BIP39.mnemonicToSeed(mnemonic: mnemonic, passphrase: "")

        let pk0 = try BIP44.derivePrivateKey(seed: seed, path: "m/44'/60'/0'/0/0")
        XCTAssertEqual(pk0.count, 32)
        XCTAssertEqual("0x" + pk0.hexString, "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80")

        let addr0 = try BIP44.deriveAddress(privateKey: pk0)
        XCTAssertEqual(addr0, "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266")

        let pk1 = try BIP44.derivePrivateKey(seed: seed, path: "m/44'/60'/0'/0/1")
        let addr1 = try BIP44.deriveAddress(privateKey: pk1)
        XCTAssertEqual(addr1, "0x70997970C51812dc3A010C7d01b50e0d17dc79C8")

        let pk2 = try BIP44.derivePrivateKey(seed: seed, path: "m/44'/60'/0'/0/2")
        let addr2 = try BIP44.deriveAddress(privateKey: pk2)
        XCTAssertEqual(addr2, "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC")
    }

    func testLegacySignedTransactionVector() throws {
        let privateKey = Data(hexString: "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80")!
        let from = try EthereumUtil.privateKeyToAddress(privateKey)
        let tx = EthereumTransaction(
            to: "0x000000000000000000000000000000000000dEaD",
            from: from,
            nonce: 0,
            value: 0,
            data: Data(),
            gasLimit: 21_000,
            chainId: 1,
            maxFeePerGas: nil,
            maxPriorityFeePerGas: nil,
            gasPrice: 1_000_000_000,
            v: nil,
            r: nil,
            s: nil
        )

        let signed = try EthereumSigner.signTransaction(privateKey: privateKey, transaction: tx)
        XCTAssertEqual("0x" + signed.hexString, "0xf86380843b9aca0082520894000000000000000000000000000000000000dead808025a003e958d29a15656af2386b65e621c8201587f1c33f149c8e59ba04ed65d80bc9a068a253689110f83ce4159c0abcffd1a3839f3a5c71e659adcfd29f5dce63bacd")
    }

    func testEIP1559SignedTransactionVector() throws {
        let privateKey = Data(hexString: "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80")!
        let from = try EthereumUtil.privateKeyToAddress(privateKey)
        let tx = EthereumTransaction(
            to: "0x000000000000000000000000000000000000dEaD",
            from: from,
            nonce: 0,
            value: 0,
            data: Data(),
            gasLimit: 21_000,
            chainId: 1,
            maxFeePerGas: 2_000_000_000,
            maxPriorityFeePerGas: 1_000_000_000,
            gasPrice: nil,
            v: nil,
            r: nil,
            s: nil
        )

        let signed = try EthereumSigner.signTransaction(privateKey: privateKey, transaction: tx)
        XCTAssertEqual("0x" + signed.hexString, "0x02f86a0180843b9aca00847735940082520894000000000000000000000000000000000000dead8080c001a0dd8ac52aa1e8c0eba6c41ca43f084972feb74e3c37623d6615d6c7f7b7949f77a07e61f0020cb36fa3921fc15436e5d5237d86aa98a0e745dab6d76ec0583e1dc2")
    }

    func testPersonalSignVector() throws {
        let privateKey = Data(hexString: "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80")!
        let sig = try EthereumSigner.signMessage(privateKey: privateKey, message: Data("hello".utf8))
        XCTAssertEqual(sig.count, 65)
        XCTAssertEqual("0x" + sig.hexString, "0xf16ea9a3478698f695fd1401bfe27e9e4a7e8e3da94aa72b021125e31fa899cc573c48ea3fe1d4ab61a9db10c19032026e3ed2dbccba5a178235ac27f94504311c")
    }

    func testEIP712TypedDataVector() throws {
        let privateKey = Data(hexString: "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80")!
        let typedDataJSON = """
        {
          "types": {
            "EIP712Domain": [
              { "name": "name", "type": "string" },
              { "name": "version", "type": "string" },
              { "name": "chainId", "type": "uint256" },
              { "name": "verifyingContract", "type": "address" }
            ],
            "Person": [
              { "name": "name", "type": "string" },
              { "name": "wallet", "type": "address" }
            ],
            "Mail": [
              { "name": "from", "type": "Person" },
              { "name": "to", "type": "Person" },
              { "name": "contents", "type": "string" }
            ]
          },
          "primaryType": "Mail",
          "domain": {
            "name": "Ether Mail",
            "version": "1",
            "chainId": 1,
            "verifyingContract": "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC"
          },
          "message": {
            "from": {
              "name": "Cow",
              "wallet": "0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"
            },
            "to": {
              "name": "Bob",
              "wallet": "0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB"
            },
            "contents": "Hello, Bob!"
          }
        }
        """

        let sig = try EthereumSigner.signTypedData(privateKey: privateKey, typedDataJSON: typedDataJSON)
        XCTAssertEqual(sig.count, 65)
        XCTAssertEqual("0x" + sig.hexString, "0x6ea8bb309a3401225701f3565e32519f94a0ea91a5910ce9229fe488e773584c0390416a2190d9560219dab757ecca2029e63fa9d1c2aebf676cc25b9f03126a1b")
    }

    func testKeystoreV3ScryptVector() throws {
        let json = """
        {
          "version": 3,
          "id": "7c233295-e0e3-4767-8a90-40b00bf2e7fb",
          "address": "39b97205b9826f21fd39b535cf972c809e160e5f",
          "crypto": {
            "ciphertext": "076437cadf9726b105e87e04312fa087d5411d4da119b016c7f360625c909a05",
            "cipherparams": { "iv": "243d48a730d076fb9b75d77c7761e205" },
            "cipher": "aes-128-ctr",
            "kdf": "scrypt",
            "kdfparams": {
              "dklen": 32,
              "salt": "07ba5feeea26646399d3f32010240295884d2d4060bde6411cfd41e3ff94babe",
              "n": 131072,
              "r": 8,
              "p": 1
            },
            "mac": "eb01d6fa8b17a12943307c9c893e66ff0498dadca6134b3dce099a340225e08f"
          }
        }
        """

        let privateKey = try KeystoreV3.decryptPrivateKey(json: json, password: "1qazXSW@3edc")
        XCTAssertEqual(privateKey.count, 32)
        XCTAssertEqual("0x" + privateKey.hexString, "0xeff4580ef3a4ecd61f8e4d8ef18da75fddc0d5aadfb437c1dd7e9500e36de930")

        let address = try EthereumUtil.privateKeyToAddress(privateKey)
        XCTAssertEqual(address, "0x39b97205B9826F21Fd39B535CF972C809e160E5f")
    }
}

